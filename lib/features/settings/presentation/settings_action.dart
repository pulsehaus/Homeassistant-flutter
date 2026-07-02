import 'package:flutter/material.dart';

import 'settings_page.dart';

/// App-bar action that opens the [SettingsPage].
///
/// A plain [StatelessWidget] (not a [ConsumerWidget]) since it only pushes a
/// route — it reads no Riverpod state itself, mirroring [AboutAction]'s shape.
class SettingsAction extends StatelessWidget {
  const SettingsAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('settings_action'),
      tooltip: 'Settings',
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (context) => const SettingsPage()),
      ),
    );
  }
}
