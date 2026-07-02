import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/data/ha_websocket_client.dart';
import 'package:homeassistant_flutter/features/connection/domain/entity_state.dart';
import 'package:homeassistant_flutter/features/connection/domain/ha_connection_config.dart';
import 'package:homeassistant_flutter/features/entities/application/climate_control_controller.dart';

import '../../connection/fakes/fake_ha_socket.dart';

final _config = HaConnectionConfig(
  baseUrl: Uri.parse('http://localhost:8123'),
  accessToken: 'test-token',
);

EntityState _climate(
  String id, {
  String state = 'heat',
  String? friendlyName,
  Map<String, Object?> attributes = const {},
}) {
  return EntityState(
    entityId: id,
    state: state,
    attributes: {...attributes, 'friendly_name': ?friendlyName},
  );
}

/// Spins up a real [HaWebSocketClient] driven by a [FakeHaSocket], leaves it
/// connected, and returns both so the test can play the server for the
/// `call_service` command. Mirrors `entity_toggle_controller_test.dart`.
Future<(ClimateControlController, FakeHaSocket)> _connectedController() async {
  final connector = FakeConnector();
  final client = HaWebSocketClient(
    config: _config,
    connector: connector.connect,
  );
  addTearDown(client.dispose);

  await client.connect();
  await pumpEventQueue();
  await completeHandshake(connector.last);

  return (ClimateControlController(client), connector.last);
}

void main() {
  group('setTemperature', () {
    test('issues climate.set_temperature targeting the entity', () async {
      final (controller, socket) = await _connectedController();

      final future = controller.setTemperature(
        _climate('climate.living_room'),
        temperature: 21.5,
      );
      await pumpEventQueue();

      final call = socket.sentOfType('call_service').last;
      expect(call['domain'], 'climate');
      expect(call['service'], 'set_temperature');
      expect(call['service_data'], {'temperature': 21.5});
      expect(call['target'], {'entity_id': 'climate.living_room'});

      socket.serverSend({
        'id': call['id'],
        'type': 'result',
        'success': true,
        'result': null,
      });

      expect((await future).isSuccess, isTrue);
    });

    test('a failed command is surfaced as a failure, not thrown', () async {
      final (controller, socket) = await _connectedController();

      final future = controller.setTemperature(
        _climate('climate.living_room', friendlyName: 'Living Room'),
        temperature: 21.5,
      );
      await pumpEventQueue();

      final call = socket.sentOfType('call_service').last;
      socket.serverSend({
        'id': call['id'],
        'type': 'result',
        'success': false,
        'error': {'code': 'not_found', 'message': 'Entity not found'},
      });

      final result = await future;
      expect(result.isSuccess, isFalse);
      final failure = result as ClimateActionFailure;
      expect(failure.message, contains('Living Room'));
      expect(failure.message, contains('Entity not found'));
    });
  });

  group('setHvacMode', () {
    test('issues climate.set_hvac_mode targeting the entity', () async {
      final (controller, socket) = await _connectedController();

      final future = controller.setHvacMode(
        _climate('climate.living_room'),
        'cool',
      );
      await pumpEventQueue();

      final call = socket.sentOfType('call_service').last;
      expect(call['domain'], 'climate');
      expect(call['service'], 'set_hvac_mode');
      expect(call['service_data'], {'hvac_mode': 'cool'});
      expect(call['target'], {'entity_id': 'climate.living_room'});

      socket.serverSend({
        'id': call['id'],
        'type': 'result',
        'success': true,
        'result': null,
      });

      expect((await future).isSuccess, isTrue);
    });

    test('a failed command is surfaced as a failure, not thrown', () async {
      final (controller, socket) = await _connectedController();

      final future = controller.setHvacMode(
        _climate('climate.living_room', friendlyName: 'Living Room'),
        'cool',
      );
      await pumpEventQueue();

      final call = socket.sentOfType('call_service').last;
      socket.serverSend({
        'id': call['id'],
        'type': 'result',
        'success': false,
        'error': {'code': 'unknown_error', 'message': 'boom'},
      });

      final result = await future;
      expect(result.isSuccess, isFalse);
      final failure = result as ClimateActionFailure;
      expect(failure.message, contains('Living Room'));
      expect(failure.message, contains('boom'));
    });
  });
}
