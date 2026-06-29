/// Immutable connection settings for a single Home Assistant instance.
///
/// Holds the base URL and a long-lived access token (created in the HA user
/// profile) and derives the WebSocket and REST endpoints from them. Kept as a
/// plain Dart value object so it can be constructed in tests and overridden in
/// a Riverpod `ProviderScope` without any UI dependency.
class HaConnectionConfig {
  const HaConnectionConfig({required this.baseUrl, required this.accessToken});

  /// Base URL of the instance, e.g. `https://ha.example.com` or
  /// `http://192.168.1.10:8123`. Any path, query or fragment is ignored — only
  /// the scheme, host and port are used to build the API endpoints.
  final Uri baseUrl;

  /// Long-lived access token used for both the WebSocket `auth` handshake and
  /// the REST `Authorization: Bearer` header.
  final String accessToken;

  /// WebSocket endpoint: `ws(s)://host[:port]/api/websocket`.
  ///
  /// `https` maps to `wss` and `http` (or anything else) to `ws`. Built from
  /// scheme/host/port only, so any path, query or fragment on [baseUrl] is
  /// dropped.
  Uri get webSocketUrl => Uri(
    scheme: baseUrl.scheme == 'https' ? 'wss' : 'ws',
    host: baseUrl.host,
    port: baseUrl.hasPort ? baseUrl.port : null,
    path: '/api/websocket',
  );

  /// Base URI for REST calls: `http(s)://host[:port]/api`.
  Uri get restBaseUrl => Uri(
    scheme: baseUrl.scheme,
    host: baseUrl.host,
    port: baseUrl.hasPort ? baseUrl.port : null,
    path: '/api',
  );

  @override
  bool operator ==(Object other) =>
      other is HaConnectionConfig &&
      other.baseUrl == baseUrl &&
      other.accessToken == accessToken;

  @override
  int get hashCode => Object.hash(baseUrl, accessToken);

  @override
  String toString() => 'HaConnectionConfig(baseUrl: $baseUrl)';
}
