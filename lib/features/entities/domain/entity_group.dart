import '../../connection/domain/entity_state.dart';

/// A domain (e.g. `light`, `sensor`, `switch`) and the entities that belong to
/// it, ready to be rendered as one section of the entities overview.
///
/// Plain immutable value type with no UI or transport dependency, so the
/// grouping/sorting rules in [groupEntitiesByDomain] can be unit-tested in
/// isolation from any widget.
class EntityGroup {
  const EntityGroup({required this.domain, required this.entities});

  /// The domain shared by every entity in [entities], e.g. `light`.
  final String domain;

  /// The entities in this domain, pre-sorted for display.
  final List<EntityState> entities;

  /// How many entities the group contains.
  int get count => entities.length;

  @override
  bool operator ==(Object other) =>
      other is EntityGroup &&
      other.domain == domain &&
      _listEquals(other.entities, entities);

  @override
  int get hashCode => Object.hash(domain, Object.hashAll(entities));

  @override
  String toString() => 'EntityGroup($domain: $count)';
}

/// Groups the live entity store into per-domain sections, deterministically
/// sorted so the overview stays stable and readable with many entities.
///
/// Sorting rules:
///
/// * Groups are ordered alphabetically by [EntityGroup.domain].
/// * Within a group, entities are ordered by their display label
///   ([_displayLabel] — friendly name when present, else the entity id),
///   case-insensitively, with the entity id as a tie-breaker so the order is
///   total and never flickers between rebuilds.
///
/// Kept as a pure function (no Riverpod, no widgets) so it is trivially
/// testable and reusable.
List<EntityGroup> groupEntitiesByDomain(Map<String, EntityState> states) {
  final byDomain = <String, List<EntityState>>{};
  for (final entity in states.values) {
    byDomain.putIfAbsent(entity.domain, () => <EntityState>[]).add(entity);
  }

  final domains = byDomain.keys.toList()..sort();

  return [
    for (final domain in domains)
      EntityGroup(
        domain: domain,
        entities: byDomain[domain]!..sort(_byDisplayLabel),
      ),
  ];
}

int _byDisplayLabel(EntityState a, EntityState b) {
  final byLabel = _displayLabel(
    a,
  ).toLowerCase().compareTo(_displayLabel(b).toLowerCase());
  if (byLabel != 0) return byLabel;
  // Tie-break on the entity id so equal labels still sort deterministically.
  return a.entityId.compareTo(b.entityId);
}

/// The label shown for an entity: its friendly name when HA provides a
/// non-empty one, otherwise the raw entity id.
String _displayLabel(EntityState entity) {
  final name = entity.friendlyName;
  if (name != null && name.trim().isNotEmpty) return name;
  return entity.entityId;
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
