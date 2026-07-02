import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/data/credential_store.dart';
import 'package:homeassistant_flutter/features/connection/domain/connection_credentials.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  // In-memory stand-in for the native secure storage, wired to the plugin's
  // method channel so SecureCredentialStore exercises its real read/write/clear
  // paths without a device keychain.
  late Map<String, String> backing;

  setUp(() {
    backing = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = (call.arguments as Map).cast<String, dynamic>();
          final key = args['key'] as String?;
          switch (call.method) {
            case 'write':
              backing[key!] = args['value'] as String;
              return null;
            case 'read':
              return backing[key];
            case 'delete':
              backing.remove(key);
              return null;
            case 'readAll':
              return backing;
            case 'containsKey':
              return backing.containsKey(key);
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  CredentialStore store() =>
      SecureCredentialStore(storage: const FlutterSecureStorage());

  const credentials = ConnectionCredentials(
    serverUrl: 'https://ha.example.com',
    accessToken: 'secret-token',
  );

  const oauthCredentials = ConnectionCredentials(
    serverUrl: 'https://ha.example.com',
    accessToken: 'oauth-access-token',
    refreshToken: 'oauth-refresh-token',
  );

  group('SecureCredentialStore', () {
    test('read returns null when nothing is stored', () async {
      expect(await store().read(), isNull);
    });

    test('write then read round-trips the credentials', () async {
      final s = store();
      await s.write(credentials);

      final read = await s.read();
      expect(read, credentials);
    });

    test('read returns null when only one key is present', () async {
      // Simulate a partially written record (url only, no token).
      backing['ha_server_url'] = 'https://ha.example.com';
      expect(await store().read(), isNull);
    });

    test('read returns credentials with a null refreshToken when it was never '
        'written (backward compatibility with pre-OAuth2 records)', () async {
      // Simulate credentials stored before the refresh-token key existed:
      // only the URL and access-token keys are present.
      backing['ha_server_url'] = credentials.serverUrl;
      backing['ha_access_token'] = credentials.accessToken;

      final read = await store().read();

      expect(read, credentials);
      expect(read?.refreshToken, isNull);
    });

    test('write then read round-trips an OAuth2 session including the refresh '
        'token', () async {
      final s = store();
      await s.write(oauthCredentials);

      final read = await s.read();
      expect(read, oauthCredentials);
      expect(read?.refreshToken, 'oauth-refresh-token');
    });

    test('writing credentials with no refresh token clears any previously '
        'stored one', () async {
      final s = store();
      await s.write(oauthCredentials);
      await s.write(credentials);

      expect(backing.containsKey('ha_refresh_token'), isFalse);
      final read = await s.read();
      expect(read?.refreshToken, isNull);
    });

    test('clear removes all keys, including the refresh token', () async {
      final s = store();
      await s.write(oauthCredentials);
      await s.clear();

      expect(backing, isEmpty);
      expect(await s.read(), isNull);
    });
  });
}
