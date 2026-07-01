import 'package:flutter/material.dart';

import 'about_page.dart';

/// App-bar action that opens the [AboutPage].
///
/// A plain [StatelessWidget] (not a [ConsumerWidget]) since it only pushes a
/// route — it reads no Riverpod state itself.
class AboutAction extends StatelessWidget {
  const AboutAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('about_action'),
      tooltip: 'About',
      icon: const Icon(Icons.info_outline),
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (context) => const AboutPage())),
    );
  }
}
