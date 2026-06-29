import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/charts/application/chart_config_mapper.dart';
import 'package:homeassistant_flutter/features/charts/domain/chart_series.dart';
import 'package:homeassistant_flutter/features/charts/domain/chart_theme.dart';

ChartTheme _theme({Brightness brightness = Brightness.light}) => ChartTheme(
  brightness: brightness,
  seriesColors: const [Color(0xFF03A9F4), Color(0xFFFF5722)],
  foregroundColor: const Color(0xFF111111),
  gridLineColor: const Color(0xFFCCCCCC),
  backgroundColor: const Color(0x00000000),
);

ChartSeries _series() => ChartSeries(
  name: 'Living room',
  unit: '°C',
  points: [
    TimeSeriesPoint(time: DateTime.utc(2026, 6, 29, 10), value: 20.5),
    TimeSeriesPoint(time: DateTime.utc(2026, 6, 29, 11), value: 21.0),
    TimeSeriesPoint(time: DateTime.utc(2026, 6, 29, 12), value: 22.3),
  ],
);

void main() {
  group('ChartConfigMapper.build', () {
    test('maps a line series into an ECharts time-axis option map', () {
      final config = ChartConfigMapper.build(
        series: [_series()],
        type: ChartType.line,
        theme: _theme(),
      );

      // Axes: time on x, value on y.
      expect((config['xAxis'] as Map)['type'], 'time');
      expect((config['yAxis'] as Map)['type'], 'value');

      final series = config['series'] as List;
      expect(series, hasLength(1));
      final first = series.first as Map<String, dynamic>;
      expect(first['type'], 'line');
      expect(first['name'], 'Living room');

      // Each point becomes an [isoTime, value] pair, in order.
      final data = first['data'] as List;
      expect(data, hasLength(3));
      expect(data.first, ['2026-06-29T10:00:00.000Z', 20.5]);
      expect(data.last, ['2026-06-29T12:00:00.000Z', 22.3]);
    });

    test('maps a bar series with the bar type and shadow axis pointer', () {
      final config = ChartConfigMapper.build(
        series: [_series()],
        type: ChartType.bar,
        theme: _theme(),
      );

      final first = (config['series'] as List).first as Map<String, dynamic>;
      expect(first['type'], 'bar');
      // Line-only options must not leak into a bar series.
      expect(first.containsKey('smooth'), isFalse);

      expect(
        ((config['tooltip'] as Map)['axisPointer'] as Map)['type'],
        'shadow',
      );
    });

    test('line series carries smooth/showSymbol styling', () {
      final config = ChartConfigMapper.build(
        series: [_series()],
        type: ChartType.line,
        theme: _theme(),
      );
      final first = (config['series'] as List).first as Map<String, dynamic>;
      expect(first['smooth'], isTrue);
      expect(first['showSymbol'], isFalse);
    });

    test('applies theme colours to palette, axes and background', () {
      final config = ChartConfigMapper.build(
        series: [_series()],
        type: ChartType.line,
        theme: _theme(),
      );

      // Palette comes from seriesColors, hex-encoded.
      expect(config['color'], ['#03a9f4', '#ff5722']);
      // Transparent background round-trips through rgba(...).
      expect(config['backgroundColor'], 'rgba(0, 0, 0, 0.000)');
      // Foreground colour drives axis labels.
      expect(
        ((config['xAxis'] as Map)['axisLabel'] as Map)['color'],
        '#111111',
      );
      expect(
        ((config['yAxis'] as Map)['splitLine'] as Map)['lineStyle'] as Map,
        containsPair('color', '#cccccc'),
      );
    });

    test('legend is hidden for a single series and shown for multiple', () {
      final single = ChartConfigMapper.build(
        series: [_series()],
        type: ChartType.line,
        theme: _theme(),
      );
      expect((single['legend'] as Map)['show'], isFalse);

      final multi = ChartConfigMapper.build(
        series: [_series(), _series()],
        type: ChartType.line,
        theme: _theme(),
      );
      expect((multi['legend'] as Map)['show'], isTrue);
      expect((multi['series'] as List), hasLength(2));
    });

    test('title is included only when provided', () {
      final without = ChartConfigMapper.build(
        series: [_series()],
        type: ChartType.line,
        theme: _theme(),
      );
      expect(without.containsKey('title'), isFalse);

      final withTitle = ChartConfigMapper.build(
        series: [_series()],
        type: ChartType.line,
        theme: _theme(),
        title: 'Temperature',
      );
      expect((withTitle['title'] as Map)['text'], 'Temperature');
    });

    test('handles an empty series without throwing', () {
      final config = ChartConfigMapper.build(
        series: const [ChartSeries(name: 'empty', points: [])],
        type: ChartType.line,
        theme: _theme(),
      );
      final first = (config['series'] as List).first as Map<String, dynamic>;
      expect(first['data'], isEmpty);
    });
  });

  group('colorToCss', () {
    test('emits #rrggbb for opaque colours', () {
      expect(colorToCss(const Color(0xFF112233)), '#112233');
    });

    test('emits rgba(...) for translucent colours', () {
      expect(colorToCss(const Color(0x80112233)), 'rgba(17, 34, 51, 0.502)');
    });
  });
}
