import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/entity_state.dart';
import '../domain/ha_connection_config.dart';
import '../domain/ha_exception.dart';

/// Thin client for the Home Assistant REST API, used for endpoints not covered
/// by (or more convenient than) the WebSocket API.
///
/// The [http.Client] can be injected so the layer is unit-testable with
/// `package:http/testing.dart`'s `MockClient` — no real server required.
///
/// Reference: https://developers.home-assistant.io/docs/api/rest
class HaRestClient {
  HaRestClient({required HaConnectionConfig config, http.Client? httpClient})
    : _config = config,
      _client = httpClient ?? http.Client(),
      _ownsClient = httpClient == null;

  final HaConnectionConfig _config;
  final http.Client _client;
  final bool _ownsClient;

  Map<String, String> get _headers => {
    'Authorization': 'Bearer ${_config.accessToken}',
    'Content-Type': 'application/json',
  };

  Uri _endpoint(String path) =>
      _config.restBaseUrl.replace(path: '${_config.restBaseUrl.path}$path');

  /// `GET /api/` — true when the API is reachable and the token is valid.
  Future<bool> ping() async {
    final response = await _request(
      () => _client.get(_endpoint('/'), headers: _headers),
    );
    return response.statusCode == 200;
  }

  /// `GET /api/states` — every current entity state.
  Future<List<EntityState>> fetchStates() async {
    final response = await _request(
      () => _client.get(_endpoint('/states'), headers: _headers),
    );
    return _decodeList(response)
        .whereType<Map>()
        .map((e) => EntityState.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// `GET /api/states/<entity_id>` — a single entity state.
  Future<EntityState> fetchState(String entityId) async {
    final response = await _request(
      () => _client.get(_endpoint('/states/$entityId'), headers: _headers),
    );
    return EntityState.fromJson(_decodeMap(response));
  }

  /// `POST /api/services/<domain>/<service>` — call a service. Returns the
  /// states that changed as a result.
  Future<List<EntityState>> callService(
    String domain,
    String service, {
    Map<String, dynamic>? data,
  }) async {
    final response = await _request(
      () => _client.post(
        _endpoint('/services/$domain/$service'),
        headers: _headers,
        body: jsonEncode(data ?? const <String, dynamic>{}),
      ),
    );
    return _decodeList(response)
        .whereType<Map>()
        .map((e) => EntityState.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// Close the underlying [http.Client] — only if this client created it.
  void close() {
    if (_ownsClient) _client.close();
  }

  // --- Helpers ------------------------------------------------------------

  /// Run a request, normalising any transport failure (e.g. SocketException,
  /// http.ClientException) into a [HaConnectionException] so callers only ever
  /// have to handle [HaException]s. [HaException]s thrown downstream pass
  /// through unchanged.
  Future<http.Response> _request(Future<http.Response> Function() send) async {
    try {
      return await send();
    } on HaException {
      rethrow;
    } catch (error) {
      throw HaConnectionException('REST request failed', cause: error);
    }
  }

  void _ensureSuccess(http.Response response) {
    final code = response.statusCode;
    if (code == 401 || code == 403) {
      throw HaAuthException(
        'Unauthorized (HTTP $code) — check the access token',
      );
    }
    if (code < 200 || code >= 300) {
      throw HaRestException('Request failed', statusCode: code);
    }
  }

  List<dynamic> _decodeList(http.Response response) {
    _ensureSuccess(response);
    final decoded = _decodeJson(response);
    if (decoded is! List) {
      throw const HaRestException('Expected a JSON array');
    }
    return decoded;
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    _ensureSuccess(response);
    final decoded = _decodeJson(response);
    if (decoded is! Map) {
      throw const HaRestException('Expected a JSON object');
    }
    return decoded.cast<String, dynamic>();
  }

  /// Decode the body as JSON, mapping a malformed/empty body to a
  /// [HaRestException] instead of letting a raw [FormatException] escape.
  Object? _decodeJson(http.Response response) {
    try {
      return jsonDecode(response.body);
    } on FormatException catch (error) {
      throw HaRestException(
        'Invalid JSON response: ${error.message}',
        statusCode: response.statusCode,
      );
    }
  }
}
