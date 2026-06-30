import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/data/ha_websocket_client.dart';
import 'package:homeassistant_flutter/features/connection/domain/ha_connection_config.dart';
import 'package:homeassistant_flutter/features/connection/domain/ha_exception.dart';
import 'package:homeassistant_flutter/features/dashboard/data/lovelace_repository.dart';
import 'package:homeassistant_flutter/features/dashboard/domain/lovelace_card.dart';

import '../../connection/fakes/fake_ha_socket.dart';

void main() {
  final config = HaConnectionConfig(
    baseUrl: Uri.parse('http://localhost:8123'),
    accessToken: 'token',
  );

  /// A live, connected client driven by a fake socket, plus its connector so the
  /// test can play the server side of the `lovelace/config` command.
  Future<(HaWebSocketClient, FakeConnector)> connectedClient() async {
    final connector = FakeConnector();
    final client = HaWebSocketClient(
      config: config,
      connector: connector.connect,
    );
    addTearDown(client.dispose);
    await client.connect();
    await completeHandshake(connector.last);
    return (client, connector);
  }

  test('fetchConfig sends lovelace/config and parses the result', () async {
    final (client, connector) = await connectedClient();
    final repo = LovelaceRepository(client);

    final future = repo.fetchConfig();
    await pumpEventQueue();

    final command = connector.last.sentOfType('lovelace/config').last;
    expect(command['url_path'], isNull); // default dashboard
    connector.last.serverSend({
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

    final lovelace = await future;
    expect(lovelace.title, 'Home');
    expect(
      lovelace.firstView!.cards.single,
      const EntityCard(entityId: 'sensor.temperature'),
    );
  });

  test('propagates a command failure (e.g. YAML-mode dashboard)', () async {
    final (client, connector) = await connectedClient();
    final repo = LovelaceRepository(client);

    final future = repo.fetchConfig();
    await pumpEventQueue();

    final command = connector.last.sentOfType('lovelace/config').last;
    connector.last.serverSend({
      'id': command['id'],
      'type': 'result',
      'success': false,
      'error': {'code': 'config_not_found', 'message': 'No Lovelace config'},
    });

    await expectLater(future, throwsA(isA<HaCommandException>()));
  });
}
