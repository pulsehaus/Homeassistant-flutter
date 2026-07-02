import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../connection/application/connection_providers.dart';
import '../../connection/data/ha_websocket_client.dart';
import '../../connection/domain/entity_state.dart';
import '../../connection/domain/ha_exception.dart';
import '../domain/media_player_control.dart';

/// The outcome of a requested media player action, so the UI can react
/// without catching exceptions itself. Mirrors `ClimateActionResult`.
///
/// On [MediaPlayerActionResult.success] the displayed value will reconcile
/// from the resulting `state_changed` event; on
/// [MediaPlayerActionResult.failure] the widget keeps the entity's real state
/// and surfaces [message] (e.g. a SnackBar).
sealed class MediaPlayerActionResult {
  const MediaPlayerActionResult();

  const factory MediaPlayerActionResult.success() = MediaPlayerActionSuccess;
  const factory MediaPlayerActionResult.failure(String message) =
      MediaPlayerActionFailure;

  /// Whether the service call succeeded.
  bool get isSuccess => this is MediaPlayerActionSuccess;
}

/// The service call was accepted by Home Assistant.
class MediaPlayerActionSuccess extends MediaPlayerActionResult {
  const MediaPlayerActionSuccess();
}

/// The service call failed; [message] is a human-readable reason to surface.
class MediaPlayerActionFailure extends MediaPlayerActionResult {
  const MediaPlayerActionFailure(this.message);

  final String message;
}

/// Drives media player control (play/pause, track skip, volume) by issuing a
/// `call_service` through the connection layer's [HaWebSocketClient].
///
/// SOLID note: mirrors `ClimateControlController` — the widget never touches
/// the client or the service-call mapping. It hands an [EntityState] to
/// [playPause]/[nextTrack]/[previousTrack]/[setVolume]; this controller
/// resolves the command via the pure [MediaPlayerControl] logic, dispatches
/// it, and translates any failure into a [MediaPlayerActionResult] the UI can
/// display. The actual value shown by the UI keeps coming from the live
/// entity store, so a failed call never leaves the UI in a wrong state.
class MediaPlayerControlController {
  MediaPlayerControlController(this._client);

  final HaWebSocketClient _client;

  /// Request that [entity] toggle play/pause.
  ///
  /// Never throws: transport/command failures are caught and returned as a
  /// [MediaPlayerActionFailure] with a clear message.
  Future<MediaPlayerActionResult> playPause(EntityState entity) {
    final command = MediaPlayerControl.playPauseCommand(entity);
    return _dispatch(
      entity,
      command,
      describeFailure: (reason) =>
          'Could not toggle playback for ${_label(entity)}: $reason',
    );
  }

  /// Request that [entity] skip to the next track.
  ///
  /// Never throws: transport/command failures are caught and returned as a
  /// [MediaPlayerActionFailure] with a clear message.
  Future<MediaPlayerActionResult> nextTrack(EntityState entity) {
    final command = MediaPlayerControl.nextTrackCommand(entity);
    return _dispatch(
      entity,
      command,
      describeFailure: (reason) =>
          'Could not skip to the next track for ${_label(entity)}: $reason',
    );
  }

  /// Request that [entity] skip to the previous track.
  ///
  /// Never throws: transport/command failures are caught and returned as a
  /// [MediaPlayerActionFailure] with a clear message.
  Future<MediaPlayerActionResult> previousTrack(EntityState entity) {
    final command = MediaPlayerControl.previousTrackCommand(entity);
    return _dispatch(
      entity,
      command,
      describeFailure: (reason) =>
          'Could not skip to the previous track for ${_label(entity)}: '
          '$reason',
    );
  }

  /// Request that [entity]'s volume be set to [volumeLevel] (0.0-1.0).
  ///
  /// Never throws: transport/command failures are caught and returned as a
  /// [MediaPlayerActionFailure] with a clear message.
  Future<MediaPlayerActionResult> setVolume(
    EntityState entity,
    double volumeLevel,
  ) {
    final command = MediaPlayerControl.volumeSetCommand(entity, volumeLevel);
    return _dispatch(
      entity,
      command,
      describeFailure: (reason) =>
          'Could not set volume for ${_label(entity)}: $reason',
    );
  }

  Future<MediaPlayerActionResult> _dispatch(
    EntityState entity,
    MediaPlayerCommand command, {
    required String Function(String reason) describeFailure,
  }) async {
    try {
      await _client.callService(
        command.domain,
        command.service,
        data: command.serviceData,
        target: command.target,
      );
      return const MediaPlayerActionResult.success();
    } on HaException catch (error) {
      return MediaPlayerActionResult.failure(describeFailure(error.message));
    } catch (error) {
      return MediaPlayerActionResult.failure(describeFailure('$error'));
    }
  }

  String _label(EntityState entity) => entity.friendlyName ?? entity.entityId;
}

/// Exposes a singleton [MediaPlayerControlController] wired to the live
/// WebSocket client. Overridable in tests with a fake client.
final mediaPlayerControlControllerProvider =
    Provider<MediaPlayerControlController>((ref) {
      return MediaPlayerControlController(ref.watch(haWebSocketClientProvider));
    }, dependencies: [haWebSocketClientProvider]);
