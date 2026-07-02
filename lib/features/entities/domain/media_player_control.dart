import '../../connection/domain/entity_state.dart';

/// Pure, transport-free logic for controlling a `media_player` entity (TV,
/// speaker, Chromecast, Sonos, …).
///
/// Mirrors [ClimateControl]'s shape: it answers the questions a widget would
/// otherwise bury in its build method, and builds the `domain`/`service`/
/// `service_data`/`target` shape ready for
/// `HaWebSocketClient.callService`, so the widget/controller never construct
/// a service-call map themselves.
///
/// Kept as a plain value/utility with no Riverpod or Flutter dependency so it
/// is trivially unit-testable in isolation.
class MediaPlayerControl {
  const MediaPlayerControl._();

  /// The entity's `media_title` attribute, or null when absent/non-string —
  /// e.g. a player that's `off` or `idle` and has nothing queued.
  static String? mediaTitle(EntityState entity) =>
      _asNonEmptyString(entity.attributes['media_title']);

  /// The entity's `media_artist` attribute, or null when absent/non-string.
  static String? mediaArtist(EntityState entity) =>
      _asNonEmptyString(entity.attributes['media_artist']);

  /// The entity's live volume (`volume_level` attribute), 0.0-1.0, or null
  /// when the player doesn't report one at all — some players (e.g. a basic
  /// Chromecast target, or a TV with no volume feedback) never expose this
  /// attribute, so the widget must be able to hide/disable the slider rather
  /// than assume a value.
  static double? volumeLevel(EntityState entity) {
    final value = entity.attributes['volume_level'];
    if (value is num) return value.toDouble();
    return null;
  }

  /// Whether [entity] reports a `volume_level` attribute at all, i.e.
  /// whether the volume slider should be shown/enabled.
  static bool supportsVolume(EntityState entity) => volumeLevel(entity) != null;

  /// The service call that toggles [entity]'s playback (`media_play_pause`).
  static MediaPlayerCommand playPauseCommand(EntityState entity) {
    return MediaPlayerCommand(
      domain: 'media_player',
      service: 'media_play_pause',
      serviceData: const {},
      target: {'entity_id': entity.entityId},
    );
  }

  /// The service call that skips [entity] to the next track
  /// (`media_next_track`).
  static MediaPlayerCommand nextTrackCommand(EntityState entity) {
    return MediaPlayerCommand(
      domain: 'media_player',
      service: 'media_next_track',
      serviceData: const {},
      target: {'entity_id': entity.entityId},
    );
  }

  /// The service call that skips [entity] to the previous track
  /// (`media_previous_track`).
  static MediaPlayerCommand previousTrackCommand(EntityState entity) {
    return MediaPlayerCommand(
      domain: 'media_player',
      service: 'media_previous_track',
      serviceData: const {},
      target: {'entity_id': entity.entityId},
    );
  }

  /// The service call that sets [entity]'s volume to [volumeLevel]
  /// (`volume_set`).
  ///
  /// [volumeLevel] is clamped to HA's 0.0-1.0 float range for this domain —
  /// **not** the 0-255 int range `light.turn_on`'s `brightness` uses.
  static MediaPlayerCommand volumeSetCommand(
    EntityState entity,
    double volumeLevel,
  ) {
    return MediaPlayerCommand(
      domain: 'media_player',
      service: 'volume_set',
      serviceData: {'volume_level': volumeLevel.clamp(0.0, 1.0)},
      target: {'entity_id': entity.entityId},
    );
  }

  static String? _asNonEmptyString(Object? value) {
    if (value is! String) return null;
    return value.trim().isEmpty ? null : value;
  }
}

/// An immutable description of the `call_service` to perform for a media
/// player control action.
///
/// Decouples *what* to call from *how* it is dispatched, so the mapping can
/// be asserted in a unit test without touching the WebSocket client.
class MediaPlayerCommand {
  const MediaPlayerCommand({
    required this.domain,
    required this.service,
    required this.serviceData,
    required this.target,
  });

  /// HA service domain — always `media_player` for this card.
  final String domain;

  /// `media_play_pause`, `media_next_track`, `media_previous_track` or
  /// `volume_set`.
  final String service;

  /// Service data, e.g. `{'volume_level': 0.5}`, or empty for the
  /// play/pause/track-skip commands.
  final Map<String, dynamic> serviceData;

  /// Service target, e.g. `{'entity_id': 'media_player.living_room'}`.
  final Map<String, dynamic> target;

  @override
  bool operator ==(Object other) =>
      other is MediaPlayerCommand &&
      other.domain == domain &&
      other.service == service &&
      _mapEquals(other.serviceData, serviceData) &&
      _mapEquals(other.target, target);

  @override
  int get hashCode => Object.hash(
    domain,
    service,
    Object.hashAll(serviceData.keys),
    Object.hashAll(target.keys),
  );

  @override
  String toString() =>
      'MediaPlayerCommand($domain.$service, data: $serviceData, '
      'target: $target)';

  static bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || b[key] != a[key]) return false;
    }
    return true;
  }
}
