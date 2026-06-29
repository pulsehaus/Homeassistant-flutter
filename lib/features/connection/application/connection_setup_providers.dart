import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/credential_store.dart';
import '../data/credential_validator.dart';

/// The secure credential store. Overridden in tests with a fake so no real
/// platform keychain is touched.
final credentialStoreProvider = Provider<CredentialStore>(
  (ref) => SecureCredentialStore(),
);

/// Validates candidate credentials by performing the real WebSocket `auth`
/// handshake. Overridden in tests with a fake socket connector so the flow runs
/// without a network.
final credentialValidatorProvider = Provider<CredentialValidator>(
  (ref) => WebSocketCredentialValidator(),
);
