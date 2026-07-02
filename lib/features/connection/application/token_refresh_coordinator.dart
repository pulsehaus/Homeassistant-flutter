import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ha_auth_client.dart';
import '../data/ha_rest_client.dart';
import '../data/ha_websocket_client.dart';
import '../domain/connection_credentials.dart';
import '../domain/ha_exception.dart';
import 'connection_providers.dart';
import 'connection_session_controller.dart';

/// Keeps an OAuth2 session's access token fresh so the user is never forced
/// back through the login flow while their refresh token is still valid.
///
/// Home Assistant's OAuth2 access tokens are short-lived (30 minutes by
/// default) and carry an `expires_in`. This coordinator refreshes
/// **proactively**: it schedules the next refresh a margin before the current
/// token's expiry, rather than waiting for a 401/`auth_invalid` to react to.
/// That is simpler to reason about here (one timer, no need to distinguish
/// "expired token" from "other auth failure" on every REST/WS error path) and
/// avoids a window where in-flight requests fail before a reactive refresh
/// would kick in.
///
/// A refreshed token is pushed to the live [HaWebSocketClient] and
/// [HaRestClient] via their mutable `updateAccessToken`, and persisted through
/// [ConnectionSessionController.save] so it survives an app restart —
/// `HaConnectionConfig` itself stays immutable and the provider scope is never
/// torn down for a routine refresh.
///
/// No-ops entirely for the manual long-lived-token path
/// ([ConnectionCredentials.canRefresh] is false): there is nothing to refresh.
class TokenRefreshCoordinator {
  TokenRefreshCoordinator({
    required this.authClient,
    required this.webSocketClient,
    required this.restClient,
    required this.saveCredentials,
    this.refreshMargin = const Duration(minutes: 5),
  });

  final HaAuthClient authClient;
  final HaWebSocketClient webSocketClient;
  final HaRestClient restClient;

  /// Persists refreshed credentials (wired to
  /// `ConnectionSessionController.save`).
  final Future<void> Function(ConnectionCredentials credentials)
  saveCredentials;

  /// How long before the access token's reported expiry to refresh it, so a
  /// request in flight around the expiry boundary doesn't race a still-valid
  /// token being rejected.
  final Duration refreshMargin;

  Timer? _timer;
  bool _disposed = false;

  /// Start the refresh cycle for [credentials]. No-op if
  /// `credentials.canRefresh` is false. Since a freshly loaded session has no
  /// known expiry (only the token itself is persisted, not when it expires),
  /// this always performs one refresh immediately to establish a known expiry,
  /// then schedules subsequent refreshes from each response's `expires_in`.
  void start(ConnectionCredentials credentials) {
    final refreshToken = credentials.refreshToken;
    if (refreshToken == null) return;
    unawaited(_refresh(refreshToken));
  }

  Future<void> _refresh(String refreshToken) async {
    if (_disposed) return;
    try {
      final response = await authClient.refresh(refreshToken);
      if (_disposed) return;
      webSocketClient.updateAccessToken(response.accessToken);
      restClient.updateAccessToken(response.accessToken);
      await saveCredentials(
        ConnectionCredentials(
          serverUrl: _currentServerUrl,
          accessToken: response.accessToken,
          refreshToken: response.refreshToken,
        ),
      );
      _scheduleNext(response.refreshToken, response.expiresIn);
    } on HaAuthException {
      // The refresh token itself was rejected (revoked/expired) — nothing more
      // this coordinator can do without the user; the next REST/WS auth
      // failure will surface the need to log in again.
    } on HaException {
      // Transport/server hiccup: try again after the usual margin rather than
      // spinning immediately.
      _scheduleNext(refreshToken, refreshMargin);
    }
  }

  // Re-read on every successful refresh from the WS client's immutable config
  // so the persisted record keeps the right server URL without this
  // coordinator needing its own copy.
  String get _currentServerUrl => webSocketClient.config.baseUrl.toString();

  void _scheduleNext(String refreshToken, Duration expiresIn) {
    if (_disposed) return;
    _timer?.cancel();
    final delay = expiresIn - refreshMargin;
    _timer = Timer(
      delay.isNegative ? Duration.zero : delay,
      () => unawaited(_refresh(refreshToken)),
    );
  }

  /// Stop the refresh cycle. Safe to call multiple times.
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}

/// The HTTP client for the OAuth2 authorize/token endpoints, scoped to the
/// active instance's base URL.
final haAuthClientProvider = Provider<HaAuthClient>((ref) {
  final client = HaAuthClient(
    baseUrl: ref.watch(haWebSocketClientProvider).config.baseUrl,
  );
  ref.onDispose(client.close);
  return client;
}, dependencies: [haWebSocketClientProvider]);

/// Drives proactive OAuth2 access-token refresh for the active session. Reads
/// the connection-scoped WS/REST clients (so it must declare them as
/// dependencies per the Riverpod scoped-dependencies rule) and the root-scoped
/// [connectionSessionProvider] to persist refreshed tokens.
///
/// Created eagerly by [autoDispose]-less `Provider` so it starts as soon as
/// the connected scope is built; disposed (cancelling its timer) when the
/// scope is torn down (e.g. on disconnect).
final tokenRefreshCoordinatorProvider = Provider<TokenRefreshCoordinator>(
  (ref) {
    final coordinator = TokenRefreshCoordinator(
      authClient: ref.watch(haAuthClientProvider),
      webSocketClient: ref.watch(haWebSocketClientProvider),
      restClient: ref.watch(haRestClientProvider),
      saveCredentials: (credentials) =>
          ref.read(connectionSessionProvider.notifier).save(credentials),
    );
    ref.onDispose(coordinator.dispose);

    final credentials = ref.read(connectionSessionProvider).value;
    if (credentials != null) coordinator.start(credentials);

    return coordinator;
  },
  dependencies: [
    haAuthClientProvider,
    haWebSocketClientProvider,
    haRestClientProvider,
  ],
);
