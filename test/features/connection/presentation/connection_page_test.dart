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

  /// The manual long-lived-token form lives collapsed under the "Advanced"
  /// section; expand it before interacting with the token field or submit
  /// button, mirroring the real user flow.
  Future<void> expandAdvancedSection(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('advanced_token_section')));
    await tester.pumpAndSettle();
  }

  testWidgets('renders the URL field and a primary Log in button', (
    tester,
  ) async {
    await pumpPage(
      tester,
      validationResult: const CredentialValidationSuccess(),
    );

    expect(find.byKey(const Key('connection_url_field')), findsOneWidget);
    expect(find.byKey(const Key('oauth_login_button')), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('the advanced token form is collapsed by default', (
    tester,
  ) async {
    await pumpPage(
      tester,
      validationResult: const CredentialValidationSuccess(),
    );

    expect(
      find.text('Advanced: use a long-lived access token instead'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('connection_token_field')), findsNothing);
  });

  testWidgets('expanding Advanced reveals the token field and connect button', (
    tester,
  ) async {
    await pumpPage(
      tester,
      validationResult: const CredentialValidationSuccess(),
    );

    await expandAdvancedSection(tester);

    expect(find.byKey(const Key('connection_token_field')), findsOneWidget);
    expect(find.text('Connect with token'), findsOneWidget);
  });

  testWidgets('shows inline field errors for empty input and does not save', (
    tester,
  ) async {
    final store = await pumpPage(
      tester,
      validationResult: const CredentialValidationSuccess(),
    );
    await expandAdvancedSection(tester);

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
    await expandAdvancedSection(tester);

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
    await expandAdvancedSection(tester);

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

  testWidgets('Log in shows an inline error for an invalid server URL', (
    tester,
  ) async {
    await pumpPage(
      tester,
      validationResult: const CredentialValidationSuccess(),
    );

    await tester.tap(find.byKey(const Key('oauth_login_button')));
    await tester.pump();

    expect(
      find.text('Enter a valid URL, e.g. https://ha.example.com'),
      findsOneWidget,
    );
    // Doesn't navigate anywhere on invalid input.
    expect(find.byType(ConnectionPage), findsOneWidget);
  });
}
