import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_mode_store.dart';

/// The theme-mode store. Overridden in tests with a fake so no real platform
/// storage is touched.
///
/// This is plain UI/local-storage state — unrelated to the Home Assistant
/// connection graph — so, unlike the connection providers, it does not need
/// scoped `dependencies`.
final themeModeStoreProvider = Provider<ThemeModeStore>(
  (ref) => SharedPreferencesThemeModeStore(),
);

/// Owns the app's manually-selected [ThemeMode].
///
/// On startup it loads any previously chosen mode from local storage,
/// defaulting to [ThemeMode.system] when nothing has been stored yet. The app
/// root watches this to drive `MaterialApp.themeMode`, so a change here is
/// applied immediately.
class ThemeModeController extends AsyncNotifier<ThemeMode> {
  ThemeModeStore get _store => ref.read(themeModeStoreProvider);

  @override
  Future<ThemeMode> build() async => await _store.read() ?? ThemeMode.system;

  /// Persist [mode] and make it the active theme mode.
  Future<void> setThemeMode(ThemeMode mode) async {
    state = AsyncData(mode);
    await _store.write(mode);
  }

  /// Cycles system → light → dark → system, used by the app-bar toggle.
  Future<void> cycle() async {
    const order = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
    final current = state.value ?? ThemeMode.system;
    final next = order[(order.indexOf(current) + 1) % order.length];
    await setThemeMode(next);
  }
}

/// Exposes the active theme mode. The app root watches this to drive
/// `MaterialApp.themeMode`; the toggle action reads the notifier to change it.
final themeModeControllerProvider =
    AsyncNotifierProvider<ThemeModeController, ThemeMode>(
      ThemeModeController.new,
    );
