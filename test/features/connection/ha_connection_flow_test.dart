// Integration-style test of the Home Assistant communication layer over the
// REAL transport path: `HaWebSocketClient` + the production `connectHaWebSocket`
// connector (package:web_socket_channel) talking to a loopback `HttpServer`
// that plays the HA WebSocket API. Unlike the other connection unit tests —
// which drive a `FakeHaSocket` at the decoded-map level — this exercises actual
// JSON framing, the socket handshake and reconnection against a live server.
//
// It lives under test/ (not integration_test/) on purpose: it is a headless,
// pure-Dart network test with no widget binding, so it runs with `flutter test`
// and in CI without a device. Flutter's integration_test/ directory is reserved
// for device-driven flows (e.g. the #3/#4 widget integration tests), which need
// a connected device/emulator and are not run by plain `flutter test`.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/data/ha_websocket_client.dart';
import 'package:homeassistant_flutter/features/connection/domain/connection_status.dart';
import 'package:homeassistant_flutter/features/connection/domain/ha_connection_config.dart';

void main() {
  const token = 'long-lived-test-token';
  const timeout = Duration(seconds: 10);

  late _FakeHaServer ha;

  setUp(() async {
    ha = _FakeHaServer(token: token);
    await ha.start();
  });

  tearDown(() async {
    await ha.stop();
  });

  HaWebSocketClient clientFor({Duration? initialBackoff}) {
    final client = HaWebSocketClient(
      config: HaConnectionConfig(
        baseUrl: Uri.parse('http://${ha.host}:${ha.port}'),
        accessToken: token,
      ),
      initialBackoff: initialBackoff ?? const Duration(seconds: 1),
    );
    addTearDown(client.dispose);
    return client;
  }

  test(
    'authenticates, seeds the entity store, then applies a live state_changed',
    () async {
      ha.initialStates = [
        {
          'entity_id': 'light.kitchen',
          'state': 'off',
          'attributes': {'friendly_name': 'Kitchen'},
          'last_updated': '2026-06-29T10:00:00Z',
        },
      ];
      final client = clientFor();

      // Subscribe before connecting so we can't miss the `connected` transition.
      final connected = client.connectionStates
          .firstWhere((s) => s.isConnected)
          .timeout(timeout);
      await client.connect();
      await connected;

      // Snapshot from `get_states` was seeded through the real JSON path.
      expect(client.entity('light.kitchen')?.state, 'off');
      expect(client.entity('light.kitchen')?.friendlyName, 'Kitchen');

      // A live `state_changed` pushed after connection updates the store.
      final turnedOn = client.entityStates
          .firstWhere((e) => e['light.kitchen']?.state == 'on')
          .timeout(timeout);
      ha.pushStateChanged({
        'entity_id': 'light.kitchen',
        'new_state': {
          'entity_id': 'light.kitchen',
          'state': 'on',
          'attributes': {'friendly_name': 'Kitchen'},
          'last_updated': '2026-06-29T10:01:00Z',
        },
      });
      await turnedOn;
      expect(client.entity('light.kitchen')?.state, 'on');
    },
  );

  test(
    'reconnects automatically after the server drops the connection',
    () async {
      final client = clientFor(
        initialBackoff: const Duration(milliseconds: 20),
      );

      final firstConnect = client.connectionStates
          .firstWhere((s) => s.isConnected)
          .timeout(timeout);
      await client.connect();
      await firstConnect;

      // Watch for the reconnecting transition and the recovery, then drop the socket.
      final reconnecting = client.connectionStates
          .firstWhere((s) => s.status == HaConnectionStatus.reconnecting)
          .timeout(timeout);
      // Subscribed after the first `connected` has already passed, so the next
      // `connected` emission this picks up is the reconnection.
      final reconnected = client.connectionStates
          .firstWhere((s) => s.isConnected)
          .timeout(timeout);
      await ha.dropActiveSocket();

      final droppedState = await reconnecting;
      expect(droppedState.reconnectAttempt, greaterThanOrEqualTo(1));

      // The client re-establishes on its own against the same server.
      await reconnected;
      expect(client.connectionState.isConnected, isTrue);
    },
  );
}

/// A minimal in-process Home Assistant WebSocket server for end-to-end tests.
/// Accepts a real WebSocket, runs the `auth` handshake, answers
/// `subscribe_events` / `get_states`, and can push `state_changed` events or
/// drop the connection on demand.
class _FakeHaServer {
  _FakeHaServer({required this.token});

  final String token;
  HttpServer? _server;
  WebSocket? _activeSocket;

  /// States returned by `get_states` (the seed snapshot).
  List<Map<String, dynamic>> initialStates = const [];

  String get host => _server!.address.host;
  int get port => _server!.port;

  Future<void> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      _activeSocket = socket;
      // HA opens the handshake by asking the client to authenticate.
      socket.add(jsonEncode({'type': 'auth_required'}));
      socket.listen(
        (data) => _handle(socket, data as String),
        onDone: () {
          if (identical(_activeSocket, socket)) _activeSocket = null;
        },
        cancelOnError: true,
      );
    });
  }

  void _handle(WebSocket socket, String data) {
    final message = (jsonDecode(data) as Map).cast<String, dynamic>();
    switch (message['type']) {
      case 'auth':
        final ok = message['access_token'] == token;
        socket.add(
          jsonEncode(
            ok
                ? {'type': 'auth_ok'}
                : {'type': 'auth_invalid', 'message': 'Invalid access token'},
          ),
        );
      case 'subscribe_events':
        socket.add(
          jsonEncode({
            'id': message['id'],
            'type': 'result',
            'success': true,
            'result': null,
          }),
        );
      case 'get_states':
        socket.add(
          jsonEncode({
            'id': message['id'],
            'type': 'result',
            'success': true,
            'result': initialStates,
          }),
        );
    }
  }

  /// Push a `state_changed` event carrying [data] (`entity_id`, `new_state`…).
  void pushStateChanged(Map<String, dynamic> data) {
    _activeSocket?.add(
      jsonEncode({
        'type': 'event',
        'event': {'event_type': 'state_changed', 'data': data},
      }),
    );
  }

  /// Simulate a network drop: close the live socket so the client must reconnect.
  Future<void> dropActiveSocket() async {
    final socket = _activeSocket;
    _activeSocket = null;
    await socket?.close();
  }

  Future<void> stop() async {
    await _activeSocket?.close();
    _activeSocket = null;
    await _server?.close(force: true);
    _server = null;
  }
}
