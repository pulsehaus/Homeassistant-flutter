import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/application/connection_setup_providers.dart';
import 'package:homeassistant_flutter/features/connection/data/ha_auth_client.dart';
import 'package:homeassistant_flutter/features/connection/domain/connection_credentials.dart';
import 'package:homeassistant_flutter/features/connection/presentation/oauth_login_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../fakes/fake_credential_store.dart';
import '../fakes/fake_webview.dart';

void main() {
  setUpAll(setUpFakeOAuthWebView);

  Future<FakeCredentialStore> pumpPage(
    WidgetTester tester, {
    required Future<http.Response> Function(http.Request) tokenHandler,
  }) async {
    final store = FakeCredentialStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          credentialStoreProvider.overrideWithValue(store),
          haAuthClientFactoryProvider.overrideWithValue(
            (baseUrl) => HaAuthClient(
              baseUrl: baseUrl,
              httpClient: MockClient(tokenHandler),
            ),
          ),
        ],
        child: const MaterialApp(
          home: OAuthLoginPage(serverUrl: 'https://ha.example.com'),
        ),
      ),
    );
    await tester.pump();
    return store;
  }

  testWidgets('loads the authorize URL into the WebView on start', (
    tester,
  ) async {
    await pumpPage(tester, tokenHandler: (_) async => http.Response('{}', 200));

    final loadedUrls = FakeOAuthWebView.instance.loadedUrls;
    expect(loadedUrls, hasLength(1));
    expect(loadedUrls.single.path, '/auth/authorize');
    expect(loadedUrls.single.host, 'ha.example.com');
  });

  testWidgets(
    'intercepts the redirect, exchanges the code and pops with success',
    (tester) async {
      final store = await pumpPage(
        tester,
        tokenHandler: (_) async => http.Response(
          jsonEncode({
            'access_token': 'access-123',
            'refresh_token': 'refresh-123',
            'expires_in': 1800,
          }),
          200,
        ),
      );

      await FakeOAuthWebView.instance.simulateNavigation(
        'homeassistant-flutter://auth-callback?code=the-code',
      );
      await tester.pumpAndSettle();

      expect(store.writes, [
        const ConnectionCredentials(
          serverUrl: 'https://ha.example.com',
          accessToken: 'access-123',
          refreshToken: 'refresh-123',
        ),
      ]);
      // The page popped itself off the navigator once login succeeded.
      expect(find.byType(OAuthLoginPage), findsNothing);
    },
  );

  testWidgets('shows an inline error banner when the code exchange fails', (
    tester,
  ) async {
    await pumpPage(
      tester,
      tokenHandler: (_) async => http.Response(
        jsonEncode({
          'error': 'invalid_grant',
          'error_description': 'Code already used',
        }),
        400,
      ),
    );

    await FakeOAuthWebView.instance.simulateNavigation(
      'homeassistant-flutter://auth-callback?code=stale-code',
    );
    await tester.pumpAndSettle();

    expect(find.text('Code already used'), findsOneWidget);
    // Stays on the login page so the user can retry.
    expect(find.byType(OAuthLoginPage), findsOneWidget);
  });

  testWidgets('a navigation carrying no code is passed through untouched', (
    tester,
  ) async {
    final store = await pumpPage(
      tester,
      tokenHandler: (_) async => http.Response('{}', 200),
    );

    await FakeOAuthWebView.instance.simulateNavigation(
      'https://ha.example.com/auth/authorize?client_id=x',
    );
    await tester.pump();

    expect(store.writes, isEmpty);
    expect(find.byType(OAuthLoginPage), findsOneWidget);
  });
}
