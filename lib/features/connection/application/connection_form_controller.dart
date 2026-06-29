import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/credential_validator.dart';
import '../domain/connection_credentials.dart';
import '../domain/ha_connection_config.dart';
import '../domain/server_url.dart';
import 'connection_session_controller.dart';
import 'connection_setup_providers.dart';

/// What the connection form is doing right now, so the screen can show a
/// spinner on the submit button and a clear inline error without the widget
/// owning any of the logic.
enum ConnectionFormStatus { idle, validating, error, success }

/// Immutable snapshot of the connection form's submission state.
class ConnectionFormState {
  const ConnectionFormState({
    this.status = ConnectionFormStatus.idle,
    this.errorMessage,
  });

  final ConnectionFormStatus status;

  /// User-facing error shown after a failed validation; `null` otherwise.
  final String? errorMessage;

  bool get isSubmitting => status == ConnectionFormStatus.validating;

  ConnectionFormState copyWith({
    ConnectionFormStatus? status,
    String? errorMessage,
  }) => ConnectionFormState(
    status: status ?? this.status,
    errorMessage: errorMessage,
  );
}

/// Drives the connection screen: validates the entered URL + token against the
/// live instance and, only on success, hands them to the session controller to
/// be persisted. Invalid input is never saved — that is the whole point of the
/// validate-before-save flow.
class ConnectionFormController extends Notifier<ConnectionFormState> {
  @override
  ConnectionFormState build() => const ConnectionFormState();

  /// Validate [serverUrl] + [accessToken] end to end and, on success, save them.
  ///
  /// Returns `true` when the credentials were validated and stored, `false`
  /// otherwise (with [state] carrying the user-facing error message).
  Future<bool> submit({
    required String serverUrl,
    required String accessToken,
  }) async {
    final baseUrl = ServerUrl.tryParse(serverUrl);
    if (baseUrl == null) {
      state = const ConnectionFormState(
        status: ConnectionFormStatus.error,
        errorMessage:
            'Enter a valid server URL, e.g. https://ha.example.com or '
            '192.168.1.10:8123.',
      );
      return false;
    }

    final token = accessToken.trim();
    if (token.isEmpty) {
      state = const ConnectionFormState(
        status: ConnectionFormStatus.error,
        errorMessage: 'Enter a long-lived access token.',
      );
      return false;
    }

    state = const ConnectionFormState(status: ConnectionFormStatus.validating);

    final validator = ref.read(credentialValidatorProvider);
    final result = await validator.validate(
      HaConnectionConfig(baseUrl: baseUrl, accessToken: token),
    );

    switch (result) {
      case CredentialValidationSuccess():
        // Persist the URL exactly as the user typed it; the connection layer
        // re-normalises it via HaConnectionConfig when it reconnects.
        await ref
            .read(connectionSessionProvider.notifier)
            .save(
              ConnectionCredentials(serverUrl: serverUrl, accessToken: token),
            );
        state = const ConnectionFormState(status: ConnectionFormStatus.success);
        return true;
      case CredentialValidationFailure(:final message):
        state = ConnectionFormState(
          status: ConnectionFormStatus.error,
          errorMessage: message,
        );
        return false;
    }
  }

  /// Reset back to the pristine state (e.g. when the user edits a field after an
  /// error).
  void reset() => state = const ConnectionFormState();
}

final connectionFormControllerProvider =
    NotifierProvider<ConnectionFormController, ConnectionFormState>(
      ConnectionFormController.new,
    );
