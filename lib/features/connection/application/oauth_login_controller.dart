import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ha_auth_client.dart';
import '../domain/connection_credentials.dart';
import '../domain/ha_exception.dart';
import '../domain/oauth_client_config.dart';
import '../domain/server_url.dart';
import 'connection_session_controller.dart';
import 'connection_setup_providers.dart';

/// What the OAuth2 login flow is doing right now, mirroring
/// [ConnectionFormController]'s status/state split so the login page can show
/// the same kind of spinner/error UI without owning any of the logic.
enum OAuthLoginStatus { idle, authorizing, exchangingCode, error, success }

/// Immutable snapshot of the OAuth2 login flow's state.
class OAuthLoginState {
  const OAuthLoginState({
    this.status = OAuthLoginStatus.idle,
    this.authorizeUrl,
    this.errorMessage,
  });

  final OAuthLoginStatus status;

  /// The `/auth/authorize` URL the WebView should load once
  /// [OAuthLoginStatus.authorizing] is reached.
  final Uri? authorizeUrl;

  /// User-facing error after a failed code/refresh exchange; `null` otherwise.
  final String? errorMessage;

  bool get isBusy =>
      status == OAuthLoginStatus.authorizing ||
      status == OAuthLoginStatus.exchangingCode;

  OAuthLoginState copyWith({
    OAuthLoginStatus? status,
    Uri? authorizeUrl,
    String? errorMessage,
  }) => OAuthLoginState(
    status: status ?? this.status,
    authorizeUrl: authorizeUrl ?? this.authorizeUrl,
    errorMessage: errorMessage,
  );
}

/// Drives the OAuth2 "Log in" screen: builds the authorize URL for a given
/// server, and exchanges the authorization code captured from the WebView
/// redirect for an access + refresh token pair, saving them via
/// [ConnectionSessionController] on success — mirroring
/// [ConnectionFormController]'s validate-then-save shape for the manual path.
class OAuthLoginController extends Notifier<OAuthLoginState> {
  @override
  OAuthLoginState build() => const OAuthLoginState();

  /// Start the flow for the instance at [serverUrl]: validates the URL and, if
  /// valid, moves to [OAuthLoginStatus.authorizing] with the authorize URL the
  /// login page's WebView should load.
  ///
  /// Returns `true` on a valid URL, `false` otherwise (with [state] carrying
  /// the user-facing error).
  bool start(String serverUrl) {
    final baseUrl = ServerUrl.tryParse(serverUrl);
    if (baseUrl == null) {
      state = const OAuthLoginState(
        status: OAuthLoginStatus.error,
        errorMessage:
            'Enter a valid server URL, e.g. https://ha.example.com or '
            '192.168.1.10:8123.',
      );
      return false;
    }

    _serverUrl = serverUrl;
    _authClient = ref.read(haAuthClientFactoryProvider)(baseUrl);
    state = OAuthLoginState(
      status: OAuthLoginStatus.authorizing,
      authorizeUrl: _authClient!.authorizeUrl(),
    );
    return true;
  }

  String? _serverUrl;
  HaAuthClient? _authClient;

  /// Called once the login page's WebView intercepts a navigation to
  /// [OAuthClientConfig.redirectUri] carrying an authorization `code`.
  /// Exchanges it for tokens and, on success, persists the session.
  ///
  /// Returns `true` on success so the page can pop back to the app; `false`
  /// on failure (with [state] carrying the user-facing error, so the WebView
  /// can stay open for a retry).
  Future<bool> completeWithCode(String code) async {
    final authClient = _authClient;
    final serverUrl = _serverUrl;
    if (authClient == null || serverUrl == null) {
      state = const OAuthLoginState(
        status: OAuthLoginStatus.error,
        errorMessage: 'Login flow was not started correctly. Please retry.',
      );
      return false;
    }

    state = state.copyWith(status: OAuthLoginStatus.exchangingCode);
    try {
      final tokens = await authClient.exchangeCode(code);
      await ref
          .read(connectionSessionProvider.notifier)
          .save(
            ConnectionCredentials(
              serverUrl: serverUrl,
              accessToken: tokens.accessToken,
              refreshToken: tokens.refreshToken,
            ),
          );
      state = state.copyWith(status: OAuthLoginStatus.success);
      return true;
    } on HaException catch (error) {
      state = state.copyWith(
        status: OAuthLoginStatus.error,
        errorMessage: error.message,
      );
      return false;
    } finally {
      authClient.close();
    }
  }

  /// Releases the in-flight [HaAuthClient] without touching [state].
  ///
  /// Used from the login page's `dispose()`: writing to a `Notifier`'s state
  /// synchronously notifies listeners, and the page itself is one of them —
  /// doing that mid-unmount trips a Flutter assertion (`markNeedsBuild` on an
  /// already-defunct element). Plain resource cleanup has no such restriction.
  void disposeAuthClient() {
    _authClient?.close();
    _authClient = null;
    _serverUrl = null;
  }

  /// Reset back to the pristine state. Safe to call while the page watching
  /// this controller is still mounted (e.g. a future "start over" action) —
  /// unlike [disposeAuthClient], not safe to call from that page's own
  /// `dispose()`.
  void reset() {
    disposeAuthClient();
    state = const OAuthLoginState();
  }
}

final oauthLoginControllerProvider =
    NotifierProvider<OAuthLoginController, OAuthLoginState>(
      OAuthLoginController.new,
    );

/// Parses the authorization `code` out of a navigation request URL, or `null`
/// if [url] isn't a redirect to [OAuthClientConfig.redirectUri] carrying one
/// (including an error redirect, e.g. `?error=access_denied`).
String? extractAuthorizationCode(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  if (!url.startsWith(OAuthClientConfig.redirectUri)) return null;
  return uri.queryParameters['code'];
}
