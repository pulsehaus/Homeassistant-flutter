import 'package:flutter/material.dart';

/// Centralised application theming. Features must read colours and text styles
/// from `Theme.of(context)` rather than hard-coding values, so the whole app
/// stays consistent and theme changes happen in a single place.
///
/// Both [light] and [dark] are derived from a single brand [_seed] colour and a
/// shared [_textTheme], so the two themes can never drift apart: change the seed
/// or the typography here and every screen follows.
abstract final class AppTheme {
  /// Brand seed colour. Home Assistant's primary blue. The full light/dark
  /// [ColorScheme]s are generated from this so the palette stays consistent.
  static const Color _seed = Color(0xFF03A9F4);

  /// Light theme — the default surface for the app.
  static ThemeData get light => _build(Brightness.light);

  /// Dark theme — applied automatically when the platform is in dark mode.
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: _textTheme,
      appBarTheme: const AppBarTheme(centerTitle: false),
    );
  }

  /// Shared typography applied to both themes. Kept slightly tighter than the
  /// Material default so dense dashboards stay readable. Defining it once here
  /// is the single source of truth for text styling across the app.
  static const TextTheme _textTheme = TextTheme(
    headlineSmall: TextStyle(fontWeight: FontWeight.w600),
    titleLarge: TextStyle(fontWeight: FontWeight.w600),
    titleMedium: TextStyle(fontWeight: FontWeight.w500),
  );
}
