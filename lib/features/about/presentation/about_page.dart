import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../shared/presentation/app_page.dart';
import '../application/package_info_providers.dart';

/// Shows the running app's name and version — useful context for bug reports.
///
/// Built on the shared [AppPage] template via [AppPage.async], so the
/// `PackageInfo.fromPlatform()` lookup's loading/error surfaces come for free
/// while [packageInfoProvider] resolves.
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageInfo = ref.watch(packageInfoProvider);

    return AppPage.async<PackageInfo>(
      title: 'About',
      value: packageInfo,
      builder: (context, info) => _AboutBody(info: info),
    );
  }
}

class _AboutBody extends StatelessWidget {
  const _AboutBody({required this.info});

  final PackageInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final version = info.buildNumber.isEmpty
        ? info.version
        : '${info.version}+${info.buildNumber}';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              info.appName,
              key: const Key('about_app_name'),
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Version $version',
              key: const Key('about_app_version'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
