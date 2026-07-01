import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Exposes the running app's [PackageInfo] (name, version, build number, …)
/// read from the platform via `package_info_plus`.
///
/// This is plain platform metadata — unrelated to the Home Assistant
/// connection graph — so, unlike the connection providers, it does not need
/// scoped `dependencies`.
///
/// Tests stub the platform channel with
/// `PackageInfo.setMockInitialValues(...)` (see the plugin's own test
/// support) rather than overriding this provider, so widgets that read it
/// work the same way in tests and at runtime.
final packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});
