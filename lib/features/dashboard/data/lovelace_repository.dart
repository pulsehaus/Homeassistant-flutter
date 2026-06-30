import '../../connection/data/ha_websocket_client.dart';
import '../domain/lovelace_config.dart';
import '../domain/lovelace_config_parser.dart';

/// Thin data-layer seam between the connection client and the dashboard
/// feature, mirroring the charts feature's `EntityHistoryRepository`.
///
/// It owns no transport or parsing logic itself: it asks [HaWebSocketClient] for
/// the raw config and hands it to the pure [parseLovelaceConfig]. Injected
/// through a Riverpod provider so it can be overridden in tests.
class LovelaceRepository {
  const LovelaceRepository(this._client);

  final HaWebSocketClient _client;

  /// Fetch and parse the Lovelace config. A null [urlPath] requests the default
  /// dashboard. Throws the connection layer's `HaCommandException` /
  /// `HaConnectionException` on failure (e.g. a YAML-mode dashboard).
  Future<LovelaceConfig> fetchConfig({String? urlPath}) async {
    final raw = await _client.fetchLovelaceConfig(urlPath: urlPath);
    return parseLovelaceConfig(raw);
  }
}
