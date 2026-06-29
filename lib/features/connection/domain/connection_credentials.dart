/// The raw credentials a user enters on the connection screen: the instance
/// server URL and a long-lived access token.
///
/// A plain value object with no UI or storage dependency so it can be parsed,
/// validated, persisted and unit-tested in isolation. Convert it to the
/// connection layer's [HaConnectionConfig] via [toConfig] once the [serverUrl]
/// has been validated.
class ConnectionCredentials {
  const ConnectionCredentials({
    required this.serverUrl,
    required this.accessToken,
  });

  /// The instance URL exactly as the user typed it, e.g.
  /// `https://ha.example.com` or `192.168.1.10:8123`.
  final String serverUrl;

  /// The long-lived access token from HA Profile → Security.
  final String accessToken;

  @override
  bool operator ==(Object other) =>
      other is ConnectionCredentials &&
      other.serverUrl == serverUrl &&
      other.accessToken == accessToken;

  @override
  int get hashCode => Object.hash(serverUrl, accessToken);

  @override
  String toString() => 'ConnectionCredentials(serverUrl: $serverUrl)';
}
