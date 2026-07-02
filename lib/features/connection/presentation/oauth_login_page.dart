import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../application/oauth_login_controller.dart';

/// Drives the user through Home Assistant's hosted OAuth2 login + consent
/// page inside an embedded WebView, capturing the redirect that carries the
/// authorization code.
///
/// An embedded WebView (rather than an external browser + custom-URL-scheme
/// deep link) is used so the redirect can be intercepted entirely in-app via
/// [NavigationDelegate.onNavigationRequest] — no Android/iOS manifest changes
/// (intent filters / associated domains) are needed for a scheme that is
/// never actually registered with the OS.
///
/// Pushed with the server URL the user entered; pops `true` on a successful
/// login (caller then proceeds like a normal successful connection) or `false`
/// if the user cancels.
class OAuthLoginPage extends ConsumerStatefulWidget {
  const OAuthLoginPage({super.key, required this.serverUrl});

  final String serverUrl;

  @override
  ConsumerState<OAuthLoginPage> createState() => _OAuthLoginPageState();
}

class _OAuthLoginPageState extends ConsumerState<OAuthLoginPage> {
  late final WebViewController _webViewController;
  // Captured once so dispose() can reset the controller without touching
  // `ref` — reading a provider via `ref` from dispose() is rejected by
  // Riverpod (the element is already unmounting by then).
  late final OAuthLoginController _controllerNotifier;
  bool _handledRedirect = false;

  @override
  void initState() {
    super.initState();
    _controllerNotifier = ref.read(oauthLoginControllerProvider.notifier);
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(onNavigationRequest: _onNavigationRequest),
      );

    // Deferred to right after the first frame: calling start() (which writes
    // to oauthLoginControllerProvider's state) synchronously from initState
    // would mutate a provider while the widget tree is still building, which
    // Riverpod rejects. The `mounted` check guards against the callback
    // firing after the page was already popped/disposed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startLogin();
    });
  }

  void _startLogin() {
    final started = _controllerNotifier.start(widget.serverUrl);
    if (started) {
      final url = ref.read(oauthLoginControllerProvider).authorizeUrl;
      if (url != null) {
        unawaited(_webViewController.loadRequest(url));
      }
    }
  }

  /// Intercepts every navigation the WebView is about to make. A navigation to
  /// the app's (never-registered) redirect URI means HA finished the
  /// authorize step — extract the code and stop the WebView from actually
  /// trying to load it.
  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final code = extractAuthorizationCode(request.url);
    if (code == null) return NavigationDecision.navigate;
    if (!_handledRedirect) {
      _handledRedirect = true;
      unawaited(_completeLogin(code));
    }
    return NavigationDecision.prevent;
  }

  Future<void> _completeLogin(String code) async {
    final success = await _controllerNotifier.completeWithCode(code);
    if (!mounted) return;
    if (success) Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    // Not reset(): writing to the controller's state from this widget's own
    // dispose() would synchronously notify this now-unmounting widget as a
    // listener, which Flutter rejects. Plain resource cleanup is safe here.
    _controllerNotifier.disposeAuthClient();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(oauthLoginControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Log in to Home Assistant')),
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _webViewController),
            if (state.status == OAuthLoginStatus.exchangingCode)
              const ColoredBox(
                color: Colors.black26,
                child: Center(child: CircularProgressIndicator()),
              ),
            if (state.status == OAuthLoginStatus.error &&
                state.errorMessage != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: _ErrorBanner(
                  message: state.errorMessage!,
                  onRetry: () {
                    _handledRedirect = false;
                    _startLogin();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onErrorContainer,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
