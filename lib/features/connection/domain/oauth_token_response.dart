/// The token pair Home Assistant's `/auth/token` endpoint returns from either
/// an authorization-code exchange or a refresh-token exchange.
///
/// A plain value object (no HTTP/JSON dependency baked in beyond [fromJson])
/// so it can be constructed directly in tests. Reference:
/// https://developers.home-assistant.io/docs/auth_api/#token
class OAuthTokenResponse {
  const OAuthTokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  /// Short-lived access token, used the same way as a long-lived token for the
  /// WebSocket `auth` handshake and the REST `Authorization: Bearer` header.
  final String accessToken;

  /// Long-lived refresh token used to mint a new [accessToken] via a
  /// `grant_type=refresh_token` request, without involving the user again.
  ///
  /// Home Assistant only returns a refresh token on the *initial*
  /// authorization-code exchange, not on subsequent refreshes — callers must
  /// keep reusing the one from the original login.
  final String refreshToken;

  /// How long [accessToken] is valid for, from the moment this response was
  /// received.
  final Duration expiresIn;

  /// Parses a `/auth/token` JSON response body.
  ///
  /// [fallbackRefreshToken] is used when the response has no `refresh_token`
  /// field — the case for a refresh-token exchange, where HA does not reissue
  /// one and the caller must keep reusing the refresh token it already has.
  factory OAuthTokenResponse.fromJson(
    Map<String, dynamic> json, {
    String? fallbackRefreshToken,
  }) {
    final refreshToken =
        json['refresh_token'] as String? ?? fallbackRefreshToken;
    if (refreshToken == null) {
      throw const FormatException(
        'Token response had no refresh_token and no fallback was supplied',
      );
    }
    return OAuthTokenResponse(
      accessToken: json['access_token'] as String,
      refreshToken: refreshToken,
      expiresIn: Duration(seconds: json['expires_in'] as int? ?? 1800),
    );
  }

  @override
  String toString() => 'OAuthTokenResponse(expiresIn: $expiresIn)';
}
