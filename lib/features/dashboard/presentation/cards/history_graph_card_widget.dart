import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../charts/application/chart_providers.dart';
import '../../../charts/presentation/time_series_chart.dart';
import '../../domain/lovelace_card.dart';

/// Renders a `history-graph` card: an optional title and one trailing-history
/// chart per listed entity, stacked vertically.
///
/// No new charting code — this is pure wiring onto the charts feature already
/// built for the entity-history screen (#4/#13): each entity's chart is driven
/// by [entityHistorySeriesProvider] and rendered with the same [TimeSeriesChart]
/// wrapper. Each entity is handled independently (one [_HistoryChart] per row)
/// so a single failing/loading entity shows its own spinner or error text
/// rather than blocking the whole card.
class HistoryGraphCardWidget extends StatelessWidget {
  const HistoryGraphCardWidget({required this.card, super.key});

  final HistoryGraphCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTitle = card.title != null && card.title!.trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasTitle)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(card.title!, style: theme.textTheme.titleMedium),
            ),
          for (final entityId in card.entities)
            _HistoryChart(entityId: entityId, hoursToShow: card.hoursToShow),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// One entity's trailing-history chart. A [ConsumerWidget] so only this
/// entity's tile rebuilds while its request is pending, and a per-entity
/// failure doesn't take down the rest of the card.
class _HistoryChart extends ConsumerWidget {
  const _HistoryChart({required this.entityId, required this.hoursToShow});

  final String entityId;
  final int hoursToShow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final request = EntityHistoryRequest(
      entityId: entityId,
      period: Duration(hours: hoursToShow),
    );
    final series = ref.watch(entityHistorySeriesProvider(request));

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: series.when(
        data: (data) => data.points.isEmpty
            ? _HistoryMessage(
                icon: Icons.show_chart,
                message: 'No history for $entityId yet.',
                theme: theme,
              )
            : SizedBox(
                height: 220,
                child: TimeSeriesChart(series: [data], title: data.name),
              ),
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) => _HistoryMessage(
          icon: Icons.error_outline,
          message: 'Could not load history for $entityId.',
          theme: theme,
        ),
      ),
    );
  }
}

/// Small inline message tile used for a single entity's empty/error state —
/// deliberately lightweight (no retry action) so one failing entity doesn't
/// dominate a multi-entity card.
class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.icon,
    required this.message,
    required this.theme,
  });

  final IconData icon;
  final String message;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
