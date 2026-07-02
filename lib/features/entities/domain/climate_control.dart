import '../../connection/domain/entity_state.dart';

/// Pure, transport-free logic for controlling a `climate` entity (thermostat,
/// AC unit, heat pump, …).
///
/// Mirrors [EntityToggle]'s shape: it answers the questions a widget would
/// otherwise bury in its build method, and builds the `domain`/`service`/
/// `service_data`/`target` shape ready for
/// `HaWebSocketClient.callService`, so the widget/controller never construct
/// a service-call map themselves.
///
/// Kept as a plain value/utility with no Riverpod or Flutter dependency so it
/// is trivially unit-testable in isolation.
class ClimateControl {
  const ClimateControl._();

  /// The default step (in the entity's own temperature unit) used by the
  /// +/- controls, matching Home Assistant's own thermostat card default.
  static const double defaultTemperatureStep = 0.5;

  /// The entity's live target temperature (`temperature` attribute), or null
  /// when absent/non-numeric — e.g. an `hvac_mode` of `off`, or a unit that
  /// doesn't expose a single target (`heat_cool` uses a range instead, out of
  /// scope for this card).
  static double? targetTemperature(EntityState entity) =>
      _asDouble(entity.attributes['temperature']);

  /// The entity's live current temperature (`current_temperature`
  /// attribute), or null when the entity doesn't report one.
  static double? currentTemperature(EntityState entity) =>
      _asDouble(entity.attributes['current_temperature']);

  /// The entity's configured step size (`target_temp_step` attribute), or
  /// [defaultTemperatureStep] when absent.
  static double temperatureStep(EntityState entity) =>
      _asDouble(entity.attributes['target_temp_step']) ??
      defaultTemperatureStep;

  /// The entity's current `hvac_mode` (the top-level `state`, per HA's
  /// climate entity model — unlike most domains, a climate entity's own
  /// `state` *is* its mode).
  static String hvacMode(EntityState entity) => entity.state;

  /// The modes this entity supports (`hvac_modes` attribute), or an empty
  /// list when absent so a widget can gate on `isEmpty` rather than crash.
  static List<String> hvacModes(EntityState entity) {
    final raw = entity.attributes['hvac_modes'];
    if (raw is! List) return const [];
    return [
      for (final mode in raw)
        if (mode is String) mode,
    ];
  }

  /// The service call that sets [entity]'s target temperature to
  /// [temperature].
  ///
  /// Returns the `domain` (`climate`), `service` (`set_temperature`) and the
  /// `serviceData`/`target` maps ready for
  /// `callService(domain, service, data: serviceData, target: target)`.
  static ClimateCommand setTemperatureCommand(
    EntityState entity, {
    required double temperature,
  }) {
    return ClimateCommand(
      domain: 'climate',
      service: 'set_temperature',
      serviceData: {'temperature': temperature},
      target: {'entity_id': entity.entityId},
    );
  }

  /// The service call that sets [entity]'s `hvac_mode` to [mode].
  static ClimateCommand setHvacModeCommand(EntityState entity, String mode) {
    return ClimateCommand(
      domain: 'climate',
      service: 'set_hvac_mode',
      serviceData: {'hvac_mode': mode},
      target: {'entity_id': entity.entityId},
    );
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

/// An immutable description of the `call_service` to perform for a climate
/// control action.
///
/// Decouples *what* to call from *how* it is dispatched, so the mapping can
/// be asserted in a unit test without touching the WebSocket client.
class ClimateCommand {
  const ClimateCommand({
    required this.domain,
    required this.service,
    required this.serviceData,
    required this.target,
  });

  /// HA service domain — always `climate` for this card.
  final String domain;

  /// `set_temperature` or `set_hvac_mode`.
  final String service;

  /// Service data, e.g. `{'temperature': 21.5}` or `{'hvac_mode': 'heat'}`.
  final Map<String, dynamic> serviceData;

  /// Service target, e.g. `{'entity_id': 'climate.living_room'}`.
  final Map<String, dynamic> target;

  @override
  bool operator ==(Object other) =>
      other is ClimateCommand &&
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
      'ClimateCommand($domain.$service, data: $serviceData, target: $target)';

  static bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || b[key] != a[key]) return false;
    }
    return true;
  }
}
