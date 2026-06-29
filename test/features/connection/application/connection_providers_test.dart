import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/application/connection_providers.dart';
import 'package:homeassistant_flutter/features/connection/data/ha_rest_client.dart';
import 'package:homeassistant_flutter/features/connection/data/ha_websocket_client.dart';
import 'package:homeassistant_flutter/features/connection/domain/connection_status.dart';
import 'package:homeassistant_flutter/features/connection/domain/ha_connection_config.dart';

import '../fakes/fake_ha_socket.dart';

final _config = HaConnectionConfig(
  baseUrl: Uri.parse('http://localhost:8123'),
  accessToken: 'test-token',
);

void main() {
  test('haConnectionConfigProvider throws until it is overridden', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      () => container.read(haConnectionConfigProvider),
      throwsA(isA<UnimplementedError>()),
    );
  });

  test('haRestClientProvider builds once the config is overridden', () {
    final container = ProviderContainer(
      overrides: [haConnectionConfigProvider.overrideWithValue(_config)],
    );
    addTearDown(container.dispose);

    expect(container.read(haRestClientProvider), isA<HaRestClient>());
  });

  test(
    'connectionState and entity providers reflect the live client',
    () async {
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

      // Keep the stream providers alive for the duration of the test.
      container.listen(connectionStateProvider, (_, _) {});
      container.listen(entityStatesProvider, (_, _) {});

      await client.connect();
      await pumpEventQueue();
      await completeHandshake(
        connector.last,
        states: [
          {'entity_id': 'light.kitchen', 'state': 'on'},
        ],
      );
      await pumpEventQueue();

      expect(
        container.read(connectionStateProvider).value?.status,
        HaConnectionStatus.connected,
      );
      expect(container.read(entityProvider('light.kitchen'))?.state, 'on');
      expect(container.read(entityProvider('light.unknown')), isNull);
    },
  );
}
