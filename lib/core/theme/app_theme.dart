import 'package:flutter/material.dart';

/// Centralised application theming. Features must read colours and text styles
/// from `Theme.of(context)` rather than hard-coding values, so the whole app
/// stays consistent and theme changes happen in a single place.
abstract final class AppTheme {
  /// Brand seed colour. Home Assistant's primary blue.
  static const Color _seed = Color(0xFF03A9F4);

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: brightness,
      ),
    );
  }
}
