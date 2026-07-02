import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../connection/application/connection_providers.dart';
import '../../../connection/domain/entity_state.dart';
import '../../../entities/application/media_player_control_controller.dart';
import '../../../entities/domain/media_player_control.dart';
import '../../domain/lovelace_card.dart';
import 'entity_card_widget.dart' show cardEntityLabel;

/// Renders a `media-control` card: a `media_player` entity (TV, speaker,
/// Chromecast, Sonos, …) showing the title/artist and playback state, with
/// play/pause, next/previous track and a volume slider.
///
/// A [ConsumerStatefulWidget] (like `ClimateCardWidget`) so it can hold an
/// optimistic volume while a `volume_set` call is in flight, reconciling from
/// the live entity once the resulting `state_changed` event lands — the same
/// optimistic-then-reconcile pattern as the brightness slider
/// (`_BrightnessSlider`/`_pendingBrightness` in `entities_overview_page.dart`),
/// applied to the 0.0-1.0 media-player volume range instead of the light
/// domain's 0-255 brightness range. Play/pause and track-skip are dispatched
/// directly with no local optimistic state, mirroring the climate card's
/// `hvac_mode` dropdown: the live `entity.state` (`playing`/`paused`/…)
/// already reflects the outcome once HA processes it.
class MediaPlayerCardWidget extends ConsumerStatefulWidget {
  const MediaPlayerCardWidget({required this.card, super.key});

  final MediaPlayerCard card;

  @override
  ConsumerState<MediaPlayerCardWidget> createState() =>
      _MediaPlayerCardWidgetState();
}

class _MediaPlayerCardWidgetState extends ConsumerState<MediaPlayerCardWidget> {
  /// Optimistic volume (0.0-1.0) shown while a `volume_set` call is in
  /// flight, mirroring `_ClimateCardWidgetState._pendingTemperature`. Cleared
  /// once the live state matches what was requested, or on failure
  /// (rollback).
  double? _pendingVolume;

  MediaPlayerCard get _card => widget.card;

  @override
  void didUpdateWidget(MediaPlayerCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final entity = ref.read(entityProvider(_card.entityId));
    if (_pendingVolume != null &&
        entity != null &&
        MediaPlayerControl.volumeLevel(entity) == _pendingVolume) {
      _pendingVolume = null;
    }
  }

  Future<void> _playPause(EntityState entity) async {
    final result = await ref
        .read(mediaPlayerControlControllerProvider)
        .playPause(entity);
    if (!mounted) return;
    if (!result.isSuccess) {
      _showError((result as MediaPlayerActionFailure).message);
    }
  }

  Future<void> _nextTrack(EntityState entity) async {
    final result = await ref
        .read(mediaPlayerControlControllerProvider)
        .nextTrack(entity);
    if (!mounted) return;
    if (!result.isSuccess) {
      _showError((result as MediaPlayerActionFailure).message);
    }
  }

  Future<void> _previousTrack(EntityState entity) async {
    final result = await ref
        .read(mediaPlayerControlControllerProvider)
        .previousTrack(entity);
    if (!mounted) return;
    if (!result.isSuccess) {
      _showError((result as MediaPlayerActionFailure).message);
    }
  }

  Future<void> _setVolume(EntityState entity, double volume) async {
    setState(() => _pendingVolume = volume);
    final result = await ref
        .read(mediaPlayerControlControllerProvider)
        .setVolume(entity, volume);
    if (!mounted) return;
    if (!result.isSuccess) {
      setState(() => _pendingVolume = null);
      _showError((result as MediaPlayerActionFailure).message);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entity = ref.watch(entityProvider(_card.entityId));
    final label = cardEntityLabel(_card.name, entity, _card.entityId);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: entity == null
            ? _MediaPlayerPlaceholder(theme: theme, label: label)
            : _MediaPlayerBody(
                entity: entity,
                label: label,
                pendingVolume: _pendingVolume,
                onPlayPause: () => _playPause(entity),
                onNextTrack: () => _nextTrack(entity),
                onPreviousTrack: () => _previousTrack(entity),
                onVolumeChanged: (volume) => _setVolume(entity, volume),
              ),
      ),
    );
  }
}

/// The live content of a media-player card: name, title/artist, playback
/// state, transport controls and (when supported) the volume slider. Split
/// out of the state's `build` purely for readability, mirroring
/// `_ClimateBody`.
class _MediaPlayerBody extends StatelessWidget {
  const _MediaPlayerBody({
    required this.entity,
    required this.label,
    required this.pendingVolume,
    required this.onPlayPause,
    required this.onNextTrack,
    required this.onPreviousTrack,
    required this.onVolumeChanged,
  });

  final EntityState entity;
  final String label;
  final double? pendingVolume;
  final VoidCallback onPlayPause;
  final VoidCallback onNextTrack;
  final VoidCallback onPreviousTrack;
  final ValueChanged<double> onVolumeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = MediaPlayerControl.mediaTitle(entity);
    final artist = MediaPlayerControl.mediaArtist(entity);
    final state = entity.state;
    final supportsVolume = MediaPlayerControl.supportsVolume(entity);
    final volume = pendingVolume ?? MediaPlayerControl.volumeLevel(entity);
    final isPlaying = state == 'playing';
    final controlsEnabled = state != 'off' && state != 'unavailable';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          title ?? 'No media playing',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (artist != null)
          Text(
            artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 4),
        Text(
          state,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Previous track',
              icon: const Icon(Icons.skip_previous),
              onPressed: controlsEnabled ? onPreviousTrack : null,
            ),
            IconButton(
              tooltip: isPlaying ? 'Pause' : 'Play',
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: controlsEnabled ? onPlayPause : null,
            ),
            IconButton(
              tooltip: 'Next track',
              icon: const Icon(Icons.skip_next),
              onPressed: controlsEnabled ? onNextTrack : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.volume_up_outlined,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(
                  context,
                ).copyWith(trackHeight: 2, padding: EdgeInsets.zero),
                child: Slider(
                  value: (volume ?? 0).clamp(0.0, 1.0),
                  min: 0,
                  max: 1,
                  label: volume == null ? '--' : '${(volume * 100).round()}%',
                  // Some media players (e.g. a basic Chromecast target, or a
                  // TV with no volume feedback) never report a
                  // `volume_level` attribute at all — disable rather than
                  // guess a value for them.
                  onChanged: supportsVolume && controlsEnabled
                      ? onVolumeChanged
                      : null,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Shown when the media player entity isn't in the live store yet (or has
/// gone missing) — a valid `media-control` config with no usable live value,
/// the same graceful-degradation spirit as `ClimateCardWidget`'s placeholder.
class _MediaPlayerPlaceholder extends StatelessWidget {
  const _MediaPlayerPlaceholder({required this.theme, required this.label});

  final ThemeData theme;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.smart_display_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              'unavailable',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
