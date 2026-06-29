import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/connection_credentials.dart';

/// Persistence boundary for the user's Home Assistant credentials.
///
/// This is the seam that keeps `flutter_secure_storage` (and its platform
/// quirks) out of the rest of the app: controllers depend on this interface,
/// not on the plugin, so the store can be mocked in tests and swapped per
/// platform. Implementations must store the token securely (Keychain / Keystore
/// / libsecret / Web Crypto), never in plain shared preferences.
abstract interface class CredentialStore {
  /// Read the stored credentials, or `null` if none have been saved.
  Future<ConnectionCredentials?> read();

  /// Persist [credentials], replacing anything already stored.
  Future<void> write(ConnectionCredentials credentials);

  /// Remove any stored credentials (used by the disconnect / change-instance
  /// path).
  Future<void> clear();
}

/// [CredentialStore] backed by `flutter_secure_storage`.
///
/// The URL and token are stored under separate keys; [read] only returns a
/// value when *both* are present so a partially written record never yields
/// half-valid credentials.
///
/// Platform notes:
/// - **iOS/macOS:** Keychain.
/// - **Android:** `EncryptedSharedPreferences` (enabled below), backed by the
///   Keystore.
/// - **Linux:** libsecret (requires `libsecret-1-dev` at build time).
/// - **Web:** values are encrypted with the Web Crypto API and stored in
///   `localStorage`; this is best-effort and weaker than the native
///   secure-element backends, which is acceptable for a self-hosted dashboard
///   but is the one caveat to be aware of on web.
class SecureCredentialStore implements CredentialStore {
  SecureCredentialStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  final FlutterSecureStorage _storage;

  static const _urlKey = 'ha_server_url';
  static const _tokenKey = 'ha_access_token';

  @override
  Future<ConnectionCredentials?> read() async {
    final url = await _storage.read(key: _urlKey);
    final token = await _storage.read(key: _tokenKey);
    if (url == null || url.isEmpty || token == null || token.isEmpty) {
      return null;
    }
    return ConnectionCredentials(serverUrl: url, accessToken: token);
  }

  @override
  Future<void> write(ConnectionCredentials credentials) async {
    await _storage.write(key: _urlKey, value: credentials.serverUrl);
    await _storage.write(key: _tokenKey, value: credentials.accessToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _urlKey);
    await _storage.delete(key: _tokenKey);
  }
}
