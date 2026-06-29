import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/data/ha_websocket_client.dart';
import 'package:homeassistant_flutter/features/connection/domain/entity_state.dart';
import 'package:homeassistant_flutter/features/connection/domain/ha_connection_config.dart';
import 'package:homeassistant_flutter/features/entities/application/entity_toggle_controller.dart';

import '../../connection/fakes/fake_ha_socket.dart';

final _config = HaConnectionConfig(
  baseUrl: Uri.parse('http://localhost:8123'),
  accessToken: 'test-token',
);

EntityState _entity(String id, {String state = 'off', String? friendlyName}) {
  return EntityState(
    entityId: id,
    state: state,
    attributes: friendlyName == null
        ? const {}
        : {'friendly_name': friendlyName},
  );
}

/// Spins up a real [HaWebSocketClient] driven by a [FakeHaSocket], leaves it
/// connected, and returns both so the test can play the server for the
/// `call_service` command.
Future<(EntityToggleController, FakeHaSocket)> _connectedController() async {
  final connector = FakeConnector();
  final client = HaWebSocketClient(
    config: _config,
    connector: connector.connect,
  );
  addTearDown(client.dispose);

  await client.connect();
  await pumpEventQueue();
  await completeHandshake(connector.last);

  return (EntityToggleController(client), connector.last);
}

void main() {
  test('turning a light on issues light.turn_on and reports success', () async {
    final (controller, socket) = await _connectedController();

    final future = controller.toggle(_entity('light.kitchen'), on: true);
    await pumpEventQueue();

    // The client sent the right call_service command.
    final call = socket.sentOfType('call_service').last;
    expect(call['domain'], 'light');
    expect(call['service'], 'turn_on');
    expect(call['target'], {'entity_id': 'light.kitchen'});

    // The server accepts it.
    socket.serverSend({
      'id': call['id'],
      'type': 'result',
      'success': true,
      'result': null,
    });

    final result = await future;
    expect(result.isSuccess, isTrue);
  });

  test('turning a switch off issues switch.turn_off', () async {
    final (controller, socket) = await _connectedController();

    final future = controller.toggle(
      _entity('switch.fan', state: 'on'),
      on: false,
    );
    await pumpEventQueue();

    final call = socket.sentOfType('call_service').last;
    expect(call['domain'], 'switch');
    expect(call['service'], 'turn_off');
    expect(call['target'], {'entity_id': 'switch.fan'});

    socket.serverSend({
      'id': call['id'],
      'type': 'result',
      'success': true,
      'result': null,
    });

    expect((await future).isSuccess, isTrue);
  });

  test('a failed command is surfaced as a ToggleFailure, not thrown', () async {
    final (controller, socket) = await _connectedController();

    final future = controller.toggle(
      _entity('light.kitchen', friendlyName: 'Kitchen'),
      on: true,
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
    final failure = result as ToggleFailure;
    expect(failure.message, contains('Kitchen'));
    expect(failure.message, contains('Entity not found'));
  });

  test('a non-toggleable entity fails fast without a service call', () async {
    final (controller, socket) = await _connectedController();

    final result = await controller.toggle(_entity('sensor.temp'), on: true);

    expect(result.isSuccess, isFalse);
    expect(socket.sentOfType('call_service'), isEmpty);
  });
}
