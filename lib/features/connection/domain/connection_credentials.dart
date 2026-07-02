/// The raw credentials a user connects with: the instance server URL and an
/// access token, either a long-lived token pasted by hand or the access token
/// half of an OAuth2 authorization-code grant.
///
/// A plain value object with no UI or storage dependency so it can be parsed,
/// validated, persisted and unit-tested in isolation. Convert it to the
/// connection layer's [HaConnectionConfig] via [toConfig] once the [serverUrl]
/// has been validated.
class ConnectionCredentials {
  const ConnectionCredentials({
    required this.serverUrl,
    required this.accessToken,
    this.refreshToken,
  });

  /// The instance URL exactly as the user typed it, e.g.
  /// `https://ha.example.com` or `192.168.1.10:8123`.
  final String serverUrl;

  /// The access token used for the WebSocket `auth` handshake and the REST
  /// `Authorization: Bearer` header. Either a long-lived token from HA
  /// Profile → Security, or the short-lived access token returned by the
  /// OAuth2 login flow.
  final String accessToken;

  /// The OAuth2 refresh token, present only when [accessToken] came from the
  /// OAuth2 login flow. `null` for the manual long-lived-token path, which has
  /// no refresh token — the token simply doesn't expire.
  final String? refreshToken;

  /// Whether [accessToken] can be refreshed without a full re-login.
  bool get canRefresh => refreshToken != null;

  ConnectionCredentials copyWith({String? accessToken, String? refreshToken}) =>
      ConnectionCredentials(
        serverUrl: serverUrl,
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken ?? this.refreshToken,
      );

  @override
  bool operator ==(Object other) =>
      other is ConnectionCredentials &&
      other.serverUrl == serverUrl &&
      other.accessToken == accessToken &&
      other.refreshToken == refreshToken;

  @override
  int get hashCode => Object.hash(serverUrl, accessToken, refreshToken);

  @override
  String toString() => 'ConnectionCredentials(serverUrl: $serverUrl)';
}
