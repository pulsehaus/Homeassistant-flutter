import 'package:homeassistant_flutter/features/connection/data/credential_store.dart';
import 'package:homeassistant_flutter/features/connection/domain/connection_credentials.dart';

/// In-memory [CredentialStore] for tests. Records writes/clears so a test can
/// assert what was persisted, and can be seeded with [initial] credentials to
/// simulate a returning user.
class FakeCredentialStore implements CredentialStore {
  FakeCredentialStore({ConnectionCredentials? initial}) : _stored = initial;

  ConnectionCredentials? _stored;

  /// The credentials handed to [write], in order. Empty until something is
  /// saved.
  final List<ConnectionCredentials> writes = [];

  /// How many times [clear] was called.
  int clears = 0;

  /// Whether anything is currently stored — handy for assertions.
  ConnectionCredentials? get current => _stored;

  @override
  Future<ConnectionCredentials?> read() async => _stored;

  @override
  Future<void> write(ConnectionCredentials credentials) async {
    writes.add(credentials);
    _stored = credentials;
  }

  @override
  Future<void> clear() async {
    clears += 1;
    _stored = null;
  }
}
