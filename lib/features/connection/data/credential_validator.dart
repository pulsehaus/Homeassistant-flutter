import 'dart:async';

import '../domain/connection_status.dart';
import '../domain/ha_connection_config.dart';
import '../domain/ha_exception.dart';
import 'ha_socket.dart';
import 'ha_websocket_client.dart';

/// Outcome of validating a set of credentials against a live instance.
sealed class CredentialValidationResult {
  const CredentialValidationResult();
}

/// The WebSocket `auth` handshake succeeded — the credentials are good.
class CredentialValidationSuccess extends CredentialValidationResult {
  const CredentialValidationSuccess();
}

/// The handshake failed. [message] is a user-facing explanation and [isAuth]
/// distinguishes a rejected token from a transport/connection problem.
class CredentialValidationFailure extends CredentialValidationResult {
  const CredentialValidationFailure(this.message, {required this.isAuth});

  final String message;
  final bool isAuth;
}

/// Validates a set of Home Assistant credentials against a live instance.
///
/// Abstracted so the connection form depends on the behaviour, not the
/// WebSocket implementation, and tests can stub the result without driving a
/// socket. The production implementation is [WebSocketCredentialValidator].
abstract interface class CredentialValidator {
  Future<CredentialValidationResult> validate(HaConnectionConfig config);
}

/// Validates credentials by performing the real WebSocket `auth` handshake
/// before they are ever persisted.
///
/// It spins up a throwaway [HaWebSocketClient] for the candidate config, drives
/// [HaWebSocketClient.connect], and watches the connection lifecycle: a
/// [HaConnectionStatus.connected] is a pass, while a [HaConnectionStatus.error]
/// (an `auth_invalid`) is a hard auth failure. A transport problem surfaces as a
/// [HaConnectionStatus.reconnecting] retry loop, which would otherwise spin
/// forever, so the validator bounds it with a [timeout] and reports a
/// connection failure. The client is always disposed afterwards.
///
/// The [HaSocketConnector] is injected so unit tests can drive the whole flow
/// with a fake socket — no real network.
class WebSocketCredentialValidator implements CredentialValidator {
  WebSocketCredentialValidator({
    HaSocketConnector connector = connectHaWebSocket,
    this.timeout = const Duration(seconds: 15),
  }) : _connector = connector;

  final HaSocketConnector _connector;

  /// How long to wait for a `connected` state before giving up. Bounds the
  /// reconnect loop a transport failure would otherwise trigger.
  final Duration timeout;

  @override
  Future<CredentialValidationResult> validate(HaConnectionConfig config) async {
    final client = HaWebSocketClient(config: config, connector: _connector);
    final completer = Completer<CredentialValidationResult>();
    StreamSubscription<HaConnectionState>? sub;

    void finish(CredentialValidationResult result) {
      if (!completer.isCompleted) completer.complete(result);
    }

    sub = client.connectionStates.listen((state) {
      switch (state.status) {
        case HaConnectionStatus.connected:
          finish(const CredentialValidationSuccess());
        case HaConnectionStatus.error:
          finish(
            CredentialValidationFailure(
              _describe(state.error),
              isAuth: state.error is HaAuthException,
            ),
          );
        case HaConnectionStatus.idle:
        case HaConnectionStatus.connecting:
        case HaConnectionStatus.authenticating:
        case HaConnectionStatus.reconnecting:
        case HaConnectionStatus.disconnected:
          break;
      }
    });

    try {
      await client.connect();
      return await completer.future.timeout(
        timeout,
        onTimeout: () => const CredentialValidationFailure(
          'Could not reach the server in time. Check the URL and that the '
          'instance is reachable.',
          isAuth: false,
        ),
      );
    } finally {
      await sub.cancel();
      await client.dispose();
    }
  }

  String _describe(Object? error) {
    if (error is HaException) return error.message;
    if (error == null) return 'Connection failed.';
    return '$error';
  }
}
