import 'dart:math';

import '../domain/chart_series.dart';

/// Static, deterministic sample data used by the example chart screen.
///
/// This stands in for real Home Assistant entity history until the
/// communication layer (#2) can supply it. It produces the same generic
/// [ChartSeries] type the real source will, so swapping it out later is a
/// one-line change at the call site.
abstract final class SampleChartData {
  /// A fabricated 24-hour temperature curve, one point per hour.
  static ChartSeries temperature({DateTime? endingAt}) {
    final end = endingAt ?? DateTime(2026, 6, 29, 12);
    // Seeded so the screen and any golden/widget expectations are stable.
    final random = Random(42);
    final points = <TimeSeriesPoint>[];
    for (var hoursAgo = 24; hoursAgo >= 0; hoursAgo--) {
      final time = end.subtract(Duration(hours: hoursAgo));
      // Diurnal sine curve around 21°C with a little noise.
      final base = 21 + 4 * sin((time.hour / 24) * 2 * pi);
      final value = base + (random.nextDouble() - 0.5) * 1.5;
      points.add(
        TimeSeriesPoint(
          time: time,
          value: double.parse(value.toStringAsFixed(1)),
        ),
      );
    }
    return ChartSeries(name: 'Living room', points: points, unit: '°C');
  }

  /// A fabricated 7-day energy-usage series, one point per day — suits a bar
  /// chart.
  static ChartSeries dailyEnergy({DateTime? endingAt}) {
    final end = endingAt ?? DateTime(2026, 6, 29);
    final random = Random(7);
    final points = <TimeSeriesPoint>[];
    for (var daysAgo = 6; daysAgo >= 0; daysAgo--) {
      final time = DateTime(end.year, end.month, end.day - daysAgo);
      final value = 8 + random.nextDouble() * 6;
      points.add(
        TimeSeriesPoint(
          time: time,
          value: double.parse(value.toStringAsFixed(1)),
        ),
      );
    }
    return ChartSeries(name: 'Energy used', points: points, unit: 'kWh');
  }
}
