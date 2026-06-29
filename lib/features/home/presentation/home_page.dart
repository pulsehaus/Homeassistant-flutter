import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/presentation/app_page.dart';
import '../application/counter_controller.dart';

/// Minimal home screen, now built on the shared [AppPage] template so it shares
/// the app bar / body structure (and the loading/error/empty surfaces, should
/// it later load real data) with every other feature screen.
///
/// It doubles as the worked example for the Riverpod pattern: it `watch`es
/// [counterControllerProvider] to rebuild when the value changes and `read`s
/// the notifier to dispatch an action from the button.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterControllerProvider);
    final theme = Theme.of(context);

    return AppPage(
      title: 'Home Assistant',
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            ref.read(counterControllerProvider.notifier).increment(),
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Foundation ready', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Riverpod example — counter: $count',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
