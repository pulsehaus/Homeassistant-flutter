import 'package:shared_preferences/shared_preferences.dart';

import '../domain/history_range.dart';

/// Persistence boundary for the history screen's user selections: the
/// charted entity (#20) and the trailing [HistoryRange] (#21).
///
/// This is the seam that keeps `shared_preferences` (and its platform quirks)
/// out of the rest of the app: the controllers depend on this interface, not
/// on the plugin, so the store can be mocked in tests and swapped if the
/// backing storage ever changes. Mirrors the `ThemeModeStore` seam in
/// `lib/core/theme/theme_mode_store.dart` — both are plain, non-sensitive
/// local preference data, so both use `shared_preferences` rather than the
/// encrypted secure storage used for connection credentials.
abstract interface class ChartSelectionStore {
  /// Read the stored entity id, or `null` if the user has never picked one
  /// (the screen should then fall back to the first numeric sensor).
  Future<String?> readEntityId();

  /// Persist [entityId], replacing anything already stored. Pass `null` to
  /// clear the stored selection.
  Future<void> writeEntityId(String? entityId);

  /// Read the stored [HistoryRange], or `null` if the user has never changed
  /// it (the screen should then default to [HistoryRange.hours24]).
  Future<HistoryRange?> readRange();

  /// Persist [range], replacing anything already stored.
  Future<void> writeRange(HistoryRange range);
}

/// [ChartSelectionStore] backed by `shared_preferences`.
///
/// The entity id is stored as a plain string and the range as its
/// [HistoryRange.name] string, each under its own key.
class SharedPreferencesChartSelectionStore implements ChartSelectionStore {
  SharedPreferencesChartSelectionStore({
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferences;

  static const _entityIdKey = 'chart_selected_entity_id';
  static const _rangeKey = 'chart_selected_range';

  @override
  Future<String?> readEntityId() async {
    final prefs = await _preferences();
    return prefs.getString(_entityIdKey);
  }

  @override
  Future<void> writeEntityId(String? entityId) async {
    final prefs = await _preferences();
    if (entityId == null) {
      await prefs.remove(_entityIdKey);
    } else {
      await prefs.setString(_entityIdKey, entityId);
    }
  }

  @override
  Future<HistoryRange?> readRange() async {
    final prefs = await _preferences();
    final stored = prefs.getString(_rangeKey);
    if (stored == null) return null;
    return HistoryRange.values.asNameMap()[stored];
  }

  @override
  Future<void> writeRange(HistoryRange range) async {
    final prefs = await _preferences();
    await prefs.setString(_rangeKey, range.name);
  }
}
