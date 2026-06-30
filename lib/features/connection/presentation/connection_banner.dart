import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/connection_providers.dart';
import '../domain/connection_banner_message.dart';

/// A slim, app-wide bar that appears when the connection to Home Assistant is in
/// trouble (reconnecting or a fatal error) and offers a manual **Retry**.
///
/// It watches [connectionStateProvider] directly and renders nothing while the
/// connection is healthy or in a quiet start-up phase, so it stays out of the
/// way until there's something worth telling the user (see
/// [ConnectionBannerMessage.forState]). Colours come from the theme's error
/// container so it reads as a warning without being a hard-coded red.
///
/// Reading the provider rather than introducing a new one keeps it clear of the
/// scoped-dependency rule that applies to *providers* touching the connection
/// layer — a widget watch is always fine.
class ConnectionBanner extends ConsumerWidget {
  const ConnectionBanner({super.key});

  void _retry(WidgetRef ref) {
    // Kicks the client to (re)open the socket immediately instead of waiting
    // out the backoff. Fire-and-forget: progress is surfaced back through
    // connectionStateProvider, which this banner already watches.
    ref.read(haWebSocketClientProvider).connect();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.valueOrNull` so a transient loading/error in the stream itself doesn't
    // throw — we only care about the connection status it carries.
    final state = ref.watch(connectionStateProvider).valueOrNull;
    final message = state == null
        ? null
        : ConnectionBannerMessage.forState(state);

    // AnimatedSize gives an unobtrusive slide in/out as the banner appears and
    // disappears, and collapses to zero height when there's nothing to show.
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : _Banner(message: message, onRetry: () => _retry(ref)),
    );
  }
}

/// The visible bar. Split out so the [ConsumerWidget] above stays purely about
/// wiring state to props.
class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.onRetry});

  final ConnectionBannerMessage message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 20,
                color: colors.onErrorContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onErrorContainer,
                  ),
                ),
              ),
              if (message.showRetry) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.onErrorContainer,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
