import '../domain/chart_series.dart';
import '../domain/chart_theme.dart';

/// Maps generic time-series data into an Apache ECharts option map (the JSON
/// `graphify` renders).
///
/// This is the single place that knows about ECharts JSON. It is a pure
/// function of its inputs — no Flutter widgets, no `BuildContext` — so feature
/// screens never hand-write ECharts config and the mapping is fully
/// unit-testable.
abstract final class ChartConfigMapper {
  /// Builds an ECharts option map for [series] rendered as [type], themed with
  /// [theme].
  ///
  /// Time is encoded on a `time`-type x-axis using ISO-8601 strings, so points
  /// don't have to be evenly spaced. Each [ChartSeries] becomes one ECharts
  /// series, coloured from [ChartTheme.seriesColors] (cycled).
  static Map<String, dynamic> build({
    required List<ChartSeries> series,
    required ChartType type,
    required ChartTheme theme,
    String? title,
  }) {
    assert(theme.seriesColors.isNotEmpty, 'seriesColors must not be empty');

    final foreground = colorToCss(theme.foregroundColor);
    final gridLine = colorToCss(theme.gridLineColor);
    final palette = theme.seriesColors.map(colorToCss).toList();

    return <String, dynamic>{
      'backgroundColor': colorToCss(theme.backgroundColor),
      'color': palette,
      if (title != null)
        'title': <String, dynamic>{
          'text': title,
          'textStyle': <String, dynamic>{'color': foreground},
        },
      'tooltip': <String, dynamic>{
        'trigger': 'axis',
        'axisPointer': <String, dynamic>{
          'type': type == ChartType.bar ? 'shadow' : 'line',
        },
      },
      'legend': <String, dynamic>{
        'show': series.length > 1,
        'data': [for (final s in series) s.name],
        'textStyle': <String, dynamic>{'color': foreground},
      },
      'grid': <String, dynamic>{
        'left': '3%',
        'right': '4%',
        'bottom': '3%',
        'top': title != null ? '15%' : '10%',
        'containLabel': true,
      },
      'xAxis': <String, dynamic>{
        'type': 'time',
        'axisLine': <String, dynamic>{
          'lineStyle': <String, dynamic>{'color': gridLine},
        },
        'axisLabel': <String, dynamic>{'color': foreground},
      },
      'yAxis': <String, dynamic>{
        'type': 'value',
        'axisLine': <String, dynamic>{
          'lineStyle': <String, dynamic>{'color': gridLine},
        },
        'axisLabel': <String, dynamic>{'color': foreground},
        'splitLine': <String, dynamic>{
          'lineStyle': <String, dynamic>{'color': gridLine},
        },
      },
      'series': [for (final s in series) _seriesToJson(s, type)],
    };
  }

  static Map<String, dynamic> _seriesToJson(
    ChartSeries series,
    ChartType type,
  ) {
    return <String, dynamic>{
      'name': series.name,
      'type': _typeName(type),
      if (type == ChartType.line) ...<String, dynamic>{
        'smooth': true,
        'showSymbol': false,
      },
      'data': [
        for (final point in series.points)
          // ECharts time axis accepts [time, value] pairs; ISO-8601 strings
          // are parsed natively and keep timezone information explicit.
          [point.time.toIso8601String(), point.value],
      ],
    };
  }

  static String _typeName(ChartType type) => switch (type) {
    ChartType.line => 'line',
    ChartType.bar => 'bar',
  };
}
