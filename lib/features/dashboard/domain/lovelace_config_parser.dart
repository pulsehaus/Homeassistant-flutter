import 'lovelace_card.dart';
import 'lovelace_config.dart';

/// Parses a raw `lovelace/config` payload into the typed [LovelaceConfig] model.
///
/// Hand-written, defensive parsing in the same style as `EntityState.fromJson`:
/// anything malformed is skipped rather than throwing, so a single bad view or
/// card never breaks the whole dashboard.
LovelaceConfig parseLovelaceConfig(Map<String, dynamic> json) {
  final rawViews = json['views'];
  final views = <LovelaceView>[];
  if (rawViews is List) {
    for (final view in rawViews) {
      if (view is Map) {
        views.add(_parseView(view.cast<String, dynamic>()));
      }
    }
  }
  return LovelaceConfig(title: json['title'] as String?, views: views);
}

LovelaceView _parseView(Map<String, dynamic> json) {
  final rawCards = json['cards'];
  final cards = <LovelaceCard>[];
  if (rawCards is List) {
    for (final card in rawCards) {
      if (card is Map) {
        cards.add(cardFromJson(card.cast<String, dynamic>()));
      }
    }
  }
  return LovelaceView(
    title: json['title'] as String?,
    path: json['path'] as String?,
    cards: cards,
  );
}

/// Turns one raw card config into a typed [LovelaceCard] — **the extension
/// point** for the whole card system.
///
/// To support a new card type:
/// 1. add a new [LovelaceCard] subclass in `lovelace_card.dart`;
/// 2. add a `case` for its `type` here;
/// 3. add a new `*_card_widget.dart`;
/// 4. add one arm to the dashboard page's render dispatcher.
/// The analyzer flags the dispatcher's `switch` until step 4 is done, so adding
/// a card type can't silently skip the UI.
///
/// Unknown types — and known types whose body is malformed — fall back to
/// [UnsupportedCard] (never throw), so the dashboard degrades gracefully.
LovelaceCard cardFromJson(Map<String, dynamic> json) {
  final type = json['type'];
  if (type is! String) return const UnsupportedCard(type: 'unknown');
  try {
    switch (type) {
      case 'entity':
        final id = json['entity'];
        if (id is! String) return UnsupportedCard(type: type);
        return EntityCard(entityId: id, name: json['name'] as String?);
      case 'entities':
        return EntitiesCard(
          title: json['title'] as String?,
          rows: _parseRows(json['entities']),
        );
      case 'history-graph':
        final entities = _parseEntityIds(json['entities']);
        if (entities.isEmpty) return UnsupportedCard(type: type);
        return HistoryGraphCard(
          entities: entities,
          title: json['title'] as String?,
          hoursToShow: (json['hours_to_show'] as num?)?.toInt() ?? 24,
        );
      case 'glance':
        final rows = _parseRows(json['entities']);
        if (rows.isEmpty) return UnsupportedCard(type: type);
        return GlanceCard(
          title: json['title'] as String?,
          rows: rows,
          showName: json['show_name'] as bool? ?? true,
          showIcon: json['show_icon'] as bool? ?? true,
          showState: json['show_state'] as bool? ?? true,
          columns: (json['columns'] as num?)?.toInt(),
        );
      default:
        return UnsupportedCard(type: type);
    }
  } catch (_) {
    // A known type with a garbage body degrades to a placeholder rather than
    // crashing the page.
    return UnsupportedCard(type: type);
  }
}

/// Normalises the two row shapes HA allows for an `entities` list — a bare
/// `"light.kitchen"` string or a `{entity, name?}` object — into [EntitiesRow],
/// so the widget layer never branches on the source shape. Non-conforming
/// entries are skipped. Shared by the `entities` and `glance` cards, which use
/// the same dual shape.
List<EntitiesRow> _parseRows(Object? raw) {
  if (raw is! List) return const [];
  final rows = <EntitiesRow>[];
  for (final entry in raw) {
    if (entry is String) {
      rows.add(EntitiesRow(entityId: entry));
    } else if (entry is Map) {
      final id = entry['entity'];
      if (id is String) {
        rows.add(EntitiesRow(entityId: id, name: entry['name'] as String?));
      }
    }
  }
  return rows;
}

/// Parses a `history-graph` card's `entities` field — HA documents this as a
/// plain list of entity-id strings (no string-or-object dual shape like the
/// `entities` card). Non-string entries are skipped rather than failing the
/// whole card.
List<String> _parseEntityIds(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final entry in raw)
      if (entry is String) entry,
  ];
}
