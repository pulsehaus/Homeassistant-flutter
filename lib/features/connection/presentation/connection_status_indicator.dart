import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/connection_providers.dart';
import '../domain/connection_status.dart';
import '../domain/connection_status_visual.dart';

/// Small, unobtrusive app-bar indicator reflecting the live connection status
/// to Home Assistant (connected / reconnecting / error / …).
///
/// It watches [connectionStateProvider] directly rather than introducing a new
/// provider, so it stays clear of the scoped-dependency rule that applies to
/// *providers* touching the connection layer (see `AGENTS.md`) — a widget watch
/// is always fine. Meant to be dropped into [AppPage]'s `actions` so every
/// screen built on it shows the same indicator without duplicating the logic
/// per screen.
class ConnectionStatusIndicator extends ConsumerWidget {
  const ConnectionStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.valueOrNull` so a transient loading/error in the stream itself doesn't
    // throw — before the first status arrives, idle is a reasonable default
    // (matches HaConnectionState.idle, the client's initial value).
    final status =
        ref.watch(connectionStateProvider).valueOrNull?.status ??
        HaConnectionStatus.idle;
    final visual = ConnectionStatusVisual.forStatus(status);
    final color = visual.colorOf(Theme.of(context).colorScheme);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: visual.label,
        child: Icon(
          visual.icon,
          color: color,
          size: 20,
          semanticLabel: visual.label,
        ),
      ),
    );
  }
}
