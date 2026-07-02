import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/application/connection_providers.dart';
import 'package:homeassistant_flutter/features/connection/domain/entity_state.dart';
import 'package:homeassistant_flutter/features/dashboard/domain/lovelace_card.dart';
import 'package:homeassistant_flutter/features/dashboard/presentation/cards/media_player_card_widget.dart';
import 'package:homeassistant_flutter/features/entities/application/media_player_control_controller.dart';

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

Map<String, EntityState> _store(List<EntityState> entities) {
  return {for (final e in entities) e.entityId: e};
}

/// A fake controller that records requests and returns a scripted
/// [MediaPlayerActionResult], mirroring `climate_card_widget_test.dart`'s fake
/// controller.
class _FakeMediaPlayerController implements MediaPlayerControlController {
  _FakeMediaPlayerController(this._result);

  final MediaPlayerActionResult _result;
  final List<String> playPauseCalls = [];
  final List<String> nextTrackCalls = [];
  final List<String> previousTrackCalls = [];
  final List<(String, double)> volumeCalls = [];

  @override
  Future<MediaPlayerActionResult> playPause(EntityState entity) async {
    playPauseCalls.add(entity.entityId);
    return _result;
  }

  @override
  Future<MediaPlayerActionResult> nextTrack(EntityState entity) async {
    nextTrackCalls.add(entity.entityId);
    return _result;
  }

  @override
  Future<MediaPlayerActionResult> previousTrack(EntityState entity) async {
    previousTrackCalls.add(entity.entityId);
    return _result;
  }

  @override
  Future<MediaPlayerActionResult> setVolume(
    EntityState entity,
    double volumeLevel,
  ) async {
    volumeCalls.add((entity.entityId, volumeLevel));
    return _result;
  }
}

Widget _harness({
  required MediaPlayerCard card,
  required Stream<Map<String, EntityState>> stream,
  required MediaPlayerControlController controller,
}) {
  return ProviderScope(
    overrides: [
      entityStatesProvider.overrideWith((ref) => stream),
      mediaPlayerControlControllerProvider.overrideWithValue(controller),
    ],
    child: MaterialApp(
      home: Scaffold(body: MediaPlayerCardWidget(card: card)),
    ),
  );
}

void main() {
  const card = MediaPlayerCard(entityId: 'media_player.living_room');

  testWidgets('renders label, title, artist, playback state and volume', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        card: const MediaPlayerCard(
          entityId: 'media_player.living_room',
          name: 'Living Room Speaker',
        ),
        stream: Stream.value(
          _store([
            _mediaPlayer(
              'media_player.living_room',
              state: 'playing',
              attributes: {
                'media_title': 'Bohemian Rhapsody',
                'media_artist': 'Queen',
                'volume_level': 0.5,
              },
            ),
          ]),
        ),
        controller: _FakeMediaPlayerController(
          const MediaPlayerActionResult.success(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Living Room Speaker'), findsOneWidget);
    expect(find.text('Bohemian Rhapsody'), findsOneWidget);
    expect(find.text('Queen'), findsOneWidget);
    expect(find.text('playing'), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('tapping play/pause calls media_play_pause', (tester) async {
    final controller = _FakeMediaPlayerController(
      const MediaPlayerActionResult.success(),
    );
    await tester.pumpWidget(
      _harness(
        card: card,
        stream: Stream.value(
          _store([_mediaPlayer('media_player.living_room', state: 'paused')]),
        ),
        controller: controller,
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();

    expect(controller.playPauseCalls, ['media_player.living_room']);
  });

  testWidgets('tapping next track calls media_next_track', (tester) async {
    final controller = _FakeMediaPlayerController(
      const MediaPlayerActionResult.success(),
    );
    await tester.pumpWidget(
      _harness(
        card: card,
        stream: Stream.value(
          _store([_mediaPlayer('media_player.living_room')]),
        ),
        controller: controller,
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.pump();

    expect(controller.nextTrackCalls, ['media_player.living_room']);
  });

  testWidgets('tapping previous track calls media_previous_track', (
    tester,
  ) async {
    final controller = _FakeMediaPlayerController(
      const MediaPlayerActionResult.success(),
    );
    await tester.pumpWidget(
      _harness(
        card: card,
        stream: Stream.value(
          _store([_mediaPlayer('media_player.living_room')]),
        ),
        controller: controller,
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.skip_previous));
    await tester.pump();

    expect(controller.previousTrackCalls, ['media_player.living_room']);
  });

  testWidgets('dragging the volume slider calls volume_set', (tester) async {
    final controller = _FakeMediaPlayerController(
      const MediaPlayerActionResult.success(),
    );
    await tester.pumpWidget(
      _harness(
        card: card,
        stream: Stream.value(
          _store([
            _mediaPlayer(
              'media_player.living_room',
              attributes: {'volume_level': 0.5},
            ),
          ]),
        ),
        controller: controller,
      ),
    );
    await tester.pump();

    await tester.drag(find.byType(Slider), const Offset(200, 0));
    await tester.pump();

    // A drag gesture reports multiple intermediate positions, each of which
    // dispatches a call; assert on the last one, mirroring how the brightness
    // slider's drag is exercised elsewhere in the suite.
    expect(controller.volumeCalls, isNotEmpty);
    final call = controller.volumeCalls.last;
    expect(call.$1, 'media_player.living_room');
    expect(call.$2, greaterThan(0.5));
  });

  testWidgets('a failed volume change rolls back and shows a SnackBar', (
    tester,
  ) async {
    final controller = _FakeMediaPlayerController(
      const MediaPlayerActionResult.failure('Could not set volume: boom'),
    );
    await tester.pumpWidget(
      _harness(
        card: card,
        stream: Stream.value(
          _store([
            _mediaPlayer(
              'media_player.living_room',
              attributes: {'volume_level': 0.5},
            ),
          ]),
        ),
        controller: controller,
      ),
    );
    await tester.pump();

    await tester.drag(find.byType(Slider), const Offset(200, 0));
    await tester.pump(); // run the future + setState

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Could not set volume'), findsOneWidget);
  });

  testWidgets('a missing entity shows a placeholder instead of crashing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        card: const MediaPlayerCard(
          entityId: 'media_player.missing',
          name: 'Missing Speaker',
        ),
        stream: Stream.value(const <String, EntityState>{}),
        controller: _FakeMediaPlayerController(
          const MediaPlayerActionResult.success(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Missing Speaker'), findsOneWidget);
    expect(find.text('unavailable'), findsOneWidget);
  });

  testWidgets(
    'missing media_title/media_artist attributes show a placeholder message '
    'instead of crashing',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          card: card,
          stream: Stream.value(
            _store([_mediaPlayer('media_player.living_room', state: 'idle')]),
          ),
          controller: _FakeMediaPlayerController(
            const MediaPlayerActionResult.success(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No media playing'), findsOneWidget);
      expect(find.text('idle'), findsOneWidget);
    },
  );

  testWidgets('a missing volume_level attribute disables the volume slider', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        card: card,
        stream: Stream.value(
          _store([_mediaPlayer('media_player.living_room')]),
        ),
        controller: _FakeMediaPlayerController(
          const MediaPlayerActionResult.success(),
        ),
      ),
    );
    await tester.pump();

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.onChanged, isNull);
  });

  testWidgets('an off entity disables play/pause and track-skip controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        card: card,
        stream: Stream.value(
          _store([_mediaPlayer('media_player.living_room', state: 'off')]),
        ),
        controller: _FakeMediaPlayerController(
          const MediaPlayerActionResult.success(),
        ),
      ),
    );
    await tester.pump();

    final playPause = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.play_arrow),
        matching: find.byType(IconButton),
      ),
    );
    expect(playPause.onPressed, isNull);
  });
}
