/// Lifecycle of the WebSocket connection to Home Assistant.
enum HaConnectionStatus {
  /// Created but not started yet.
  idle,

  /// Opening the WebSocket.
  connecting,

  /// Socket open, performing the `auth` handshake.
  authenticating,

  /// Authenticated, subscribed to `state_changed` and seeded — fully ready.
  connected,

  /// Connection dropped; waiting out the backoff before the next attempt.
  reconnecting,

  /// Closed on purpose (via `disconnect`); will not reconnect.
  disconnected,

  /// Fatal, non-retryable error (e.g. invalid token). Will not reconnect.
  error,
}

/// Immutable snapshot of the connection lifecycle, exposed to the rest of the
/// app so the UI can react to connecting / connected / reconnecting / error
/// without ever touching the transport.
class HaConnectionState {
  const HaConnectionState(
    this.status, {
    this.error,
    this.reconnectAttempt = 0,
    this.retryDelay,
  });

  /// Initial state before [connect] is called.
  static const idle = HaConnectionState(HaConnectionStatus.idle);

  final HaConnectionStatus status;

  /// Last error surfaced (never thrown). Set for [HaConnectionStatus.error] and
  /// carried through [HaConnectionStatus.reconnecting].
  final Object? error;

  /// How many reconnect attempts have been scheduled since the last successful
  /// connection. Resets to 0 once [HaConnectionStatus.connected] is reached.
  final int reconnectAttempt;

  /// When [status] is [HaConnectionStatus.reconnecting], the backoff delay
  /// before the next attempt.
  final Duration? retryDelay;

  bool get isConnected => status == HaConnectionStatus.connected;

  @override
  bool operator ==(Object other) =>
      other is HaConnectionState &&
      other.status == status &&
      other.error == error &&
      other.reconnectAttempt == reconnectAttempt &&
      other.retryDelay == retryDelay;

  @override
  int get hashCode => Object.hash(status, error, reconnectAttempt, retryDelay);

  @override
  String toString() {
    final buffer = StringBuffer('HaConnectionState(${status.name}');
    if (reconnectAttempt > 0) buffer.write(', attempt: $reconnectAttempt');
    if (error != null) buffer.write(', error: $error');
    return (buffer..write(')')).toString();
  }
}
