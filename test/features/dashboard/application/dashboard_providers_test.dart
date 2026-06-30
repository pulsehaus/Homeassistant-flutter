import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/application/connection_providers.dart';
import 'package:homeassistant_flutter/features/connection/data/ha_websocket_client.dart';
import 'package:homeassistant_flutter/features/connection/domain/ha_connection_config.dart';
import 'package:homeassistant_flutter/features/connection/domain/ha_exception.dart';
import 'package:homeassistant_flutter/features/dashboard/application/dashboard_providers.dart';

import '../../connection/fakes/fake_ha_socket.dart';

final _config = HaConnectionConfig(
  baseUrl: Uri.parse('http://localhost:8123'),
  accessToken: 'token',
);

/// Build a container wired to a fake-socket client, with both the connection
/// config and the WebSocket client overridden so the gated dashboard provider
/// resolves in the same scope as production (see [haWebSocketClientProvider]).
({
  ProviderContainer container,
  HaWebSocketClient client,
  FakeConnector connector,
})
_harness() {
  final connector = FakeConnector();
  final client = HaWebSocketClient(
    config: _config,
    connector: connector.connect,
  );
  addTearDown(client.dispose);

  final container = ProviderContainer(
    overrides: [
      haConnectionConfigProvider.overrideWithValue(_config),
      haWebSocketClientProvider.overrideWithValue(client),
    ],
  );
  addTearDown(container.dispose);

  return (container: container, client: client, connector: connector);
}

/// Respond to the pending `lovelace/config` command with a minimal valid config.
void _respondWithConfig(FakeHaSocket socket) {
  final command = socket.sentOfType('lovelace/config').last;
  socket.serverSend({
    'id': command['id'],
    'type': 'result',
    'success': true,
    'result': {
      'title': 'Home',
      'views': [
        {
          'cards': [
            {'type': 'entity', 'entity': 'sensor.temperature'},
          ],
        },
      ],
    },
  });
}

void main() {
  test('stays loading while connecting, then fetches once connected', () async {
    final h = _harness();
    // Keep the gated stream alive for the whole test.
    h.container.listen(dashboardConfigStreamProvider, (_, _) {});

    // Begin connecting but do NOT complete the handshake yet.
    await h.client.connect();
    await pumpEventQueue();

    // Cold start: the socket is still connecting, so the config provider must
    // stay loading instead of surfacing a "disconnected" error — and it must
    // not have sent the lovelace/config command yet.
    expect(h.client.connectionState.isConnected, isFalse);
    expect(h.container.read(dashboardConfigStreamProvider).isLoading, isTrue);
    expect(h.connector.last.sentOfType('lovelace/config'), isEmpty);

    // The socket connects; the gated stream now fetches automatically.
    await completeHandshake(h.connector.last);
    await pumpEventQueue();
    _respondWithConfig(h.connector.last);
    await pumpEventQueue();

    final value = h.container.read(dashboardConfigStreamProvider);
    expect(value.isLoading, isFalse);
    expect(value.hasError, isFalse);
    expect(value.value?.title, 'Home');
  });

  test('already-connected client fetches immediately', () async {
    final h = _harness();
    h.container.listen(dashboardConfigStreamProvider, (_, _) {});

    // Connect first, then read the provider — it should skip the gate and fetch.
    await h.client.connect();
    await completeHandshake(h.connector.last);
    await pumpEventQueue();

    expect(h.client.connectionState.isConnected, isTrue);
    _respondWithConfig(h.connector.last);
    await pumpEventQueue();

    expect(
      h.container.read(dashboardConfigStreamProvider).value?.title,
      'Home',
    );
  });

  test('surfaces a fatal connection error (invalid token)', () async {
    final h = _harness();
    h.container.listen(dashboardConfigStreamProvider, (_, _) {});

    await h.client.connect();
    await pumpEventQueue();

    // Still loading while connecting/authenticating.
    expect(h.container.read(dashboardConfigStreamProvider).isLoading, isTrue);

    // The server rejects the token → fatal, non-retryable error state.
    h.connector.last.serverSend({'type': 'auth_required'});
    await pumpEventQueue();
    h.connector.last.serverSend({
      'type': 'auth_invalid',
      'message': 'Invalid access token',
    });
    await pumpEventQueue();

    final value = h.container.read(dashboardConfigStreamProvider);
    expect(value.hasError, isTrue);
    expect(value.error, isA<HaAuthException>());
    // It never tried to fetch the config over the dead socket.
    expect(h.connector.last.sentOfType('lovelace/config'), isEmpty);
  });
}
