import 'package:package_info_plus/package_info_plus.dart';

/// Stubs `PackageInfo.fromPlatform()` with deterministic values so widgets
/// that read [packageInfoProvider] (in `lib/features/about`) can be pumped in
/// `flutter_test` without a real platform channel.
///
/// `package_info_plus` ships this exact hook for tests
/// (`PackageInfo.setMockInitialValues`), so — unlike the WebView stubbing in
/// `test/features/charts/fake_webview.dart`, which had to hand-roll a fake
/// platform implementation — there is no custom fake to write here.
///
/// Call [setUpFakePackageInfo] from a test's `setUpAll`.
void setUpFakePackageInfo({
  String appName = 'Home Assistant Flutter',
  String version = '1.0.0',
  String buildNumber = '1',
}) {
  PackageInfo.setMockInitialValues(
    appName: appName,
    packageName: 'com.example.homeassistant_flutter',
    version: version,
    buildNumber: buildNumber,
    buildSignature: '',
  );
}
