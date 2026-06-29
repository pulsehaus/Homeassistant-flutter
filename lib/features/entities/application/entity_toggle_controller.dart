import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../connection/application/connection_providers.dart';
import '../../connection/data/ha_websocket_client.dart';
import '../../connection/domain/entity_state.dart';
import '../../connection/domain/ha_exception.dart';
import '../domain/entity_toggle.dart';

/// The outcome of a requested toggle, so the UI can react without catching
/// exceptions itself.
///
/// On [ToggleResult.success] the displayed state will reconcile from the
/// resulting `state_changed` event; on [ToggleResult.failure] the widget keeps
/// the entity's real state and surfaces [message] (e.g. a SnackBar).
sealed class ToggleResult {
  const ToggleResult();

  const factory ToggleResult.success() = ToggleSuccess;
  const factory ToggleResult.failure(String message) = ToggleFailure;

  /// Whether the service call succeeded.
  bool get isSuccess => this is ToggleSuccess;
}

/// The service call was accepted by Home Assistant.
class ToggleSuccess extends ToggleResult {
  const ToggleSuccess();
}

/// The service call failed; [message] is a human-readable reason to surface.
class ToggleFailure extends ToggleResult {
  const ToggleFailure(this.message);

  final String message;
}

/// Drives toggling a controllable entity (`light`, `switch`) by issuing a
/// `call_service` through the connection layer's [HaWebSocketClient].
///
/// SOLID note: the widget never touches the client or the service mapping. It
/// hands an [EntityState] and the desired position to [toggle]; this controller
/// resolves the command via the pure [EntityToggle] logic, dispatches it, and
/// translates any failure into a [ToggleResult] the UI can display. The actual
/// on/off shown by the UI keeps coming from the live entity store, so a failed
/// call never leaves the UI in a wrong state.
class EntityToggleController {
  EntityToggleController(this._client);

  final HaWebSocketClient _client;

  /// Request that [entity] be turned [on] (or off when false).
  ///
  /// Never throws: transport/command failures are caught and returned as a
  /// [ToggleFailure] with a clear message. A successful call resolves to
  /// [ToggleSuccess]; the new state then arrives via the live `state_changed`
  /// stream, so callers don't have to mutate state themselves.
  Future<ToggleResult> toggle(EntityState entity, {required bool on}) async {
    final ToggleCommand command;
    try {
      command = EntityToggle.toggleCommand(entity, on: on);
    } on ArgumentError catch (error) {
      return ToggleResult.failure(
        error.message?.toString() ?? 'Entity cannot be toggled',
      );
    }

    try {
      await _client.callService(
        command.domain,
        command.service,
        target: command.target,
      );
      return const ToggleResult.success();
    } on HaException catch (error) {
      return ToggleResult.failure(
        _describe(entity, on: on, reason: error.message),
      );
    } catch (error) {
      return ToggleResult.failure(_describe(entity, on: on, reason: '$error'));
    }
  }

  String _describe(
    EntityState entity, {
    required bool on,
    required String reason,
  }) {
    final label = entity.friendlyName ?? entity.entityId;
    final verb = on ? 'turn on' : 'turn off';
    return 'Could not $verb $label: $reason';
  }
}

/// Exposes a singleton [EntityToggleController] wired to the live WebSocket
/// client. Overridable in tests with a fake client.
final entityToggleControllerProvider = Provider<EntityToggleController>((ref) {
  return EntityToggleController(ref.watch(haWebSocketClientProvider));
});
