import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/credential_store.dart';
import '../data/credential_validator.dart';
import '../data/ha_auth_client.dart';

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

/// Builds the [HaAuthClient] the OAuth2 login flow talks to, given the
/// instance's base URL. A factory rather than a single instance because the
/// base URL is only known once the user enters a server address on the
/// connection screen — [OAuthLoginController.start] calls this with the
/// validated URL. Overridden in tests with a factory backed by a mock
/// [http.Client] so the flow runs without a network.
final haAuthClientFactoryProvider = Provider<HaAuthClient Function(Uri)>(
  (ref) =>
      (baseUrl) => HaAuthClient(baseUrl: baseUrl),
);
