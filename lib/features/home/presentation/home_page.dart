import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../charts/presentation/chart_example_page.dart';
import '../application/counter_controller.dart';

/// Minimal home screen acting as the app shell placeholder until real
/// features (connection, dashboards) are built.
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

    return Scaffold(
      appBar: AppBar(title: const Text('Home Assistant')),
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
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ChartExamplePage(),
                ),
              ),
              icon: const Icon(Icons.insights),
              label: const Text('Charts example'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            ref.read(counterControllerProvider.notifier).increment(),
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
