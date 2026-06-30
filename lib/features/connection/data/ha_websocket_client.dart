import 'dart:async';
import 'dart:math' as math;

import '../domain/connection_status.dart';
import '../domain/entity_state.dart';
import '../domain/ha_connection_config.dart';
import '../domain/ha_exception.dart';
import 'ha_socket.dart';

/// Talks to a Home Assistant instance over the WebSocket API.
///
/// Responsibilities:
/// - open the socket and perform the `auth` handshake with a long-lived token;
/// - subscribe to `state_changed` and keep an in-memory store of entity states;
/// - expose the connection lifecycle and the entity store as streams;
/// - reconnect automatically with exponential backoff on dropped connections.
///
/// Errors are *surfaced* through [connectionStates] (and the [connectionState]
/// snapshot), never thrown out of [connect]. Decoupled from any UI and from
/// Riverpod so it can be driven by a fake [HaSocket] in unit tests.
///
/// Reference: https://developers.home-assistant.io/docs/api/websocket
class HaWebSocketClient {
  HaWebSocketClient({
    required this.config,
    HaSocketConnector connector = connectHaWebSocket,
    this.initialBackoff = const Duration(seconds: 1),
    this.maxBackoff = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
  }) : _connector = connector;

  final HaConnectionConfig config;
  final HaSocketConnector _connector;

  /// Backoff for the first reconnect attempt; doubles (by [backoffMultiplier])
  /// each subsequent attempt up to [maxBackoff].
  final Duration initialBackoff;
  final Duration maxBackoff;
  final double backoffMultiplier;

  final _stateController = StreamController<HaConnectionState>.broadcast();
  final _entitiesController =
      StreamController<Map<String, EntityState>>.broadcast();

  HaConnectionState _state = HaConnectionState.idle;
  Map<String, EntityState> _entities = {};

  HaSocket? _socket;
  StreamSubscription<Map<String, dynamic>>? _socketSub;

  /// Monotonically increasing command id, reset on every (re)connection as HA
  /// requires ids to be increasing within a single connection.
  int _commandId = 0;
  final _pending = <int, Completer<Object?>>{};

  /// Non-null while seeding the store: `state_changed` events that arrive
  /// between the subscription and the `get_states` snapshot are buffered here
  /// and replayed on top of the snapshot so a live change can't be clobbered.
  List<Map<String, dynamic>>? _seedBuffer;

  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;
  bool _intentionalClose = false;
  bool _disposed = false;

  // --- Public API ---------------------------------------------------------

  /// Live connection lifecycle. Broadcast; read [connectionState] for the
  /// current value.
  Stream<HaConnectionState> get connectionStates => _stateController.stream;

  /// Current connection lifecycle snapshot.
  HaConnectionState get connectionState => _state;

  /// Live entity store: emits an immutable snapshot of all known entities on
  /// every change. Broadcast; read [entities] for the current value.
  Stream<Map<String, EntityState>> get entityStates =>
      _entitiesController.stream;

  /// Current immutable snapshot of all known entities, keyed by entity id.
  Map<String, EntityState> get entities => Map.unmodifiable(_entities);

  /// Current state of a single entity, or null if unknown.
  EntityState? entity(String entityId) => _entities[entityId];

  /// Start (or restart) the connection lifecycle. Does not throw on transport
  /// or auth failures — observe [connectionStates] instead.
  Future<void> connect() async {
    if (_disposed) {
      throw StateError('connect() called on a disposed HaWebSocketClient');
    }
    _intentionalClose = false;
    await _open();
  }

  /// Close the connection on purpose. No reconnect is scheduled.
  Future<void> disconnect() async {
    _intentionalClose = true;
    _cancelReconnect();
    // Flip the lifecycle state before awaiting teardown so a service call
    // racing the shutdown window is rejected rather than left hanging.
    _emit(HaConnectionStatus.disconnected);
    _failPending(const HaConnectionException('Connection closed by client'));
    await _teardownSocket();
  }

  /// Call a Home Assistant service over the WebSocket, e.g.
  /// `callService('light', 'turn_on', target: {'entity_id': 'light.kitchen'})`.
  /// Completes with the command result, or throws [HaCommandException] /
  /// [HaConnectionException].
  Future<Object?> callService(
    String domain,
    String service, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? target,
  }) {
    if (_disposed || !_state.isConnected) {
      return Future.error(
        const HaConnectionException('Cannot call a service while disconnected'),
      );
    }
    return _sendCommand(_nextId(), {
      'type': 'call_service',
      'domain': domain,
      'service': service,
      'service_data': ?data,
      'target': ?target,
    });
  }

  /// Fetch a Lovelace dashboard config over the WebSocket API. A null [urlPath]
  /// requests the default dashboard. Only available for storage-mode (UI-edited)
  /// dashboards; YAML/auto-generated setups may error or return a strategy shape.
  ///
  /// Completes with the raw config map, or throws [HaCommandException] /
  /// [HaConnectionException]. Unlike [callService], `url_path` is always sent
  /// (with an explicit null for the default dashboard) rather than spread away,
  /// because HA expects the key to be present.
  Future<Map<String, dynamic>> fetchLovelaceConfig({String? urlPath}) {
    if (_disposed || !_state.isConnected) {
      return Future.error(
        const HaConnectionException(
          'Cannot fetch the dashboard while disconnected',
        ),
      );
    }
    return _sendCommand(_nextId(), {
      'type': 'lovelace/config',
      'url_path': urlPath,
    }).then((result) => (result as Map).cast<String, dynamic>());
  }

  /// Permanently release all resources. The client cannot be reused afterwards.
  Future<void> dispose() async {
    _disposed = true;
    _intentionalClose = true;
    _cancelReconnect();
    _failPending(const HaConnectionException('Client disposed'));
    await _teardownSocket();
    await _stateController.close();
    await _entitiesController.close();
  }

  // --- Connection lifecycle ----------------------------------------------

  Future<void> _open() async {
    _cancelReconnect();
    // Tear down any existing connection first so connect() can safely restart a
    // live client without leaking the previous socket/subscription. On the
    // reconnect path teardown already happened, making this a no-op.
    await _teardownSocket();
    _failPending(const HaConnectionException('Reconnecting'));
    _seedBuffer = null;
    _commandId = 0;
    _emit(HaConnectionStatus.connecting);
    try {
      final socket = await _connector(config.webSocketUrl);
      // A disconnect()/dispose() may have happened while connecting.
      if (_intentionalClose || _disposed) {
        await socket.close();
        return;
      }
      _socket = socket;
      _emit(HaConnectionStatus.authenticating);
      _socketSub = socket.messages.listen(
        _onMessage,
        onError: _onSocketError,
        onDone: _onSocketDone,
        cancelOnError: false,
      );
      // The handshake is message-driven: HA sends `auth_required` first, which
      // _onMessage answers with the token.
    } catch (error) {
      _handleDrop(_asConnectionError(error));
    }
  }

  void _onMessage(Map<String, dynamic> message) {
    // A synchronous throw inside a stream's onData callback escapes to the
    // surrounding zone (not onError), which would crash the app and break the
    // "errors are surfaced, never thrown" contract. Guard the whole dispatch so
    // a single malformed frame is skipped while the connection stays healthy.
    try {
      switch (message['type']) {
        case 'auth_required':
          _socket?.send({'type': 'auth', 'access_token': config.accessToken});
        case 'auth_ok':
          unawaited(_onAuthenticated());
        case 'auth_invalid':
          _onAuthInvalid(
            message['message'] as String? ?? 'Invalid access token',
          );
        case 'result':
          _onResult(message);
        case 'event':
          _onEvent(message);
        case 'pong':
          break; // keepalive ack, nothing to do
      }
    } catch (_) {
      // Malformed/unexpected frame — drop it rather than tearing down a healthy
      // connection or crashing the zone.
    }
  }

  Future<void> _onAuthenticated() async {
    // Subscribe to `state_changed` first, then seed the store from a snapshot.
    // While the snapshot is in flight, live events are buffered (see _onEvent)
    // and replayed on top of the snapshot afterwards, so a change that lands
    // during the seed window can't be overwritten by the (older) snapshot.
    final subscriptionId = _nextId();
    final subscribed = _sendCommand(subscriptionId, {
      'type': 'subscribe_events',
      'event_type': 'state_changed',
    });
    final statesId = _nextId();
    final snapshot = _sendCommand(statesId, {'type': 'get_states'});
    _seedBuffer = [];

    try {
      await subscribed;
      final states = (await snapshot as List?) ?? const [];
      final seeded = <String, EntityState>{};
      for (final raw in states) {
        if (raw is Map) {
          final entity = EntityState.fromJson(raw.cast<String, dynamic>());
          seeded[entity.entityId] = entity;
        }
      }
      _entities = seeded;
      final buffered = _seedBuffer ?? const [];
      _seedBuffer = null;
      for (final data in buffered) {
        _applyStateChanged(data);
      }
      _reconnectAttempt = 0;
      _emit(HaConnectionStatus.connected);
      _emitEntities();
    } catch (error) {
      _seedBuffer = null;
      // Subscribing or seeding failed — treat as a (retryable) connection drop.
      _handleDrop(_asConnectionError(error));
    }
  }

  void _onAuthInvalid(String reason) {
    // A bad token will keep being rejected, so this is fatal: stop and surface
    // the error instead of reconnecting in a loop.
    _intentionalClose = true;
    _failPending(HaAuthException(reason));
    unawaited(_teardownSocket());
    _emit(HaConnectionStatus.error, error: HaAuthException(reason));
  }

  void _onResult(Map<String, dynamic> message) {
    final id = message['id'];
    if (id is! int) return;
    final completer = _pending.remove(id);
    if (completer == null || completer.isCompleted) return;
    if (message['success'] == true) {
      completer.complete(message['result']);
    } else {
      final error = (message['error'] as Map?)?.cast<String, dynamic>();
      completer.completeError(
        HaCommandException(
          error?['message'] as String? ?? 'Command failed',
          code: error?['code']?.toString(),
        ),
      );
    }
  }

  void _onEvent(Map<String, dynamic> message) {
    final event = (message['event'] as Map?)?.cast<String, dynamic>();
    if (event == null || event['event_type'] != 'state_changed') return;
    final data = (event['data'] as Map?)?.cast<String, dynamic>();
    if (data == null) return;

    final buffer = _seedBuffer;
    if (buffer != null) {
      // Still seeding: defer until the snapshot has been applied.
      buffer.add(data);
      return;
    }
    _applyStateChanged(data);
  }

  void _applyStateChanged(Map<String, dynamic> data) {
    final entityId = data['entity_id'] as String?;
    if (entityId == null) return;

    final newState = data['new_state'];
    if (newState is Map) {
      _entities[entityId] = EntityState.fromJson(
        newState.cast<String, dynamic>(),
      );
    } else {
      // `new_state == null` means the entity was removed.
      if (!_entities.containsKey(entityId)) return;
      _entities.remove(entityId);
    }
    _emitEntities();
  }

  // --- Drop / reconnect ---------------------------------------------------

  void _onSocketError(Object error, StackTrace _) =>
      _handleDrop(_asConnectionError(error));

  void _onSocketDone() =>
      _handleDrop(const HaConnectionException('WebSocket connection closed'));

  /// Single entry point for every kind of unexpected disconnection. Guards
  /// against double handling (a transport often reports both `onError` and
  /// `onDone`) and against firing while a reconnect is already pending.
  void _handleDrop(HaConnectionException error) {
    if (_intentionalClose || _disposed) return;
    if (_state.status == HaConnectionStatus.reconnecting) return;
    _failPending(error);
    unawaited(_teardownSocket());
    _scheduleReconnect(error);
  }

  void _scheduleReconnect(HaConnectionException error) {
    final delay = _backoffFor(_reconnectAttempt);
    _reconnectAttempt += 1;
    _state = HaConnectionState(
      HaConnectionStatus.reconnecting,
      error: error,
      reconnectAttempt: _reconnectAttempt,
      retryDelay: delay,
    );
    if (!_stateController.isClosed) _stateController.add(_state);
    _reconnectTimer = Timer(delay, () {
      if (_intentionalClose || _disposed) return;
      unawaited(_open());
    });
  }

  Duration _backoffFor(int attempt) {
    final millis =
        initialBackoff.inMilliseconds * math.pow(backoffMultiplier, attempt);
    final capped = math.min(millis, maxBackoff.inMilliseconds.toDouble());
    return Duration(milliseconds: capped.round());
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  // --- Helpers ------------------------------------------------------------

  int _nextId() => ++_commandId;

  Future<Object?> _sendCommand(int id, Map<String, dynamic> payload) {
    final socket = _socket;
    if (socket == null) {
      // No live socket (e.g. a command racing teardown) — reject immediately
      // instead of registering a completer that would never settle.
      return Future.error(const HaConnectionException('No active connection'));
    }
    final completer = Completer<Object?>();
    _pending[id] = completer;
    socket.send({'id': id, ...payload});
    return completer.future;
  }

  void _failPending(Object error) {
    if (_pending.isEmpty) return;
    final completers = _pending.values.toList();
    _pending.clear();
    for (final completer in completers) {
      if (!completer.isCompleted) completer.completeError(error);
    }
  }

  Future<void> _teardownSocket() async {
    // Null both references synchronously, before any await, so a command racing
    // the teardown sees no socket and is rejected rather than left hanging.
    final sub = _socketSub;
    final socket = _socket;
    _socketSub = null;
    _socket = null;
    await sub?.cancel();
    await socket?.close();
  }

  void _emit(HaConnectionStatus status, {Object? error}) {
    _state = HaConnectionState(
      status,
      error: error,
      reconnectAttempt: _reconnectAttempt,
    );
    if (!_stateController.isClosed) _stateController.add(_state);
  }

  void _emitEntities() {
    if (!_entitiesController.isClosed) {
      _entitiesController.add(Map.unmodifiable(_entities));
    }
  }

  HaConnectionException _asConnectionError(Object error) =>
      error is HaConnectionException
      ? error
      : HaConnectionException('$error', cause: error);
}
