import 'package:flutter/material.dart';

import '../application/sample_chart_data.dart';
import '../domain/chart_series.dart';
import 'time_series_chart.dart';

/// Demo screen showing the [TimeSeriesChart] wrapper driven by *static* sample
/// data (see [SampleChartData]).
///
/// It exists to prove the chart pipeline end to end — generic data → ECharts
/// config → rendered chart — and to show theming and the line/bar switch. Wiring
/// it to real HA entity history (via the communication layer, #2) and dropping
/// it into the shared page template (#3) are follow-ups; the wrapper's plain
/// data input means those changes won't touch the chart itself.
class ChartExamplePage extends StatefulWidget {
  const ChartExamplePage({super.key});

  @override
  State<ChartExamplePage> createState() => _ChartExamplePageState();
}

class _ChartExamplePageState extends State<ChartExamplePage> {
  ChartType _type = ChartType.line;

  late final _temperature = SampleChartData.temperature();
  late final _energy = SampleChartData.dailyEnergy();

  ChartSeries get _series => _type == ChartType.line ? _temperature : _energy;

  String get _title => _type == ChartType.line
      ? 'Living room temperature (24h)'
      : 'Daily energy use (7d)';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Charts'),
        actions: [
          // Toggle line/bar to demonstrate both mappings against the same
          // generic data type.
          SegmentedButton<ChartType>(
            segments: const [
              ButtonSegment(
                value: ChartType.line,
                icon: Icon(Icons.show_chart),
                label: Text('Line'),
              ),
              ButtonSegment(
                value: ChartType.bar,
                icon: Icon(Icons.bar_chart),
                label: Text('Bar'),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (selection) =>
                setState(() => _type = selection.first),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sample data — real Home Assistant history is wired in once the '
              'communication layer (#2) lands.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TimeSeriesChart(
                series: [_series],
                type: _type,
                title: _title,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
