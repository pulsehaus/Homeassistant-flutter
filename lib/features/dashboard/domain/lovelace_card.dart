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

/// The three numeric thresholds of a `gauge` card's `severity` map, on the
/// entity's own scale (not normalised to 0..1).
///
/// HA colours the gauge by walking the thresholds top-down: at or above [red]
/// is red, at or above [yellow] (and below [red]) is yellow, otherwise green.
/// See `GaugeCardWidget` for the comparison logic.
class GaugeSeverity {
  const GaugeSeverity({this.green, this.yellow, this.red});

  final double? green;
  final double? yellow;
  final double? red;

  @override
  bool operator ==(Object other) =>
      other is GaugeSeverity &&
      other.green == green &&
      other.yellow == yellow &&
      other.red == red;

  @override
  int get hashCode => Object.hash(green, yellow, red);

  @override
  String toString() =>
      'GaugeSeverity(green: $green, yellow: $yellow, red: $red)';
}

/// A gauge card (`type: gauge`): a single numeric entity rendered as a
/// min/max-clamped gauge, optionally coloured by [severity] thresholds.
class GaugeCard extends LovelaceCard {
  const GaugeCard({
    required this.entityId,
    this.name,
    this.unit,
    this.min = 0,
    this.max = 100,
    this.severity,
  });

  /// The entity this gauge displays, e.g. `sensor.living_room_humidity`.
  final String entityId;

  /// An explicit display name from the config, or null to fall back to the
  /// entity's friendly name / id at render time.
  final String? name;

  /// An explicit unit override from the config, or null to fall back to the
  /// entity's `unit_of_measurement` attribute.
  final String? unit;

  /// The gauge's lower bound. Defaults to 0, matching HA.
  final double min;

  /// The gauge's upper bound. Defaults to 100, matching HA.
  final double max;

  /// Optional colour thresholds; null when the config has no `severity` map.
  final GaugeSeverity? severity;

  @override
  bool operator ==(Object other) =>
      other is GaugeCard &&
      other.entityId == entityId &&
      other.name == name &&
      other.unit == unit &&
      other.min == min &&
      other.max == max &&
      other.severity == severity;

  @override
  int get hashCode => Object.hash(entityId, name, unit, min, max, severity);

  @override
  String toString() =>
      'GaugeCard($entityId, name: $name, unit: $unit, min: $min, max: $max, '
      'severity: $severity)';
}

/// A glance card (`type: glance`): an optional title and a compact grid of
/// entity tiles (icon + name + state), each individually toggleable via the
/// `show_*` options.
class GlanceCard extends LovelaceCard {
  const GlanceCard({
    this.title,
    this.rows = const [],
    this.showName = true,
    this.showIcon = true,
    this.showState = true,
    this.columns,
  });

  /// Optional card heading.
  final String? title;

  /// The tiles to render, normalised the same way as [EntitiesCard]'s rows
  /// regardless of the shape HA used in the config (a bare entity-id string
  /// or an object).
  final List<EntitiesRow> rows;

  /// Whether each tile shows its entity's name. Defaults to `true`.
  final bool showName;

  /// Whether each tile shows its entity's icon. Defaults to `true`.
  final bool showIcon;

  /// Whether each tile shows its entity's state. Defaults to `true`.
  final bool showState;

  /// Explicit grid column count from HA's `columns`, or null to let the
  /// widget pick a sensible default.
  final int? columns;

  @override
  bool operator ==(Object other) =>
      other is GlanceCard &&
      other.title == title &&
      other.showName == showName &&
      other.showIcon == showIcon &&
      other.showState == showState &&
      other.columns == columns &&
      _listEquals(other.rows, rows);

  @override
  int get hashCode => Object.hash(
    title,
    showName,
    showIcon,
    showState,
    columns,
    Object.hashAll(rows),
  );

  @override
  String toString() =>
      'GlanceCard(title: $title, rows: ${rows.length}, '
      'showName: $showName, showIcon: $showIcon, showState: $showState, '
      'columns: $columns)';
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
