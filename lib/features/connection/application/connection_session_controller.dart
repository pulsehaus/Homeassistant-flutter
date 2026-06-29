import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/credential_store.dart';
import '../domain/connection_credentials.dart';
import 'connection_setup_providers.dart';

/// Owns the app-level "are we connected to an instance?" state.
///
/// On startup it loads any credentials from secure storage; the value it holds
/// is `null` when no instance is configured (show the connection screen) and a
/// [ConnectionCredentials] once one is (route to the app shell). The connection
/// form calls [save] after a successful validation, and the disconnect /
/// change-instance path calls [clear].
///
/// This is the single source of truth the app root watches to decide which
/// screen to show and to override `haConnectionConfigProvider`.
class ConnectionSessionController
    extends AsyncNotifier<ConnectionCredentials?> {
  CredentialStore get _store => ref.read(credentialStoreProvider);

  @override
  Future<ConnectionCredentials?> build() => _store.read();

  /// Persist already-validated [credentials] and make them the active session.
  Future<void> save(ConnectionCredentials credentials) async {
    await _store.write(credentials);
    state = AsyncData(credentials);
  }

  /// Clear stored credentials and return to the unconfigured state — the
  /// disconnect / change-instance path.
  Future<void> clear() async {
    await _store.clear();
    state = const AsyncData(null);
  }
}

/// Exposes the active connection session. The app root watches this to choose
/// between the connection screen and the app shell.
final connectionSessionProvider =
    AsyncNotifierProvider<ConnectionSessionController, ConnectionCredentials?>(
      ConnectionSessionController.new,
    );
