import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/presentation/app_page.dart';
import '../../../shared/presentation/page_state.dart';
import '../application/chart_providers.dart';
import '../domain/chart_series.dart';
import 'time_series_chart.dart';

/// The trailing windows offered by the history screen's range selector.
///
/// Each option maps 1:1 to a [Duration] fed into [EntityHistoryRequest.period]
/// — switching options re-keys the [entityHistorySeriesProvider] family, so
/// Riverpod fetches (and independently caches) the new window.
enum HistoryRange {
  hour1(Duration(hours: 1), '1h'),
  hours24(Duration(hours: 24), '24h'),
  days7(Duration(days: 7), '7d');

  const HistoryRange(this.period, this.label);

  /// The trailing window this option represents.
  final Duration period;

  /// Short label shown on the selector segment.
  final String label;
}

/// Screen that renders a *real* Home Assistant entity's recorded history as a
/// chart, replacing the static sample example (#13).
///
/// It defaults to a sensible entity (the first numeric `sensor.*`, via
/// [defaultChartEntityProvider]) so it is useful without any interaction, but
/// also offers a dropdown (#20) listing every numeric `sensor.*` known to the
/// live entity store ([numericSensorEntitiesProvider]) so the user can pick
/// which one to chart; the choice is held in [selectedChartEntityProvider].
/// A [HistoryRange] selector (1h / 24h / 7d, #21) lets the user pick the
/// trailing window: the selected option becomes the `period` on the
/// [EntityHistoryRequest] key, so changing it re-fetches (and caches) the
/// chart for that window. Either way, the resolved entity's trailing history
/// is fetched through [entityHistorySeriesProvider] and handed to
/// [AppPage.async] so loading, error and empty states all use the shared
/// template surfaces (#3). The chart itself is the unchanged
/// [TimeSeriesChart] wrapper — only the data source is new.
class EntityHistoryPage extends ConsumerStatefulWidget {
  const EntityHistoryPage({
    super.key,
    this.initialRange = HistoryRange.hours24,
  });

  /// Range selected on first load. Defaults to 24h, matching the existing
  /// [EntityHistoryRequest] default.
  final HistoryRange initialRange;

  @override
  ConsumerState<EntityHistoryPage> createState() => _EntityHistoryPageState();
}

class _EntityHistoryPageState extends ConsumerState<EntityHistoryPage> {
  late HistoryRange _range = widget.initialRange;

  @override
  Widget build(BuildContext context) {
    final numericSensors = ref.watch(numericSensorEntitiesProvider);
    final selected = ref.watch(selectedChartEntityProvider);
    // Fall back to the default entity when nothing has been explicitly
    // selected yet, or the previous selection is no longer numeric/known.
    final defaultEntityId = ref.watch(defaultChartEntityProvider);
    final entityId = (selected != null && numericSensors.contains(selected))
        ? selected
        : defaultEntityId;

    final picker = numericSensors.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButton<String>(
              isExpanded: true,
              value: entityId != null && numericSensors.contains(entityId)
                  ? entityId
                  : null,
              hint: const Text('Select a sensor'),
              items: [
                for (final id in numericSensors)
                  DropdownMenuItem(value: id, child: Text(id)),
              ],
              onChanged: (value) =>
                  ref.read(selectedChartEntityProvider.notifier).state = value,
            ),
          );

    // No numeric sensor is known yet (entities still streaming in, or the
    // instance has none) — show the shared empty surface rather than an error.
    if (entityId == null) {
      return const AppPage(
        title: 'History',
        state: PageState.empty(),
        emptyMessage:
            'No numeric sensor found yet.\nConnect an instance with a '
            'sensor.* entity to chart its history.',
        body: SizedBox.shrink(),
      );
    }

    final period = _range.period;
    final request = EntityHistoryRequest(entityId: entityId, period: period);
    final series = ref.watch(entityHistorySeriesProvider(request));

    return AppPage.async<ChartSeries>(
      title: 'History',
      value: series,
      isEmpty: (data) => data.points.isEmpty,
      emptyMessage:
          'No recorded history for this entity in the last '
          '${period.inHours}h.',
      onRetry: () => ref.invalidate(entityHistorySeriesProvider(request)),
      actions: [
        SegmentedButton<HistoryRange>(
          segments: [
            for (final range in HistoryRange.values)
              ButtonSegment(value: range, label: Text(range.label)),
          ],
          selected: {_range},
          onSelectionChanged: (selection) =>
              setState(() => _range = selection.first),
        ),
        const SizedBox(width: 12),
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(entityHistorySeriesProvider(request)),
        ),
      ],
      builder: (context, data) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ?picker,
              Text(
                'Live history for $entityId (last ${period.inHours}h).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TimeSeriesChart(series: [data], title: data.name),
              ),
            ],
          ),
        );
      },
    );
  }
}
