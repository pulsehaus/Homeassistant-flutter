import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/charts/application/sample_chart_data.dart';

void main() {
  group('SampleChartData', () {
    test('temperature returns 25 hourly points in chronological order', () {
      final series = SampleChartData.temperature(
        endingAt: DateTime(2026, 6, 29, 12),
      );

      expect(series.unit, '°C');
      // 24 hours ago .. now inclusive.
      expect(series.points, hasLength(25));
      for (var i = 1; i < series.points.length; i++) {
        expect(
          series.points[i].time.isAfter(series.points[i - 1].time),
          isTrue,
        );
      }
    });

    test('temperature is deterministic (seeded)', () {
      final a = SampleChartData.temperature(
        endingAt: DateTime(2026, 6, 29, 12),
      );
      final b = SampleChartData.temperature(
        endingAt: DateTime(2026, 6, 29, 12),
      );
      expect(a.points, b.points);
    });

    test('dailyEnergy returns 7 daily points', () {
      final series = SampleChartData.dailyEnergy(
        endingAt: DateTime(2026, 6, 29),
      );
      expect(series.unit, 'kWh');
      expect(series.points, hasLength(7));
    });
  });
}
