import 'package:flutter/widgets.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// Installs a [FakeOAuthWebView] platform that records `loadRequest` calls and
/// lets a test drive the navigation delegate directly (simulating the WebView
/// "deciding" to navigate somewhere, e.g. HA's redirect to the OAuth2
/// `redirect_uri`) — unlike `test/features/charts/fake_webview.dart`'s
/// render-only stub, which never invokes the callbacks it captures.
///
/// Call [setUpFakeOAuthWebView] from a test's `setUpAll`, then use
/// [FakeOAuthWebView.instance] to inspect/drive the controller under test.
void setUpFakeOAuthWebView() {
  WebViewPlatform.instance = FakeOAuthWebView.instance = FakeOAuthWebView();
}

/// Fake [WebViewPlatform] exposing the single controller/navigation delegate
/// it created, so a test can inspect [loadedUrls] and call
/// [simulateNavigation] directly.
class FakeOAuthWebView extends WebViewPlatform {
  static late FakeOAuthWebView instance;

  _FakeWebViewController? _lastController;
  _FakeNavigationDelegate? _lastNavigationDelegate;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => _lastController = _FakeWebViewController(params);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _lastNavigationDelegate = _FakeNavigationDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _FakeWebViewWidget(params);

  /// URLs passed to `loadRequest`, in order.
  List<Uri> get loadedUrls => _lastController?.loadedUrls ?? const [];

  /// Simulates the WebView's engine deciding to navigate to [url] (e.g.
  /// following HA's redirect to the OAuth2 `redirect_uri`), running it through
  /// the navigation delegate exactly as a real WebView would before actually
  /// loading it.
  Future<void> simulateNavigation(String url) async {
    final decision = await _lastNavigationDelegate?.onNavigationRequest?.call(
      NavigationRequest(url: url, isMainFrame: true),
    );
    if (decision == NavigationDecision.navigate) {
      _lastController?.loadedUrls.add(Uri.parse(url));
    }
  }
}

class _FakeWebViewController extends PlatformWebViewController {
  _FakeWebViewController(super.params) : super.implementation();

  final List<Uri> loadedUrls = [];

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<void> setOnConsoleMessage(
    void Function(JavaScriptConsoleMessage) onConsoleMessage,
  ) async {}

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    loadedUrls.add(params.uri);
  }

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {}

  @override
  Future<void> runJavaScript(String javaScript) async {}

  @override
  Future<void> clearCache() async {}

  @override
  Future<void> clearLocalStorage() async {}
}

class _FakeNavigationDelegate extends PlatformNavigationDelegate {
  _FakeNavigationDelegate(super.params) : super.implementation();

  NavigationRequestCallback? onNavigationRequest;

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async {
    this.onNavigationRequest = onNavigationRequest;
  }

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {}

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {}

  @override
  Future<void> setOnProgress(ProgressCallback onProgress) async {}

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {}
}

class _FakeWebViewWidget extends PlatformWebViewWidget {
  _FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: ValueKey('fake-oauth-webview'));
}
