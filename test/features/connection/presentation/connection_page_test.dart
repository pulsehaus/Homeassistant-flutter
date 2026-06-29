import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/application/connection_setup_providers.dart';
import 'package:homeassistant_flutter/features/connection/data/credential_validator.dart';
import 'package:homeassistant_flutter/features/connection/domain/connection_credentials.dart';
import 'package:homeassistant_flutter/features/connection/presentation/connection_page.dart';

import '../fakes/fake_credential_store.dart';
import '../fakes/fake_credential_validator.dart';

void main() {
  Future<FakeCredentialStore> pumpPage(
    WidgetTester tester, {
    required CredentialValidationResult validationResult,
  }) async {
    final store = FakeCredentialStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          credentialStoreProvider.overrideWithValue(store),
          credentialValidatorProvider.overrideWithValue(
            FakeCredentialValidator(validationResult),
          ),
        ],
        child: const MaterialApp(home: ConnectionPage()),
      ),
    );
    return store;
  }

  testWidgets('renders the URL and token fields and a connect button', (
    tester,
  ) async {
    await pumpPage(
      tester,
      validationResult: const CredentialValidationSuccess(),
    );

    expect(find.byKey(const Key('connection_url_field')), findsOneWidget);
    expect(find.byKey(const Key('connection_token_field')), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });

  testWidgets('shows inline field errors for empty input and does not save', (
    tester,
  ) async {
    final store = await pumpPage(
      tester,
      validationResult: const CredentialValidationSuccess(),
    );

    await tester.tap(find.byKey(const Key('connection_submit_button')));
    await tester.pump();

    expect(
      find.text('Enter a valid URL, e.g. https://ha.example.com'),
      findsOneWidget,
    );
    expect(find.text('Enter a long-lived access token'), findsOneWidget);
    expect(store.writes, isEmpty);
  });

  testWidgets('shows the validation error banner on a failed handshake', (
    tester,
  ) async {
    final store = await pumpPage(
      tester,
      validationResult: const CredentialValidationFailure(
        'Invalid access token',
        isAuth: true,
      ),
    );

    await tester.enterText(
      find.byKey(const Key('connection_url_field')),
      'https://ha.example.com',
    );
    await tester.enterText(
      find.byKey(const Key('connection_token_field')),
      'bad-token',
    );
    await tester.tap(find.byKey(const Key('connection_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Invalid access token'), findsOneWidget);
    expect(store.writes, isEmpty);
  });

  testWidgets('saves the credentials on a successful handshake', (
    tester,
  ) async {
    final store = await pumpPage(
      tester,
      validationResult: const CredentialValidationSuccess(),
    );

    await tester.enterText(
      find.byKey(const Key('connection_url_field')),
      'https://ha.example.com',
    );
    await tester.enterText(
      find.byKey(const Key('connection_token_field')),
      'good-token',
    );
    await tester.tap(find.byKey(const Key('connection_submit_button')));
    await tester.pumpAndSettle();

    expect(store.writes, [
      const ConnectionCredentials(
        serverUrl: 'https://ha.example.com',
        accessToken: 'good-token',
      ),
    ]);
  });
}
