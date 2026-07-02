import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/application/connection_session_controller.dart';
import 'package:homeassistant_flutter/features/connection/application/connection_setup_providers.dart';
import 'package:homeassistant_flutter/features/connection/application/oauth_login_controller.dart';
import 'package:homeassistant_flutter/features/connection/data/ha_auth_client.dart';
import 'package:homeassistant_flutter/features/connection/domain/connection_credentials.dart';
import 'package:homeassistant_flutter/features/connection/domain/oauth_client_config.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../fakes/fake_credential_store.dart';

void main() {
  ProviderContainer containerWith({
    required Future<http.Response> Function(http.Request) tokenHandler,
    FakeCredentialStore? store,
  }) {
    final container = ProviderContainer(
      overrides: [
        credentialStoreProvider.overrideWithValue(
          store ?? FakeCredentialStore(),
        ),
        haAuthClientFactoryProvider.overrideWithValue(
          (baseUrl) => HaAuthClient(
            baseUrl: baseUrl,
            httpClient: MockClient(tokenHandler),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('OAuthLoginController.start', () {
    test('rejects an invalid server URL without touching the auth client', () {
      final container = containerWith(
        tokenHandler: (_) async => http.Response('{}', 200),
      );
      final controller = container.read(oauthLoginControllerProvider.notifier);

      final started = controller.start('not a url');

      expect(started, isFalse);
      final state = container.read(oauthLoginControllerProvider);
      expect(state.status, OAuthLoginStatus.error);
      expect(state.errorMessage, isNotNull);
    });

    test('builds the authorize URL for a valid server URL', () {
      final container = containerWith(
        tokenHandler: (_) async => http.Response('{}', 200),
      );
      final controller = container.read(oauthLoginControllerProvider.notifier);

      final started = controller.start('https://ha.example.com');

      expect(started, isTrue);
      final state = container.read(oauthLoginControllerProvider);
      expect(state.status, OAuthLoginStatus.authorizing);
      expect(state.authorizeUrl?.host, 'ha.example.com');
      expect(state.authorizeUrl?.path, '/auth/authorize');
      expect(
        state.authorizeUrl?.queryParameters['client_id'],
        OAuthClientConfig.clientId,
      );
    });
  });

  group('OAuthLoginController.completeWithCode', () {
    test('exchanges the code, saves the session and reports success', () async {
      final store = FakeCredentialStore();
      final container = containerWith(
        store: store,
        tokenHandler: (request) async => http.Response(
          jsonEncode({
            'access_token': 'access-123',
            'refresh_token': 'refresh-123',
            'expires_in': 1800,
          }),
          200,
        ),
      );
      // Establish the session controller before completeWithCode saves to
      // it, mirroring how the app always has connectionSessionProvider
      // built before the login page can be reached.
      await container.read(connectionSessionProvider.future);
      final controller = container.read(oauthLoginControllerProvider.notifier);
      controller.start('https://ha.example.com');

      final success = await controller.completeWithCode('the-auth-code');

      expect(success, isTrue);
      expect(
        container.read(oauthLoginControllerProvider).status,
        OAuthLoginStatus.success,
      );
      expect(store.writes, [
        const ConnectionCredentials(
          serverUrl: 'https://ha.example.com',
          accessToken: 'access-123',
          refreshToken: 'refresh-123',
        ),
      ]);
    });

    test('surfaces a HaAuthException as a user-facing error', () async {
      final container = containerWith(
        tokenHandler: (_) async => http.Response(
          jsonEncode({
            'error': 'invalid_grant',
            'error_description': 'Bad code',
          }),
          400,
        ),
      );
      await container.read(connectionSessionProvider.future);
      final controller = container.read(oauthLoginControllerProvider.notifier);
      controller.start('https://ha.example.com');

      final success = await controller.completeWithCode('bad-code');

      expect(success, isFalse);
      final state = container.read(oauthLoginControllerProvider);
      expect(state.status, OAuthLoginStatus.error);
      expect(state.errorMessage, 'Bad code');
    });

    test('fails cleanly if called before start (defensive — should not happen '
        'via the real UI)', () async {
      final container = containerWith(
        tokenHandler: (_) async => http.Response('{}', 200),
      );
      final controller = container.read(oauthLoginControllerProvider.notifier);

      final success = await controller.completeWithCode('any-code');

      expect(success, isFalse);
      expect(
        container.read(oauthLoginControllerProvider).status,
        OAuthLoginStatus.error,
      );
    });
  });

  group('extractAuthorizationCode', () {
    test('extracts the code from a matching redirect URI', () {
      final code = extractAuthorizationCode(
        '${OAuthClientConfig.redirectUri}?code=abc123',
      );
      expect(code, 'abc123');
    });

    test('returns null for a non-redirect URL', () {
      expect(
        extractAuthorizationCode('https://ha.example.com/auth/authorize'),
        isNull,
      );
    });

    test('returns null for an error redirect with no code', () {
      final code = extractAuthorizationCode(
        '${OAuthClientConfig.redirectUri}?error=access_denied',
      );
      expect(code, isNull);
    });
  });
}
