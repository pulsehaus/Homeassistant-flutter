import '../../connection/data/ha_rest_client.dart';
import '../domain/chart_series.dart';
import 'entity_history_mapper.dart';

/// Fetches an entity's recorded history from Home Assistant and returns it as
/// the generic [ChartSeries] the chart layer renders.
///
/// It owns no transport or parsing logic of its own: the HTTP call is delegated
/// to the injected [HaRestClient] (connection layer, #2) and the JSON→domain
/// translation to the pure [EntityHistoryMapper]. This keeps the repository a
/// thin, single-responsibility seam that the application layer can depend on
/// through an abstraction.
class EntityHistoryRepository {
  const EntityHistoryRepository(this._client);

  final HaRestClient _client;

  /// History for [entityId] over the trailing [period] (ending now).
  ///
  /// [now] is injectable so tests can pin the time window deterministically.
  Future<ChartSeries> fetchSeries(
    String entityId, {
    Duration period = const Duration(hours: 24),
    String? fallbackName,
    DateTime? now,
  }) async {
    final end = now ?? DateTime.now();
    final start = end.subtract(period);
    final payload = await _client.fetchHistory(
      entityId,
      start: start,
      end: end,
    );
    return EntityHistoryMapper.toSeries(
      payload,
      entityId,
      fallbackName: fallbackName,
    );
  }
}
