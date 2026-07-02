import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/data/ha_websocket_client.dart';
import 'package:homeassistant_flutter/features/connection/domain/entity_state.dart';
import 'package:homeassistant_flutter/features/connection/domain/ha_connection_config.dart';
import 'package:homeassistant_flutter/features/entities/application/media_player_control_controller.dart';

import '../../connection/fakes/fake_ha_socket.dart';

final _config = HaConnectionConfig(
  baseUrl: Uri.parse('http://localhost:8123'),
  accessToken: 'test-token',
);

EntityState _mediaPlayer(
  String id, {
  String state = 'playing',
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
/// `call_service` command. Mirrors `climate_control_controller_test.dart`.
Future<(MediaPlayerControlController, FakeHaSocket)>
_connectedController() async {
  final connector = FakeConnector();
  final client = HaWebSocketClient(
    config: _config,
    connector: connector.connect,
  );
  addTearDown(client.dispose);

  await client.connect();
  await pumpEventQueue();
  await completeHandshake(connector.last);

  return (MediaPlayerControlController(client), connector.last);
}

void main() {
  group('playPause', () {
    test('issues media_player.media_play_pause targeting the entity', () async {
      final (controller, socket) = await _connectedController();

      final future = controller.playPause(
        _mediaPlayer('media_player.living_room'),
      );
      await pumpEventQueue();

      final call = socket.sentOfType('call_service').last;
      expect(call['domain'], 'media_player');
      expect(call['service'], 'media_play_pause');
      expect(call['target'], {'entity_id': 'media_player.living_room'});

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

      final future = controller.playPause(
        _mediaPlayer(
          'media_player.living_room',
          friendlyName: 'Living Room Speaker',
        ),
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
      final failure = result as MediaPlayerActionFailure;
      expect(failure.message, contains('Living Room Speaker'));
      expect(failure.message, contains('Entity not found'));
    });
  });

  group('nextTrack', () {
    test('issues media_player.media_next_track targeting the entity', () async {
      final (controller, socket) = await _connectedController();

      final future = controller.nextTrack(
        _mediaPlayer('media_player.living_room'),
      );
      await pumpEventQueue();

      final call = socket.sentOfType('call_service').last;
      expect(call['domain'], 'media_player');
      expect(call['service'], 'media_next_track');
      expect(call['target'], {'entity_id': 'media_player.living_room'});

      socket.serverSend({
        'id': call['id'],
        'type': 'result',
        'success': true,
        'result': null,
      });

      expect((await future).isSuccess, isTrue);
    });
  });

  group('previousTrack', () {
    test(
      'issues media_player.media_previous_track targeting the entity',
      () async {
        final (controller, socket) = await _connectedController();

        final future = controller.previousTrack(
          _mediaPlayer('media_player.living_room'),
        );
        await pumpEventQueue();

        final call = socket.sentOfType('call_service').last;
        expect(call['domain'], 'media_player');
        expect(call['service'], 'media_previous_track');
        expect(call['target'], {'entity_id': 'media_player.living_room'});

        socket.serverSend({
          'id': call['id'],
          'type': 'result',
          'success': true,
          'result': null,
        });

        expect((await future).isSuccess, isTrue);
      },
    );
  });

  group('setVolume', () {
    test(
      'issues media_player.volume_set with the 0.0-1.0 volume_level',
      () async {
        final (controller, socket) = await _connectedController();

        final future = controller.setVolume(
          _mediaPlayer('media_player.living_room'),
          0.75,
        );
        await pumpEventQueue();

        final call = socket.sentOfType('call_service').last;
        expect(call['domain'], 'media_player');
        expect(call['service'], 'volume_set');
        expect(call['service_data'], {'volume_level': 0.75});
        expect(call['target'], {'entity_id': 'media_player.living_room'});

        socket.serverSend({
          'id': call['id'],
          'type': 'result',
          'success': true,
          'result': null,
        });

        expect((await future).isSuccess, isTrue);
      },
    );

    test('a failed command is surfaced as a failure, not thrown', () async {
      final (controller, socket) = await _connectedController();

      final future = controller.setVolume(
        _mediaPlayer(
          'media_player.living_room',
          friendlyName: 'Living Room Speaker',
        ),
        0.5,
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
      final failure = result as MediaPlayerActionFailure;
      expect(failure.message, contains('Living Room Speaker'));
      expect(failure.message, contains('boom'));
    });
  });
}
