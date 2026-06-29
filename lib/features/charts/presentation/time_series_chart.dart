import 'package:flutter/material.dart';
import 'package:graphify/graphify.dart';

import '../application/chart_config_mapper.dart';
import '../domain/chart_series.dart';
import '../domain/chart_theme.dart';

/// A reusable, themable chart that renders one or more generic
/// [ChartSeries] as a line or bar chart.
///
/// Feature screens pass plain [ChartSeries] data and a [ChartType]; this widget
/// owns everything ECharts-specific. It derives a [ChartTheme] from the ambient
/// `Theme.of(context)`, so charts automatically follow the app's light/dark
/// theme, then delegates rendering to `graphify`'s [GraphifyView].
///
/// Keeping the public input a plain data type (not an HA model) means the same
/// widget drops into the real entity-history flow once the communication layer
/// (#2) is available — only the data source changes.
class TimeSeriesChart extends StatefulWidget {
  const TimeSeriesChart({
    super.key,
    required this.series,
    this.type = ChartType.line,
    this.title,
  });

  /// The data to plot. Each entry becomes one chart series.
  final List<ChartSeries> series;

  /// Whether to draw lines or bars.
  final ChartType type;

  /// Optional chart title rendered by ECharts.
  final String? title;

  @override
  State<TimeSeriesChart> createState() => _TimeSeriesChartState();
}

class _TimeSeriesChartState extends State<TimeSeriesChart> {
  final _controller = GraphifyController();

  @override
  void didUpdateWidget(TimeSeriesChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-render when the data, chart type or title change after first build.
    if (oldWidget.series != widget.series ||
        oldWidget.type != widget.type ||
        oldWidget.title != widget.title) {
      _controller.update(_optionsFor(context));
    }
  }

  /// Translates the ambient Material theme into a [ChartTheme] and runs the
  /// mapper. Done here (not in the mapper) so the mapping stays widget-free.
  Map<String, dynamic> _optionsFor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chartTheme = ChartTheme(
      brightness: scheme.brightness,
      seriesColors: [
        scheme.primary,
        scheme.tertiary,
        scheme.secondary,
        scheme.error,
      ],
      foregroundColor: scheme.onSurface,
      gridLineColor: scheme.outlineVariant,
      backgroundColor: Colors.transparent,
    );
    return ChartConfigMapper.build(
      series: widget.series,
      type: widget.type,
      theme: chartTheme,
      title: widget.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GraphifyView(
      controller: _controller,
      // Rebuild options against the *current* theme on every build so a
      // light/dark switch re-themes the chart.
      initialOptions: _optionsFor(context),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
