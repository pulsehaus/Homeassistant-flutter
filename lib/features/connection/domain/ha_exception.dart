/// Errors surfaced by the Home Assistant communication layer.
///
/// Sealed so callers (and tests) can exhaustively switch on the failure kind.
/// These are *surfaced* through the connection state or returned futures rather
/// than allowed to crash the app.
sealed class HaException implements Exception {
  const HaException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The access token was rejected (`auth_invalid` / HTTP 401-403). Not
/// retryable — reconnecting with the same token would fail again.
class HaAuthException extends HaException {
  const HaAuthException(super.message);
}

/// The transport failed: the socket could not be opened, dropped, or closed
/// unexpectedly. Retryable — the client reconnects with backoff.
class HaConnectionException extends HaException {
  const HaConnectionException(super.message, {this.cause});

  final Object? cause;
}

/// A WebSocket command returned `success: false`.
class HaCommandException extends HaException {
  const HaCommandException(super.message, {this.code});

  /// HA error code, e.g. `not_found`, `invalid_format`.
  final String? code;
}

/// A REST request returned a non-success status code.
class HaRestException extends HaException {
  const HaRestException(super.message, {this.statusCode});

  final int? statusCode;
}
