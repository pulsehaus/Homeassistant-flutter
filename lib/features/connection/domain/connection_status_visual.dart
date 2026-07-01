import 'package:flutter/material.dart';

import 'connection_status.dart';

/// What the app-bar connection indicator should show for a given
/// [HaConnectionStatus]: which icon, and which [ColorScheme] role to colour it
/// with.
///
/// Pure presentation logic (no Flutter widgets, no transport) so the mapping is
/// unit-testable on its own — the widget only reads [ConnectionStatusVisual]
/// and paints it, mirroring how [ConnectionBannerMessage] keeps the banner's
/// "what to show" decision out of the widget layer.
@immutable
class ConnectionStatusVisual {
  const ConnectionStatusVisual({
    required this.icon,
    required this.label,
    required this.colorOf,
  });

  /// Icon representing this status.
  final IconData icon;

  /// Human-readable label, used as the tooltip / semantics text.
  final String label;

  /// Resolves the icon colour from the current [ColorScheme] so nothing is
  /// hard-coded — callers pass `Theme.of(context).colorScheme`.
  final Color Function(ColorScheme colors) colorOf;

  /// The visual for [status].
  ///
  /// - [HaConnectionStatus.connected] reads as healthy (theme primary).
  /// - [HaConnectionStatus.reconnecting] reads as a transient warning (theme
  ///   tertiary), distinct from both connected and error.
  /// - [HaConnectionStatus.error] reads as a fatal problem (theme error).
  /// - The quiet start-up phases ([idle] / [connecting] / [authenticating])
  ///   and a deliberate [disconnected] use a muted, neutral tone so the
  ///   indicator doesn't draw attention before there's anything to report.
  static ConnectionStatusVisual forStatus(HaConnectionStatus status) {
    switch (status) {
      case HaConnectionStatus.connected:
        return ConnectionStatusVisual(
          icon: Icons.cloud_done_outlined,
          label: 'Connected to Home Assistant',
          colorOf: (colors) => colors.primary,
        );
      case HaConnectionStatus.reconnecting:
        return ConnectionStatusVisual(
          icon: Icons.cloud_sync_outlined,
          label: 'Reconnecting to Home Assistant…',
          colorOf: (colors) => colors.tertiary,
        );
      case HaConnectionStatus.error:
        return ConnectionStatusVisual(
          icon: Icons.cloud_off_outlined,
          label: "Can't reach Home Assistant",
          colorOf: (colors) => colors.error,
        );
      case HaConnectionStatus.idle:
      case HaConnectionStatus.connecting:
      case HaConnectionStatus.authenticating:
        return ConnectionStatusVisual(
          icon: Icons.cloud_queue_outlined,
          label: 'Connecting to Home Assistant…',
          colorOf: (colors) => colors.onSurfaceVariant,
        );
      case HaConnectionStatus.disconnected:
        return ConnectionStatusVisual(
          icon: Icons.cloud_outlined,
          label: 'Disconnected from Home Assistant',
          colorOf: (colors) => colors.onSurfaceVariant,
        );
    }
  }
}
