import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/presentation/app_page.dart';
import '../../../shared/presentation/page_state.dart';
import '../../connection/presentation/connection_status_indicator.dart';
import '../application/chart_providers.dart';
import '../domain/chart_series.dart';
import '../domain/history_range.dart';
import 'time_series_chart.dart';

export '../domain/history_range.dart' show HistoryRange;

/// Screen that renders a *real* Home Assistant entity's recorded history as a
/// chart, replacing the static sample example (#13).
///
/// It defaults to a sensible entity (the first numeric `sensor.*`, via
/// [defaultChartEntityProvider]) so it is useful without any interaction, but
/// also offers a dropdown (#20) listing every numeric `sensor.*` known to the
/// live entity store ([numericSensorEntitiesProvider]) so the user can pick
/// which one to chart; the choice is held in [selectedChartEntityProvider].
/// A [HistoryRange] selector (1h / 24h / 7d, #21) lets the user pick the
/// trailing window, held in [selectedHistoryRangeProvider]: the selected
/// option becomes the `period` on the [EntityHistoryRequest] key, so changing
/// it re-fetches (and caches) the chart for that window. Both selections are
/// persisted locally (#61) via [chartSelectionStoreProvider], so they survive
/// an app restart — a fresh install (nothing stored yet) keeps today's
/// defaults (first numeric sensor / 24h). Either way, the resolved entity's
/// trailing history is fetched through [entityHistorySeriesProvider] and
/// handed to [AppPage.async] so loading, error and empty states all use the
/// shared template surfaces (#3). The chart itself is the unchanged
/// [TimeSeriesChart] wrapper — only the data source is new.
/// The content is also wrapped in a [RefreshIndicator] (#32): pulling down
/// re-fetches the same [entityHistorySeriesProvider] family member the manual
/// refresh [IconButton] already invalidates, via `ref.refresh(...future)` so
/// `onRefresh` completes once the new data (or error) has landed.
class EntityHistoryPage extends ConsumerWidget {
  const EntityHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final numericSensors = ref.watch(numericSensorEntitiesProvider);
    // Both selections are restored asynchronously from local storage (#61).
    // While that read is in flight (effectively instant on native, briefly
    // async on web) `valueOrNull` yields null/the range default so the screen
    // renders with today's defaults instead of an extra loading surface; it
    // then rebuilds once the stored value lands.
    final selected = ref.watch(selectedChartEntityProvider).valueOrNull;
    final range =
        ref.watch(selectedHistoryRangeProvider).valueOrNull ??
        HistoryRange.hours24;
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
                  ref.read(selectedChartEntityProvider.notifier).select(value),
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
        connectionIndicator: ConnectionStatusIndicator(),
        body: SizedBox.shrink(),
      );
    }

    final period = range.period;
    final request = EntityHistoryRequest(entityId: entityId, period: period);
    final series = ref.watch(entityHistorySeriesProvider(request));

    return AppPage.async<ChartSeries>(
      title: 'History',
      value: series,
      isEmpty: (data) => data.points.isEmpty,
      emptyBuilder: (context) =>
          _NoHistoryEmptyState(entityId: entityId, period: period),
      onRetry: () => ref.invalidate(entityHistorySeriesProvider(request)),
      connectionIndicator: const ConnectionStatusIndicator(),
      actions: [
        SegmentedButton<HistoryRange>(
          segments: [
            for (final r in HistoryRange.values)
              ButtonSegment(value: r, label: Text(r.label)),
          ],
          selected: {range},
          onSelectionChanged: (selection) => ref
              .read(selectedHistoryRangeProvider.notifier)
              .select(selection.first),
        ),
        const SizedBox(width: 12),
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(entityHistorySeriesProvider(request)),
        ),
      ],
      builder: (context, data) {
        return RefreshIndicator(
          onRefresh: () =>
              ref.refresh(entityHistorySeriesProvider(request).future),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: CustomScrollView(
              // Pull-to-refresh needs a scrollable to drive the gesture even
              // when the content itself fits on screen without scrolling.
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverList(
                  delegate: SliverChildListDelegate([
                    ?picker,
                    Text(
                      _caption(entityId, period, data.unit),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                  ]),
                ),
                SliverFillRemaining(
                  hasScrollBody: true,
                  child: TimeSeriesChart(series: [data], title: data.name),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Builds the "Live history for `<entity>`" caption, appending the series'
/// unit of measurement (e.g. `°C`) in parentheses when one is present. When
/// [unit] is `null` or empty, the caption is unchanged from before the unit
/// was surfaced — no stray "null" text.
String _caption(String entityId, Duration period, String? unit) {
  final unitSuffix = (unit == null || unit.isEmpty) ? '' : ' ($unit)';
  return 'Live history for $entityId (last ${period.inHours}h)$unitSuffix.';
}

/// Empty surface shown when the selected entity has no recorded history for
/// the current [period] (#34). Mirrors the shared `_EmptyState` in
/// [AppPage] (themed icon + message, centred) but swaps the generic inbox
/// icon for a history/chart-related one and spells out *why* nothing is
/// showing, since a blank chart otherwise reads as broken rather than empty.
class _NoHistoryEmptyState extends StatelessWidget {
  const _NoHistoryEmptyState({required this.entityId, required this.period});

  final String entityId;
  final Duration period;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.show_chart,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No history for this entity yet',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$entityId has no recorded state changes in the last '
              '${period.inHours}h. Once Home Assistant records some, '
              'they will show up here as a chart.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
