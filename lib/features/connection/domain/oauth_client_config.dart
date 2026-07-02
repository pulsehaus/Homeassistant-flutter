/// The OAuth2 client identity this app presents to a Home Assistant instance.
///
/// Home Assistant's authorization server does not require pre-registered
/// clients: any `client_id` is accepted as long as it resolves to a same-origin
/// (or otherwise trusted) page, and it is shown to the user on the consent
/// screen as "this app wants to access your instance". We use a URL-shaped
/// `client_id` (Home Assistant's own convention — the official mobile app does
/// the same) and a matching custom-scheme `redirectUri` that the embedded
/// WebView intercepts before it ever leaves the app; no scheme is registered
/// with the OS, so the flow doesn't require any Android/iOS manifest changes.
///
/// Reference: https://developers.home-assistant.io/docs/auth_api/#authorization-code
abstract final class OAuthClientConfig {
  /// Shown on HA's consent screen. Not a real reachable URL — Home Assistant
  /// only checks that it's a well-formed URI, it never dereferences it.
  static const clientId = 'https://home-assistant-flutter.app';

  /// Custom-scheme redirect the WebView's `NavigationDelegate` intercepts.
  /// Never actually loaded (no such scheme is registered with the OS or the
  /// WebView), so the app never needs a deep-link / app-link registration —
  /// the WebView simply sees the navigation *request* and cancels it.
  static const redirectUri = 'homeassistant-flutter://auth-callback';
}
