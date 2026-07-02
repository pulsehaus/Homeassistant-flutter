import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../connection/application/connection_providers.dart';
import '../../connection/data/ha_websocket_client.dart';
import '../../connection/domain/entity_state.dart';
import '../../connection/domain/ha_exception.dart';
import '../domain/climate_control.dart';

/// The outcome of a requested climate action, so the UI can react without
/// catching exceptions itself. Mirrors `ToggleResult`.
///
/// On [ClimateActionResult.success] the displayed value will reconcile from
/// the resulting `state_changed` event; on [ClimateActionResult.failure] the
/// widget keeps the entity's real state and surfaces [message] (e.g. a
/// SnackBar).
sealed class ClimateActionResult {
  const ClimateActionResult();

  const factory ClimateActionResult.success() = ClimateActionSuccess;
  const factory ClimateActionResult.failure(String message) =
      ClimateActionFailure;

  /// Whether the service call succeeded.
  bool get isSuccess => this is ClimateActionSuccess;
}

/// The service call was accepted by Home Assistant.
class ClimateActionSuccess extends ClimateActionResult {
  const ClimateActionSuccess();
}

/// The service call failed; [message] is a human-readable reason to surface.
class ClimateActionFailure extends ClimateActionResult {
  const ClimateActionFailure(this.message);

  final String message;
}

/// Drives climate control (target temperature + `hvac_mode`) by issuing a
/// `call_service` through the connection layer's [HaWebSocketClient].
///
/// SOLID note: mirrors `EntityToggleController` — the widget never touches
/// the client or the service-call mapping. It hands an [EntityState] and the
/// desired temperature/mode to [setTemperature]/[setHvacMode]; this
/// controller resolves the command via the pure [ClimateControl] logic,
/// dispatches it, and translates any failure into a [ClimateActionResult] the
/// UI can display. The actual value shown by the UI keeps coming from the
/// live entity store, so a failed call never leaves the UI in a wrong state.
class ClimateControlController {
  ClimateControlController(this._client);

  final HaWebSocketClient _client;

  /// Request that [entity]'s target temperature be set to [temperature].
  ///
  /// Never throws: transport/command failures are caught and returned as a
  /// [ClimateActionFailure] with a clear message.
  Future<ClimateActionResult> setTemperature(
    EntityState entity, {
    required double temperature,
  }) {
    final command = ClimateControl.setTemperatureCommand(
      entity,
      temperature: temperature,
    );
    return _dispatch(
      entity,
      command,
      describeFailure: (reason) =>
          'Could not set temperature for ${_label(entity)}: $reason',
    );
  }

  /// Request that [entity]'s `hvac_mode` be set to [mode].
  ///
  /// Never throws: transport/command failures are caught and returned as a
  /// [ClimateActionFailure] with a clear message.
  Future<ClimateActionResult> setHvacMode(EntityState entity, String mode) {
    final command = ClimateControl.setHvacModeCommand(entity, mode);
    return _dispatch(
      entity,
      command,
      describeFailure: (reason) =>
          'Could not set mode for ${_label(entity)}: $reason',
    );
  }

  Future<ClimateActionResult> _dispatch(
    EntityState entity,
    ClimateCommand command, {
    required String Function(String reason) describeFailure,
  }) async {
    try {
      await _client.callService(
        command.domain,
        command.service,
        data: command.serviceData,
        target: command.target,
      );
      return const ClimateActionResult.success();
    } on HaException catch (error) {
      return ClimateActionResult.failure(describeFailure(error.message));
    } catch (error) {
      return ClimateActionResult.failure(describeFailure('$error'));
    }
  }

  String _label(EntityState entity) => entity.friendlyName ?? entity.entityId;
}

/// Exposes a singleton [ClimateControlController] wired to the live
/// WebSocket client. Overridable in tests with a fake client.
final climateControlControllerProvider = Provider<ClimateControlController>((
  ref,
) {
  return ClimateControlController(ref.watch(haWebSocketClientProvider));
}, dependencies: [haWebSocketClientProvider]);
