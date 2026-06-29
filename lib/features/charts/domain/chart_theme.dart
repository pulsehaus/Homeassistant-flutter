import 'dart:ui';

import 'package:flutter/foundation.dart';

/// The styling inputs the chart config mapper needs, expressed as plain values
/// rather than a Flutter `ThemeData`/`BuildContext`.
///
/// Keeping the mapper's theme input as a pure data object means the
/// data→ECharts-JSON mapping can be unit-tested without pumping a widget, and
/// the presentation layer is the only place that has to translate
/// `Theme.of(context)` into one of these.
@immutable
class ChartTheme {
  const ChartTheme({
    required this.brightness,
    required this.seriesColors,
    required this.foregroundColor,
    required this.gridLineColor,
    required this.backgroundColor,
  });

  /// Light or dark — drives ECharts' built-in defaults where we don't override.
  final Brightness brightness;

  /// Palette used for series, cycled in order. Must not be empty.
  final List<Color> seriesColors;

  /// Colour for axis labels, legend and tooltip text.
  final Color foregroundColor;

  /// Colour for axis lines and split (grid) lines.
  final Color gridLineColor;

  /// Chart canvas background. Usually transparent so the host surface shows.
  final Color backgroundColor;

  bool get isDark => brightness == Brightness.dark;
}

/// Converts a Flutter [Color] to the `#RRGGBB`/`#AARRGGBB` hex string ECharts
/// expects. ECharts accepts `#rrggbb`; for partial opacity we emit `rgba(...)`.
String colorToCss(Color color) {
  final a = (color.a * 255.0).round() & 0xff;
  final r = (color.r * 255.0).round() & 0xff;
  final g = (color.g * 255.0).round() & 0xff;
  final b = (color.b * 255.0).round() & 0xff;
  if (a == 0xff) {
    final hex = ((r << 16) | (g << 8) | b).toRadixString(16).padLeft(6, '0');
    return '#$hex';
  }
  final opacity = (a / 255.0);
  return 'rgba($r, $g, $b, ${opacity.toStringAsFixed(3)})';
}
