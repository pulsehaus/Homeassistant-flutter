/// The card model for a Lovelace dashboard.
///
/// A [LovelaceCard] is a normalised, transport-free value type: the parser
/// ([cardFromJson]) turns raw HA config JSON into one of these subclasses *once*,
/// so widgets never re-parse JSON and the render dispatcher matches on concrete
/// runtime types instead.
///
/// The class is **sealed** on purpose: an exhaustive `switch` over a
/// [LovelaceCard] (see the dashboard page's render dispatcher) is checked by the
/// analyzer, so adding a new subclass forces every dispatcher to grow a matching
/// arm. That is what makes "add a card type without reworking existing code"
/// real and compiler-enforced — the open/closed contract is the type system's
/// job, not a convention.
///
/// To add a card type:
/// 1. add a new subclass here;
/// 2. add a `case` for its `type` in [cardFromJson];
/// 3. add a new `*_card_widget.dart`;
/// 4. add one arm to the dashboard page's render dispatcher.
/// The analyzer flags the dispatcher until step 4 is done.
sealed class LovelaceCard {
  const LovelaceCard();
}

/// A single-entity card (`type: entity`): shows one entity's name and state.
class EntityCard extends LovelaceCard {
  const EntityCard({required this.entityId, this.name});

  /// The entity this card displays, e.g. `light.kitchen`.
  final String entityId;

  /// An explicit display name from the config, or null to fall back to the
  /// entity's friendly name / id at render time.
  final String? name;

  @override
  bool operator ==(Object other) =>
      other is EntityCard && other.entityId == entityId && other.name == name;

  @override
  int get hashCode => Object.hash(entityId, name);

  @override
  String toString() => 'EntityCard($entityId, name: $name)';
}

/// An entities card (`type: entities`): an optional title and a list of rows.
class EntitiesCard extends LovelaceCard {
  const EntitiesCard({this.title, this.rows = const []});

  /// Optional card heading.
  final String? title;

  /// The rows to render, already normalised to [EntitiesRow] regardless of the
  /// shape HA used in the config (a bare entity-id string or an object).
  final List<EntitiesRow> rows;

  @override
  bool operator ==(Object other) =>
      other is EntitiesCard &&
      other.title == title &&
      _listEquals(other.rows, rows);

  @override
  int get hashCode => Object.hash(title, Object.hashAll(rows));

  @override
  String toString() => 'EntitiesCard(title: $title, rows: ${rows.length})';
}

/// One row of an [EntitiesCard]. HA allows two shapes in config — a bare
/// `"light.kitchen"` string or a `{entity, name?}` object — and the parser
/// normalises both into this single type so widgets never branch on the source
/// shape.
class EntitiesRow {
  const EntitiesRow({required this.entityId, this.name});

  /// The entity this row displays, e.g. `light.kitchen`.
  final String entityId;

  /// An explicit per-row name from the config, or null to fall back to the
  /// entity's friendly name / id at render time.
  final String? name;

  @override
  bool operator ==(Object other) =>
      other is EntitiesRow && other.entityId == entityId && other.name == name;

  @override
  int get hashCode => Object.hash(entityId, name);

  @override
  String toString() => 'EntitiesRow($entityId, name: $name)';
}

/// A history-graph card (`type: history-graph`): a title and one or more
/// entities, each rendered as a trailing-history chart (reusing the charts
/// feature's `TimeSeriesChart` — see `HistoryGraphCardWidget`).
class HistoryGraphCard extends LovelaceCard {
  const HistoryGraphCard({
    required this.entities,
    this.title,
    this.hoursToShow = 24,
  });

  /// Entity ids to chart, e.g. `sensor.temperature`. HA's schema for this
  /// card is a plain list of entity-id strings (unlike the `entities` card's
  /// string-or-object dual shape), so no per-row normalisation is needed.
  final List<String> entities;

  /// Optional card heading.
  final String? title;

  /// The trailing window (in hours) to chart, from HA's `hours_to_show`.
  /// Defaults to 24 when absent, matching `EntityHistoryRequest`'s default
  /// period.
  final int hoursToShow;

  @override
  bool operator ==(Object other) =>
      other is HistoryGraphCard &&
      other.title == title &&
      other.hoursToShow == hoursToShow &&
      _listEquals(other.entities, entities);

  @override
  int get hashCode => Object.hash(title, hoursToShow, Object.hashAll(entities));

  @override
  String toString() =>
      'HistoryGraphCard(title: $title, hoursToShow: $hoursToShow, '
      'entities: $entities)';
}

/// The graceful-degradation card: produced for any card whose `type` is unknown,
/// missing, or whose (known) body is malformed. Rendering it shows a muted
/// placeholder instead of crashing, so an unsupported card never breaks the page.
class UnsupportedCard extends LovelaceCard {
  const UnsupportedCard({required this.type});

  /// The original `type` from the config (or `'unknown'` when absent), shown in
  /// the placeholder so the gap is diagnosable.
  final String type;

  @override
  bool operator ==(Object other) =>
      other is UnsupportedCard && other.type == type;

  @override
  int get hashCode => type.hashCode;

  @override
  String toString() => 'UnsupportedCard($type)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
