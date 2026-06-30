import 'connection_status.dart';

/// What the connection banner should display for a given [HaConnectionState].
///
/// Pure presentation logic, kept here (no Flutter, no transport) so the
/// "which message / show retry? for which status" decision is unit-testable in
/// isolation from the widget. The banner widget reads this and renders it with
/// themed colours.
class ConnectionBannerMessage {
  const ConnectionBannerMessage({required this.title, this.showRetry = true});

  /// Short, user-facing line describing the current connection problem.
  final String title;

  /// Whether to offer a manual "Retry" action. Always true today, but kept
  /// explicit so a future non-retryable surface can opt out.
  final bool showRetry;

  /// The banner to show for [state], or `null` when nothing should be shown
  /// (i.e. the connection is healthy or in a transient, non-alarming phase).
  ///
  /// We only surface the banner once the connection is in trouble:
  /// - [HaConnectionStatus.reconnecting] — the socket dropped and we are
  ///   backing off before retrying;
  /// - [HaConnectionStatus.error] — a fatal, non-retryable failure.
  ///
  /// Healthy states ([connected]) and the quiet start-up phases
  /// ([idle]/[connecting]/[authenticating]) — plus a deliberate
  /// [disconnected] — show nothing, so the banner stays unobtrusive.
  static ConnectionBannerMessage? forState(HaConnectionState state) {
    switch (state.status) {
      case HaConnectionStatus.reconnecting:
        return const ConnectionBannerMessage(
          title: 'Connection lost. Reconnecting…',
        );
      case HaConnectionStatus.error:
        return const ConnectionBannerMessage(
          title: "Can't reach Home Assistant.",
        );
      case HaConnectionStatus.idle:
      case HaConnectionStatus.connecting:
      case HaConnectionStatus.authenticating:
      case HaConnectionStatus.connected:
      case HaConnectionStatus.disconnected:
        return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ConnectionBannerMessage &&
      other.title == title &&
      other.showRetry == showRetry;

  @override
  int get hashCode => Object.hash(title, showRetry);
}
