// Smoke test for the app shell and the Riverpod reference example.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homeassistant_flutter/app/app.dart';
import 'package:homeassistant_flutter/features/connection/application/connection_setup_providers.dart';
import 'package:homeassistant_flutter/features/connection/domain/connection_credentials.dart';

import 'features/charts/fake_webview.dart';
import 'features/connection/fakes/fake_credential_store.dart';

void main() {
  // The app shell eagerly builds every destination (incl. the charts screen,
  // which embeds a WebView via graphify), so stub the WebView platform.
  setUpAll(setUpFakeWebView);

  // Seed stored credentials so the app skips the connection screen and lands on
  // the shell — the smoke test is about the shell, not the first-run flow.
  ProviderScope appWithStoredCredentials() => ProviderScope(
    overrides: [
      credentialStoreProvider.overrideWithValue(
        FakeCredentialStore(
          initial: const ConnectionCredentials(
            serverUrl: 'https://ha.example.com',
            accessToken: 'token',
          ),
        ),
      ),
    ],
    child: const HomeAssistantApp(),
  );

  testWidgets('Home shell renders and the Riverpod counter increments', (
    WidgetTester tester,
  ) async {
    // ProviderScope is required for Riverpod providers to resolve.
    await tester.pumpWidget(appWithStoredCredentials());
    await tester.pumpAndSettle();

    // The app shell is shown with the Home destination selected, and the
    // counter starts at 0.
    expect(find.text('Foundation ready'), findsOneWidget);
    expect(find.text('Riverpod example — counter: 0'), findsOneWidget);

    // The shell exposes navigation between Home and Charts.
    expect(find.byType(NavigationBar), findsOneWidget);

    // Tapping the '+' button drives the provider and rebuilds the UI.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('Riverpod example — counter: 1'), findsOneWidget);
  });

  testWidgets('Switching to the Charts destination shows the charts screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(appWithStoredCredentials());
    await tester.pumpAndSettle();

    // Charts is the second navigation destination.
    await tester.tap(find.text('Charts').last);
    await tester.pump();

    // The charts screen's line/bar toggle is now visible.
    expect(find.text('Line'), findsOneWidget);
    expect(find.text('Bar'), findsOneWidget);
  });
}
