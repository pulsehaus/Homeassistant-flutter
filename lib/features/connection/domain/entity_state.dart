/// A single Home Assistant entity and its current state.
///
/// Mirrors the JSON returned by `get_states` / the REST `/api/states` endpoint
/// and carried by `state_changed` events. Kept as a plain immutable value
/// object with no transport or UI dependency.
class EntityState {
  const EntityState({
    required this.entityId,
    required this.state,
    this.attributes = const {},
    this.lastChanged,
    this.lastUpdated,
  });

  /// e.g. `light.kitchen`, `sensor.outside_temperature`.
  final String entityId;

  /// The state value as HA reports it, e.g. `on`, `off`, `23.4`, `unavailable`.
  final String state;

  /// Arbitrary attributes (`friendly_name`, `brightness`, `unit_of_measurement`…).
  final Map<String, Object?> attributes;

  final DateTime? lastChanged;
  final DateTime? lastUpdated;

  /// `domain` part of [entityId], e.g. `light` for `light.kitchen`.
  String get domain {
    final dot = entityId.indexOf('.');
    return dot == -1 ? entityId : entityId.substring(0, dot);
  }

  /// Human-readable name when HA provides one, otherwise null.
  String? get friendlyName => attributes['friendly_name'] as String?;

  factory EntityState.fromJson(Map<String, dynamic> json) {
    final rawAttributes = json['attributes'];
    return EntityState(
      entityId: json['entity_id'] as String,
      state: json['state'] as String? ?? 'unknown',
      attributes: rawAttributes is Map
          ? rawAttributes.cast<String, Object?>()
          : const {},
      lastChanged: _parseTimestamp(json['last_changed']),
      lastUpdated: _parseTimestamp(json['last_updated']),
    );
  }

  static DateTime? _parseTimestamp(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }

  // Equality is intentionally based on the cheap, change-tracking fields rather
  // than a deep map comparison: HA bumps `last_updated` on every change
  // (including attributes), so it is a reliable, inexpensive proxy. This keeps
  // Riverpod selectors from rebuilding when an unrelated entity changes.
  @override
  bool operator ==(Object other) =>
      other is EntityState &&
      other.entityId == entityId &&
      other.state == state &&
      other.lastUpdated == lastUpdated;

  @override
  int get hashCode => Object.hash(entityId, state, lastUpdated);

  @override
  String toString() => 'EntityState($entityId: $state)';
}
