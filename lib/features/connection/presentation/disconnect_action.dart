import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/connection_session_controller.dart';

/// App-bar action that lets the user disconnect from the current instance and
/// switch to a different one.
///
/// It clears the stored credentials via [ConnectionSessionController.clear],
/// which flips the session back to "unconfigured" and so returns the app to the
/// connection screen. A confirmation dialog guards the (destructive) clear.
class DisconnectAction extends ConsumerWidget {
  const DisconnectAction({super.key});

  Future<void> _confirmAndDisconnect(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect?'),
        content: const Text(
          'This removes the saved server URL and access token from this '
          'device. You will need to enter them again to reconnect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await ref.read(connectionSessionProvider.notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      key: const Key('disconnect_action'),
      tooltip: 'Disconnect / change instance',
      icon: const Icon(Icons.logout),
      onPressed: () => _confirmAndDisconnect(context, ref),
    );
  }
}
