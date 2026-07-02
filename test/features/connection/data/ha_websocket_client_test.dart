import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/data/ha_websocket_client.dart';
import 'package:homeassistant_flutter/features/connection/domain/connection_status.dart';
import 'package:homeassistant_flutter/features/connection/domain/entity_state.dart';
import 'package:homeassistant_flutter/features/connection/domain/ha_connection_config.dart';
import 'package:homeassistant_flutter/features/connection/domain/ha_exception.dart';

import '../fakes/fake_ha_socket.dart';

final _config = HaConnectionConfig(
  baseUrl: Uri.parse('http://localhost:8123'),
  accessToken: 'test-token',
);

void main() {
  group('HaWebSocketClient — authentication', () {
    test(
      'sends the token and reaches connected, seeding entity states',
      () async {
        final connector = FakeConnector();
        final client = HaWebSocketClient(
          config: _config,
          connector: connector.connect,
        );
        addTearDown(client.dispose);

        await client.connect();
        await pumpEventQueue();
        final socket = connector.last;

        socket.serverSend({'type': 'auth_required', 'ha_version': '2024.1'});
        await pumpEventQueue();
        expect(socket.sent.first, {
          'type': 'auth',
          'access_token': 'test-token',
        });

        socket.serverSend({'type': 'auth_ok', 'ha_version': '2024.1'});
        await pumpEventQueue();

        final subscribe = socket.sentOfType('subscribe_events').single;
        expect(subscribe['event_type'], 'state_changed');
        final getStates = socket.sentOfType('get_states').single;

        socket.serverSend({
          'id': subscribe['id'],
          'type': 'result',
          'success': true,
          'result': null,
        });
        socket.serverSend({
          'id': getStates['id'],
          'type': 'result',
          'success': true,
          'result': [
            {
              'entity_id': 'light.kitchen',
              'state': 'on',
              'attributes': {'friendly_name': 'Kitchen'},
            },
          ],
        });
        await pumpEventQueue();

        expect(client.connectionState.status, HaConnectionStatus.connected);
        expect(client.entity('light.kitchen')?.state, 'on');
        expect(client.entity('light.kitchen')?.friendlyName, 'Kitchen');
      },
    );

    test(
      'surfaces an auth error and does not reconnect on an invalid token',
      () async {
        final connector = FakeConnector();
        final client = HaWebSocketClient(
          config: _config,
          connector: connector.connect,
        );
        addTearDown(client.dispose);

        await client.connect();
        await pumpEventQueue();
        final socket = connector.last;

        socket.serverSend({'type': 'auth_required'});
        await pumpEventQueue();
        socket.serverSend({
          'type': 'auth_invalid',
          'message': 'Invalid password',
        });
        await pumpEventQueue();

        expect(client.connectionState.status, HaConnectionStatus.error);
        expect(client.connectionState.error, isA<HaAuthException>());
        expect(socket.closed, isTrue);
        expect(connector.calls, 1, reason: 'must not retry with a bad token');
      },
    );

    test('updateAccessToken changes the token used on the next auth handshake '
        'without needing config itself to change', () async {
      final connector = FakeConnector();
      final client = HaWebSocketClient(
        config: _config,
        connector: connector.connect,
      );
      addTearDown(client.dispose);

      client.updateAccessToken('refreshed-token');
      await client.connect();
      await pumpEventQueue();
      final socket = connector.last;

      socket.serverSend({'type': 'auth_required'});
      await pumpEventQueue();

      expect(socket.sent.first, {
        'type': 'auth',
        'access_token': 'refreshed-token',
      });
      // The immutable config is untouched — only the client's internal
      // token changed.
      expect(client.config.accessToken, 'test-token');
    });
  });

  group('HaWebSocketClient — entity store', () {
    test('updates an entity from a state_changed event', () async {
      final connector = FakeConnector();
      final client = HaWebSocketClient(
        config: _config,
        connector: connector.connect,
      );
      addTearDown(client.dispose);

      await client.connect();
      await pumpEventQueue();
      final socket = connector.last;
      await completeHandshake(
        socket,
        states: [
          {'entity_id': 'light.kitchen', 'state': 'off'},
        ],
      );
      expect(client.entity('light.kitchen')?.state, 'off');

      socket.serverSend({
        'type': 'event',
        'event': {
          'event_type': 'state_changed',
          'data': {
            'entity_id': 'light.kitchen',
            'new_state': {'entity_id': 'light.kitchen', 'state': 'on'},
          },
        },
      });
      await pumpEventQueue();

      expect(client.entity('light.kitchen')?.state, 'on');
    });

    test('removes an entity when new_state is null', () async {
      final connector = FakeConnector();
      final client = HaWebSocketClient(
        config: _config,
        connector: connector.connect,
      );
      addTearDown(client.dispose);

      await client.connect();
      await pumpEventQueue();
      final socket = connector.last;
      await completeHandshake(
        socket,
        states: [
          {'entity_id': 'light.kitchen', 'state': 'on'},
        ],
      );

      socket.serverSend({
        'type': 'event',
        'event': {
          'event_type': 'state_changed',
          'data': {'entity_id': 'light.kitchen', 'new_state': null},
        },
      });
      await pumpEventQueue();

      expect(client.entity('light.kitchen'), isNull);
    });
  });

  group('HaWebSocketClient — reconnection', () {
    test('reconnects with exponential backoff after a drop', () {
      fakeAsync((async) {
        final connector = FakeConnector();
        final client = HaWebSocketClient(
          config: _config,
          connector: connector.connect,
          initialBackoff: const Duration(seconds: 1),
          maxBackoff: const Duration(seconds: 30),
        );

        client.connect();
        async.flushMicrotasks();
        _completeHandshakeSync(async, connector.last);
        expect(client.connectionState.status, HaConnectionStatus.connected);

        // The connection drops.
        connector.last.serverClose();
        async.flushMicrotasks();
        expect(client.connectionState.status, HaConnectionStatus.reconnecting);
        expect(client.connectionState.retryDelay, const Duration(seconds: 1));
        expect(connector.calls, 1);

        // Nothing happens before the backoff elapses...
        async.elapse(const Duration(milliseconds: 999));
        expect(connector.calls, 1);
        // ...then it retries.
        async.elapse(const Duration(milliseconds: 1));
        async.flushMicrotasks();
        expect(connector.calls, 2);

        // A successful reconnect resets the backoff counter.
        _completeHandshakeSync(async, connector.last);
        expect(client.connectionState.status, HaConnectionStatus.connected);
        expect(client.connectionState.reconnectAttempt, 0);

        client.dispose();
        async.flushMicrotasks();
      });
    });

    test('the backoff grows then caps at maxBackoff', () {
      fakeAsync((async) {
        // Six failures in a row: the initial attempt plus one per loop step.
        final connector = FakeConnector()..failNextConnections = 6;
        final client = HaWebSocketClient(
          config: _config,
          connector: connector.connect,
          initialBackoff: const Duration(seconds: 1),
          maxBackoff: const Duration(seconds: 8),
        );

        client.connect();
        async.flushMicrotasks();

        // Advance the clock by exactly the current backoff each step so that
        // precisely one reconnect attempt fires, and record the delay that was
        // scheduled.
        final delays = <Duration>[];
        for (var i = 0; i < 5; i++) {
          final delay = client.connectionState.retryDelay!;
          delays.add(delay);
          async.elapse(delay);
          async.flushMicrotasks();
        }

        expect(delays, [
          const Duration(seconds: 1),
          const Duration(seconds: 2),
          const Duration(seconds: 4),
          const Duration(seconds: 8), // capped
          const Duration(seconds: 8), // stays capped
        ]);

        client.dispose();
        async.flushMicrotasks();
      });
    });

    test('surfaces a connection failure without throwing', () {
      fakeAsync((async) {
        final connector = FakeConnector()..failNextConnections = 1;
        final client = HaWebSocketClient(
          config: _config,
          connector: connector.connect,
          initialBackoff: const Duration(seconds: 1),
        );

        // Must not throw even though the first socket fails to open.
        client.connect();
        async.flushMicrotasks();
        expect(client.connectionState.status, HaConnectionStatus.reconnecting);

        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(connector.calls, 2);

        _completeHandshakeSync(async, connector.last);
        expect(client.connectionState.status, HaConnectionStatus.connected);

        client.dispose();
        async.flushMicrotasks();
      });
    });

    test('disconnect() closes and does not reconnect', () async {
      final connector = FakeConnector();
      final client = HaWebSocketClient(
        config: _config,
        connector: connector.connect,
      );

      await client.connect();
      await pumpEventQueue();
      await completeHandshake(connector.last);
      expect(client.connectionState.status, HaConnectionStatus.connected);

      await client.disconnect();
      expect(client.connectionState.status, HaConnectionStatus.disconnected);
      expect(connector.last.closed, isTrue);

      // disconnect() itself does not schedule a reconnect.
      await pumpEventQueue();
      expect(connector.calls, 1);
    });

    test('connect() on a live client tears down the previous socket', () async {
      final connector = FakeConnector();
      final client = HaWebSocketClient(
        config: _config,
        connector: connector.connect,
      );
      addTearDown(client.dispose);

      await client.connect();
      await pumpEventQueue();
      await completeHandshake(connector.last);
      final first = connector.last;

      // Restart while connected.
      await client.connect();
      await pumpEventQueue();
      expect(first.closed, isTrue, reason: 'old socket must be closed');
      expect(connector.calls, 2);

      await completeHandshake(connector.last);
      expect(client.connectionState.status, HaConnectionStatus.connected);

      // A late drop on the orphaned old socket must not disturb the new one.
      first.serverClose();
      await pumpEventQueue();
      expect(client.connectionState.status, HaConnectionStatus.connected);
    });
  });

  group('HaWebSocketClient — commands', () {
    test('callService rejects while disconnected', () async {
      final client = HaWebSocketClient(
        config: _config,
        connector: FakeConnector().connect,
      );
      addTearDown(client.dispose);

      expect(
        client.callService('light', 'turn_on'),
        throwsA(isA<HaConnectionException>()),
      );
    });

    test('callService sends a command and completes with its result', () async {
      final connector = FakeConnector();
      final client = HaWebSocketClient(
        config: _config,
        connector: connector.connect,
      );
      addTearDown(client.dispose);

      await client.connect();
      await pumpEventQueue();
      final socket = connector.last;
      await completeHandshake(socket);

      final future = client.callService(
        'light',
        'turn_on',
        target: {'entity_id': 'light.kitchen'},
      );
      await pumpEventQueue();

      final call = socket.sentOfType('call_service').single;
      expect(call['domain'], 'light');
      expect(call['service'], 'turn_on');
      expect(call['target'], {'entity_id': 'light.kitchen'});
      // The command id must keep increasing past the handshake ids.
      expect(
        call['id'],
        greaterThan(socket.sentOfType('get_states').single['id'] as int),
      );

      socket.serverSend({
        'id': call['id'],
        'type': 'result',
        'success': true,
        'result': {'context': 'abc'},
      });
      expect(await future, {'context': 'abc'});
    });

    test(
      'callService surfaces a command error as HaCommandException',
      () async {
        final connector = FakeConnector();
        final client = HaWebSocketClient(
          config: _config,
          connector: connector.connect,
        );
        addTearDown(client.dispose);

        await client.connect();
        await pumpEventQueue();
        final socket = connector.last;
        await completeHandshake(socket);

        final future = client.callService('light', 'turn_on');
        await pumpEventQueue();
        final call = socket.sentOfType('call_service').single;

        socket.serverSend({
          'id': call['id'],
          'type': 'result',
          'success': false,
          'error': {'code': 'not_found', 'message': 'Entity not found'},
        });

        await expectLater(
          future,
          throwsA(
            isA<HaCommandException>()
                .having((e) => e.message, 'message', 'Entity not found')
                .having((e) => e.code, 'code', 'not_found'),
          ),
        );
      },
    );
  });

  group('HaWebSocketClient — robustness', () {
    test(
      'a state_changed during the seed window survives the snapshot',
      () async {
        final connector = FakeConnector();
        final client = HaWebSocketClient(
          config: _config,
          connector: connector.connect,
        );
        addTearDown(client.dispose);

        await client.connect();
        await pumpEventQueue();
        final socket = connector.last;

        socket.serverSend({'type': 'auth_required'});
        await pumpEventQueue();
        socket.serverSend({'type': 'auth_ok'});
        await pumpEventQueue();
        final subscribe = socket.sentOfType('subscribe_events').single;
        final getStates = socket.sentOfType('get_states').single;

        // Subscribe ack, then a LIVE event flips the light to 'on'...
        socket.serverSend({
          'id': subscribe['id'],
          'type': 'result',
          'success': true,
          'result': null,
        });
        socket.serverSend({
          'type': 'event',
          'event': {
            'event_type': 'state_changed',
            'data': {
              'entity_id': 'light.kitchen',
              'new_state': {'entity_id': 'light.kitchen', 'state': 'on'},
            },
          },
        });
        // ...then the (older) get_states snapshot still says 'off'.
        socket.serverSend({
          'id': getStates['id'],
          'type': 'result',
          'success': true,
          'result': [
            {'entity_id': 'light.kitchen', 'state': 'off'},
          ],
        });
        await pumpEventQueue();

        // The live event must win — not be clobbered by the snapshot replace.
        expect(client.connectionState.status, HaConnectionStatus.connected);
        expect(client.entity('light.kitchen')?.state, 'on');
      },
    );

    test('a malformed frame is skipped without crashing or dropping', () async {
      final connector = FakeConnector();
      final client = HaWebSocketClient(
        config: _config,
        connector: connector.connect,
      );
      addTearDown(client.dispose);

      await client.connect();
      await pumpEventQueue();
      final socket = connector.last;
      await completeHandshake(socket);

      // new_state lacking entity_id makes EntityState.fromJson throw; the
      // listener must swallow it rather than letting it escape to the zone.
      socket.serverSend({
        'type': 'event',
        'event': {
          'event_type': 'state_changed',
          'data': {
            'entity_id': 'light.kitchen',
            'new_state': {'state': 'on'}, // no entity_id
          },
        },
      });
      await pumpEventQueue();

      expect(client.connectionState.status, HaConnectionStatus.connected);
    });

    test('removing an unknown entity emits nothing', () async {
      final connector = FakeConnector();
      final client = HaWebSocketClient(
        config: _config,
        connector: connector.connect,
      );
      addTearDown(client.dispose);

      await client.connect();
      await pumpEventQueue();
      final socket = connector.last;
      await completeHandshake(
        socket,
        states: [
          {'entity_id': 'light.kitchen', 'state': 'on'},
        ],
      );

      final emissions = <Map<String, EntityState>>[];
      client.entityStates.listen(emissions.add);

      socket.serverSend({
        'type': 'event',
        'event': {
          'event_type': 'state_changed',
          'data': {'entity_id': 'light.ghost', 'new_state': null},
        },
      });
      await pumpEventQueue();

      expect(emissions, isEmpty, reason: 'no-op removal must not emit');
      expect(client.entity('light.kitchen')?.state, 'on');
    });

    test('entityStates emits an unmodifiable snapshot', () async {
      final connector = FakeConnector();
      final client = HaWebSocketClient(
        config: _config,
        connector: connector.connect,
      );
      addTearDown(client.dispose);

      await client.connect();
      await pumpEventQueue();
      final socket = connector.last;
      await completeHandshake(socket);

      final emissions = <Map<String, EntityState>>[];
      client.entityStates.listen(emissions.add);

      socket.serverSend({
        'type': 'event',
        'event': {
          'event_type': 'state_changed',
          'data': {
            'entity_id': 'light.kitchen',
            'new_state': {'entity_id': 'light.kitchen', 'state': 'on'},
          },
        },
      });
      await pumpEventQueue();

      expect(emissions, isNotEmpty);
      expect(
        () =>
            emissions.last['x'] = const EntityState(entityId: 'x', state: 'on'),
        throwsUnsupportedError,
      );
    });
  });
}

/// Drives a fake socket through the full handshake on a [FakeAsync] virtual
/// clock (the real-event-queue variant lives in the shared `fakes` helper).
void _completeHandshakeSync(
  FakeAsync async,
  FakeHaSocket socket, {
  List<Map<String, dynamic>> states = const [],
}) {
  socket.serverSend({'type': 'auth_required'});
  async.flushMicrotasks();
  socket.serverSend({'type': 'auth_ok'});
  async.flushMicrotasks();
  final subscribe = socket.sentOfType('subscribe_events').last;
  final getStates = socket.sentOfType('get_states').last;
  socket.serverSend({
    'id': subscribe['id'],
    'type': 'result',
    'success': true,
    'result': null,
  });
  socket.serverSend({
    'id': getStates['id'],
    'type': 'result',
    'success': true,
    'result': states,
  });
  async.flushMicrotasks();
}
