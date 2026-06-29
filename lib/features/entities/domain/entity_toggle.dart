import '../../connection/domain/entity_state.dart';

/// Pure, transport-free logic for toggling a controllable entity.
///
/// It answers three questions a widget would otherwise bury in its build
/// method:
///
/// * **Is this entity toggleable?** ([isToggleable]) — only domains that expose
///   `turn_on`/`turn_off` (currently `light` and `switch`).
/// * **Is it currently on?** ([isOn]) — the displayed switch position.
/// * **Which service call flips it?** ([toggleCommand]) — the `domain`,
///   `service` and `target` to hand to `HaWebSocketClient.callService`.
///
/// Kept as a plain value/utility with no Riverpod or Flutter dependency so it is
/// trivially unit-testable in isolation (see `entity_toggle_test.dart`).
class EntityToggle {
  const EntityToggle._();

  /// Domains this app can toggle. Both expose the standard
  /// `turn_on` / `turn_off` services with an `entity_id` target.
  static const Set<String> toggleableDomains = {'light', 'switch'};

  /// Whether [entity] belongs to a domain we can toggle from the UI.
  static bool isToggleable(EntityState entity) =>
      toggleableDomains.contains(entity.domain);

  /// Whether [entity] is currently *on*.
  ///
  /// Home Assistant reports the canonical `on` for an active light/switch.
  /// Anything else (`off`, `unavailable`, `unknown`, …) is treated as not-on so
  /// a flaky state never renders the switch as enabled.
  static bool isOn(EntityState entity) => entity.state == 'on';

  /// The service call that flips [entity] to [on].
  ///
  /// Returns the `domain`, `service` (`turn_on` / `turn_off`) and the
  /// `target` map ready for `callService(domain, service, target: target)`.
  /// Throws [ArgumentError] if [entity] isn't toggleable, so callers gate on
  /// [isToggleable] first.
  static ToggleCommand toggleCommand(EntityState entity, {required bool on}) {
    if (!isToggleable(entity)) {
      throw ArgumentError.value(
        entity.entityId,
        'entity',
        'Entity domain "${entity.domain}" is not toggleable',
      );
    }
    return ToggleCommand(
      domain: entity.domain,
      service: on ? 'turn_on' : 'turn_off',
      target: {'entity_id': entity.entityId},
    );
  }
}

/// An immutable description of the `call_service` to perform for a toggle.
///
/// Decouples *what* to call from *how* it is dispatched, so the mapping can be
/// asserted in a unit test without touching the WebSocket client.
class ToggleCommand {
  const ToggleCommand({
    required this.domain,
    required this.service,
    required this.target,
  });

  /// HA service domain, e.g. `light` or `switch`.
  final String domain;

  /// `turn_on` or `turn_off`.
  final String service;

  /// Service target, e.g. `{'entity_id': 'light.kitchen'}`.
  final Map<String, dynamic> target;

  @override
  bool operator ==(Object other) =>
      other is ToggleCommand &&
      other.domain == domain &&
      other.service == service &&
      _mapEquals(other.target, target);

  @override
  int get hashCode => Object.hash(domain, service, Object.hashAll(target.keys));

  @override
  String toString() => 'ToggleCommand($domain.$service, target: $target)';

  static bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || b[key] != a[key]) return false;
    }
    return true;
  }
}
