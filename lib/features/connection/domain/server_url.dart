/// Parses and normalises the server URL a user types on the connection screen
/// into a base [Uri] suitable for [HaConnectionConfig].
///
/// Home Assistant users commonly paste an address without a scheme
/// (`192.168.1.10:8123`) or with a trailing path/slash. This normaliser is the
/// single place that turns that free-form input into a well-formed
/// `scheme://host[:port]` URL, so both the form and the credential store agree
/// on what "valid" means. Pure Dart with no Flutter dependency so it is
/// unit-testable in isolation.
abstract final class ServerUrl {
  /// Normalise [input] into an `http`/`https` base [Uri], or return `null` when
  /// it cannot be a valid Home Assistant address.
  ///
  /// Rules:
  /// - blank input is rejected;
  /// - a missing scheme defaults to `http://` (HA is often reached over a plain
  ///   LAN address);
  /// - only `http`/`https` schemes are accepted;
  /// - a host is required;
  /// - any path, query or fragment is dropped — only scheme/host/port are kept.
  static Uri? tryParse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final withScheme = trimmed.contains('://') ? trimmed : 'http://$trimmed';

    final parsed = Uri.tryParse(withScheme);
    if (parsed == null) return null;
    if (parsed.scheme != 'http' && parsed.scheme != 'https') return null;
    if (parsed.host.isEmpty) return null;
    // A host may not contain whitespace; `Uri` would otherwise percent-encode a
    // typo like "not a url" into a "valid" host. Reject it.
    if (RegExp(r'\s|%20').hasMatch(parsed.host)) return null;

    return Uri(
      scheme: parsed.scheme,
      host: parsed.host,
      port: parsed.hasPort ? parsed.port : null,
    );
  }

  /// Whether [input] normalises to a valid base URL.
  static bool isValid(String input) => tryParse(input) != null;
}
