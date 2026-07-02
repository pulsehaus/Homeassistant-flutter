import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/ha_exception.dart';
import '../domain/oauth_client_config.dart';
import '../domain/oauth_token_response.dart';

/// Drives the HTTP side of Home Assistant's OAuth2 authorization-code flow:
/// builds the `/auth/authorize` URL the WebView navigates to, and performs the
/// `/auth/token` exchanges (authorization code → tokens, and refresh token →
/// new access token).
///
/// The [http.Client] can be injected so the exchange requests are
/// unit-testable with `package:http/testing.dart`'s `MockClient` — no real
/// server required, mirroring [HaRestClient].
///
/// Reference: https://developers.home-assistant.io/docs/auth_api
class HaAuthClient {
  HaAuthClient({required this.baseUrl, http.Client? httpClient})
    : _client = httpClient ?? http.Client(),
      _ownsClient = httpClient == null;

  /// Base URL of the instance, e.g. `https://ha.example.com`.
  final Uri baseUrl;

  final http.Client _client;
  final bool _ownsClient;

  /// The URL the login WebView should navigate to, starting the
  /// authorization-code grant. Home Assistant shows its hosted login +
  /// consent page and, once the user approves, redirects to
  /// [OAuthClientConfig.redirectUri] with a `code` query parameter.
  Uri authorizeUrl() => baseUrl.replace(
    path: '${baseUrl.path}/auth/authorize',
    queryParameters: {
      'client_id': OAuthClientConfig.clientId,
      'redirect_uri': OAuthClientConfig.redirectUri,
      'response_type': 'code',
    },
  );

  /// Exchanges an authorization [code] (captured from the WebView redirect)
  /// for an access + refresh token pair.
  ///
  /// Throws [HaAuthException] if HA rejects the code (e.g. it already expired
  /// or was already used) and [HaConnectionException] on a transport failure.
  Future<OAuthTokenResponse> exchangeCode(String code) => _tokenRequest({
    'grant_type': 'authorization_code',
    'code': code,
    'client_id': OAuthClientConfig.clientId,
  });

  /// Exchanges a [refreshToken] for a new access token, without involving the
  /// user again. Home Assistant does not reissue a refresh token on this path,
  /// so the response reuses [refreshToken] as a fallback (see
  /// [OAuthTokenResponse.fromJson]).
  ///
  /// Throws [HaAuthException] if the refresh token itself has been revoked
  /// (the user must log in again) and [HaConnectionException] on a transport
  /// failure.
  Future<OAuthTokenResponse> refresh(String refreshToken) => _tokenRequest({
    'grant_type': 'refresh_token',
    'refresh_token': refreshToken,
    'client_id': OAuthClientConfig.clientId,
  }, fallbackRefreshToken: refreshToken);

  Future<OAuthTokenResponse> _tokenRequest(
    Map<String, String> body, {
    String? fallbackRefreshToken,
  }) async {
    final http.Response response;
    try {
      response = await _client.post(
        baseUrl.replace(path: '${baseUrl.path}/auth/token'),
        headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );
    } catch (error) {
      throw HaConnectionException('Token request failed', cause: error);
    }

    if (response.statusCode == 400 || response.statusCode == 401) {
      throw HaAuthException(_describeError(response));
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HaRestException(
        'Token request failed',
        statusCode: response.statusCode,
      );
    }

    final Map<String, dynamic> json;
    try {
      json = (jsonDecode(response.body) as Map).cast<String, dynamic>();
    } on FormatException catch (error) {
      throw HaRestException(
        'Invalid JSON in token response: ${error.message}',
        statusCode: response.statusCode,
      );
    }

    try {
      return OAuthTokenResponse.fromJson(
        json,
        fallbackRefreshToken: fallbackRefreshToken,
      );
    } on FormatException catch (error) {
      throw HaRestException('Malformed token response: ${error.message}');
    }
  }

  String _describeError(http.Response response) {
    try {
      final json = (jsonDecode(response.body) as Map).cast<String, dynamic>();
      final description = json['error_description'] ?? json['error'];
      if (description is String && description.isNotEmpty) return description;
    } catch (_) {
      // Fall through to the generic message below.
    }
    return 'The server rejected the login (HTTP ${response.statusCode}).';
  }

  /// Close the underlying [http.Client] — only if this client created it.
  void close() {
    if (_ownsClient) _client.close();
  }
}
