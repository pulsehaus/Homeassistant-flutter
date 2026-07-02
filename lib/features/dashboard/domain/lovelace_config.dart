import 'lovelace_card.dart';

/// A parsed Lovelace dashboard config.
///
/// Plain immutable value type with no transport or UI dependency, produced by
/// [parseLovelaceConfig]. `DashboardPage` renders every view in [views],
/// switching between them via a tab selector when there is more than one;
/// [firstView] remains the sensible default for a single-view config.
class LovelaceConfig {
  const LovelaceConfig({this.title, this.views = const []});

  /// Optional dashboard title.
  final String? title;

  /// The dashboard's views (tabs). May be empty for an absent/blank config.
  final List<LovelaceView> views;

  /// The default (first) view, or null when the dashboard has no views.
  LovelaceView? get firstView => views.isEmpty ? null : views.first;

  @override
  bool operator ==(Object other) =>
      other is LovelaceConfig &&
      other.title == title &&
      _listEquals(other.views, views);

  @override
  int get hashCode => Object.hash(title, Object.hashAll(views));

  @override
  String toString() => 'LovelaceConfig(title: $title, views: ${views.length})';
}

/// One view (tab) of a [LovelaceConfig] and the cards it holds.
class LovelaceView {
  const LovelaceView({this.title, this.path, this.cards = const []});

  /// Optional view title (tab label).
  final String? title;

  /// Optional URL path segment HA assigns to the view.
  final String? path;

  /// The cards to render in this view, in config order.
  final List<LovelaceCard> cards;

  @override
  bool operator ==(Object other) =>
      other is LovelaceView &&
      other.title == title &&
      other.path == path &&
      _listEquals(other.cards, cards);

  @override
  int get hashCode => Object.hash(title, path, Object.hashAll(cards));

  @override
  String toString() => 'LovelaceView(title: $title, cards: ${cards.length})';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
