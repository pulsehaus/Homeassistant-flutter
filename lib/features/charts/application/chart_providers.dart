import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../connection/application/connection_providers.dart';
import '../../connection/domain/entity_state.dart';
import '../data/entity_history_repository.dart';
import '../domain/chart_series.dart';

/// The repository that turns HA history into [ChartSeries], wired to the shared
/// REST client from the connection layer (#2).
final entityHistoryRepositoryProvider = Provider<EntityHistoryRepository>((
  ref,
) {
  return EntityHistoryRepository(ref.watch(haRestClientProvider));
}, dependencies: [haRestClientProvider]);

/// Identifies a single history request: which entity, over what trailing
/// window. Used as the family key so Riverpod caches/refetches per (entity,
/// period) pair.
@immutable
class EntityHistoryRequest {
  const EntityHistoryRequest({
    required this.entityId,
    this.period = const Duration(hours: 24),
  });

  final String entityId;
  final Duration period;

  @override
  bool operator ==(Object other) =>
      other is EntityHistoryRequest &&
      other.entityId == entityId &&
      other.period == period;

  @override
  int get hashCode => Object.hash(entityId, period);

  @override
  String toString() =>
      'EntityHistoryRequest(entityId: $entityId, period: $period)';
}

/// A single entity's history as a [ChartSeries], fetched on demand.
///
/// Async + family keyed by [EntityHistoryRequest], so `AppPage.async` can map it
/// onto the shared loading/error/empty surfaces and each (entity, period)
/// combination is cached independently.
final entityHistorySeriesProvider =
    FutureProvider.family<ChartSeries, EntityHistoryRequest>((
      ref,
      request,
    ) async {
      final repository = ref.watch(entityHistoryRepositoryProvider);
      return repository.fetchSeries(request.entityId, period: request.period);
    }, dependencies: [entityHistoryRepositoryProvider]);

/// All numeric `sensor.*` entity ids currently known to the live entity
/// store, sorted for a stable picker order.
///
/// "Numeric" means the current state parses as a number — i.e. it makes sense
/// on a value axis. Backs both [defaultChartEntityProvider] (pick the first)
/// and the entity picker on [entity_history_page] (list them all).
final numericSensorEntitiesProvider = Provider<List<String>>((ref) {
  // `valueOrNull` (not `.value`) so a loading/error connection state yields
  // "no entities yet" instead of rethrowing — the screen then shows its empty
  // surface rather than crashing.
  final states = ref.watch(entityStatesProvider).valueOrNull ?? const {};
  return states.values
      .where((e) => e.domain == 'sensor' && _isNumeric(e.state))
      .map((e) => e.entityId)
      .toList()
    ..sort();
}, dependencies: [entityStatesProvider]);

/// A sensible default entity to chart: the first numeric `sensor.*` currently
/// known to the live entity store, or null if none is available yet.
///
/// This keeps the screen useful without an explicit selection; the picker on
/// [entity_history_page] lets the user override it.
final defaultChartEntityProvider = Provider<String?>((ref) {
  final numericSensors = ref.watch(numericSensorEntitiesProvider);
  return numericSensors.isEmpty ? null : numericSensors.first;
}, dependencies: [numericSensorEntitiesProvider]);

/// The entity explicitly chosen by the user via the picker on
/// [entity_history_page], or null when nothing has been picked yet (in which
/// case the screen falls back to [defaultChartEntityProvider]).
///
/// Deliberately a plain [StateProvider]: it holds ephemeral UI selection, not
/// domain state, so it has no `dependencies` on the connection providers.
final selectedChartEntityProvider = StateProvider<String?>((ref) => null);

bool _isNumeric(String state) => double.tryParse(state) != null;

/// Convenience accessor for the friendly name of an entity, used to label the
/// chart/series when present.
String? friendlyNameOf(EntityState? entity) => entity?.friendlyName;
