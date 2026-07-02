import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/domain/entity_state.dart';
import 'package:homeassistant_flutter/features/entities/domain/media_player_control.dart';

EntityState _mediaPlayer(
  String id, {
  String state = 'playing',
  Map<String, Object?> attributes = const {},
}) {
  return EntityState(entityId: id, state: state, attributes: attributes);
}

void main() {
  group('MediaPlayerControl.mediaTitle', () {
    test('reads the media_title attribute', () {
      final entity = _mediaPlayer(
        'media_player.living_room',
        attributes: {'media_title': 'Bohemian Rhapsody'},
      );
      expect(MediaPlayerControl.mediaTitle(entity), 'Bohemian Rhapsody');
    });

    test('is null when missing', () {
      expect(
        MediaPlayerControl.mediaTitle(_mediaPlayer('media_player.living_room')),
        isNull,
      );
    });

    test('is null when blank or non-string', () {
      expect(
        MediaPlayerControl.mediaTitle(
          _mediaPlayer(
            'media_player.living_room',
            attributes: {'media_title': '   '},
          ),
        ),
        isNull,
      );
      expect(
        MediaPlayerControl.mediaTitle(
          _mediaPlayer(
            'media_player.living_room',
            attributes: {'media_title': 42},
          ),
        ),
        isNull,
      );
    });
  });

  group('MediaPlayerControl.mediaArtist', () {
    test('reads the media_artist attribute', () {
      final entity = _mediaPlayer(
        'media_player.living_room',
        attributes: {'media_artist': 'Queen'},
      );
      expect(MediaPlayerControl.mediaArtist(entity), 'Queen');
    });

    test('is null when missing', () {
      expect(
        MediaPlayerControl.mediaArtist(
          _mediaPlayer('media_player.living_room'),
        ),
        isNull,
      );
    });
  });

  group('MediaPlayerControl.volumeLevel', () {
    test('reads the volume_level attribute', () {
      final entity = _mediaPlayer(
        'media_player.living_room',
        attributes: {'volume_level': 0.5},
      );
      expect(MediaPlayerControl.volumeLevel(entity), 0.5);
    });

    test('is null when the player does not report one at all', () {
      expect(
        MediaPlayerControl.volumeLevel(
          _mediaPlayer('media_player.living_room'),
        ),
        isNull,
      );
    });

    test('is null when non-numeric', () {
      expect(
        MediaPlayerControl.volumeLevel(
          _mediaPlayer(
            'media_player.living_room',
            attributes: {'volume_level': 'loud'},
          ),
        ),
        isNull,
      );
    });
  });

  group('MediaPlayerControl.supportsVolume', () {
    test('is true when volume_level is present', () {
      expect(
        MediaPlayerControl.supportsVolume(
          _mediaPlayer(
            'media_player.living_room',
            attributes: {'volume_level': 0.2},
          ),
        ),
        isTrue,
      );
    });

    test('is false when volume_level is absent (e.g. a basic Chromecast '
        'target or a TV with no volume feedback)', () {
      expect(
        MediaPlayerControl.supportsVolume(
          _mediaPlayer('media_player.living_room'),
        ),
        isFalse,
      );
    });
  });

  group('MediaPlayerControl.playPauseCommand', () {
    test(
      'builds a media_player.media_play_pause call targeting the entity',
      () {
        final command = MediaPlayerControl.playPauseCommand(
          _mediaPlayer('media_player.living_room'),
        );

        expect(command.domain, 'media_player');
        expect(command.service, 'media_play_pause');
        expect(command.serviceData, isEmpty);
        expect(command.target, {'entity_id': 'media_player.living_room'});
      },
    );
  });

  group('MediaPlayerControl.nextTrackCommand', () {
    test(
      'builds a media_player.media_next_track call targeting the entity',
      () {
        final command = MediaPlayerControl.nextTrackCommand(
          _mediaPlayer('media_player.living_room'),
        );

        expect(command.domain, 'media_player');
        expect(command.service, 'media_next_track');
        expect(command.target, {'entity_id': 'media_player.living_room'});
      },
    );
  });

  group('MediaPlayerControl.previousTrackCommand', () {
    test(
      'builds a media_player.media_previous_track call targeting the entity',
      () {
        final command = MediaPlayerControl.previousTrackCommand(
          _mediaPlayer('media_player.living_room'),
        );

        expect(command.domain, 'media_player');
        expect(command.service, 'media_previous_track');
        expect(command.target, {'entity_id': 'media_player.living_room'});
      },
    );
  });

  group('MediaPlayerControl.volumeSetCommand', () {
    test('builds a media_player.volume_set call with the 0.0-1.0 float '
        'volume_level, not the 0-255 int range used by light brightness', () {
      final command = MediaPlayerControl.volumeSetCommand(
        _mediaPlayer('media_player.living_room'),
        0.42,
      );

      expect(command.domain, 'media_player');
      expect(command.service, 'volume_set');
      expect(command.serviceData, {'volume_level': 0.42});
      expect(command.target, {'entity_id': 'media_player.living_room'});
    });

    test('clamps the requested volume to 0.0-1.0', () {
      final entity = _mediaPlayer('media_player.living_room');

      expect(MediaPlayerControl.volumeSetCommand(entity, 1.5).serviceData, {
        'volume_level': 1.0,
      });
      expect(MediaPlayerControl.volumeSetCommand(entity, -0.5).serviceData, {
        'volume_level': 0.0,
      });
    });
  });

  test('MediaPlayerCommand uses value equality', () {
    final entity = _mediaPlayer('media_player.living_room');
    final a = MediaPlayerControl.volumeSetCommand(entity, 0.5);
    final b = MediaPlayerControl.volumeSetCommand(entity, 0.5);
    final c = MediaPlayerControl.volumeSetCommand(entity, 0.6);

    expect(a, b);
    expect(a, isNot(c));
  });
}
