import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistence boundary for the user's manually chosen [ThemeMode].
///
/// This is the seam that keeps `shared_preferences` (and its platform quirks)
/// out of the rest of the app: the controller depends on this interface, not
/// on the plugin, so the store can be mocked in tests and swapped if the
/// backing storage ever changes. Mirrors the `CredentialStore` seam in
/// `lib/features/connection/data/credential_store.dart` — the theme mode is
/// plain, non-sensitive local preference data, so it uses `shared_preferences`
/// rather than the encrypted secure storage used for connection credentials.
abstract interface class ThemeModeStore {
  /// Read the stored theme mode, or `null` if the user has never chosen one
  /// (the app should then default to [ThemeMode.system]).
  Future<ThemeMode?> read();

  /// Persist [mode], replacing anything already stored.
  Future<void> write(ThemeMode mode);
}

/// [ThemeModeStore] backed by `shared_preferences`.
///
/// The mode is stored as its [ThemeMode.name] string under a single key.
class SharedPreferencesThemeModeStore implements ThemeModeStore {
  SharedPreferencesThemeModeStore({
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferences;

  static const _key = 'theme_mode';

  @override
  Future<ThemeMode?> read() async {
    final prefs = await _preferences();
    final stored = prefs.getString(_key);
    if (stored == null) return null;
    return ThemeMode.values.asNameMap()[stored];
  }

  @override
  Future<void> write(ThemeMode mode) async {
    final prefs = await _preferences();
    await prefs.setString(_key, mode.name);
  }
}
