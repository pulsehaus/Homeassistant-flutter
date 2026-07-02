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
import 'package:homeassistant_flutter/core/theme/theme_mode_providers.dart';
import 'package:homeassistant_flutter/features/charts/application/chart_providers.dart';
import 'package:homeassistant_flutter/features/connection/application/connection_providers.dart';
import 'package:homeassistant_flutter/features/connection/application/connection_setup_providers.dart';
import 'package:homeassistant_flutter/features/connection/data/ha_websocket_client.dart';
import 'package:homeassistant_flutter/features/connection/domain/connection_credentials.dart';
import 'package:homeassistant_flutter/features/connection/domain/ha_connection_config.dart';

import 'core/theme/fakes/fake_theme_mode_store.dart';
import 'features/charts/fake_webview.dart';
import 'features/charts/fakes/fake_chart_selection_store.dart';
import 'features/connection/fakes/fake_credential_store.dart';
import 'features/connection/fakes/fake_ha_socket.dart';

void main() {
  // The app shell eagerly builds every destination (incl. the charts screen,
  // which embeds a WebView via graphify), so stub the WebView platform.
  setUpAll(setUpFakeWebView);

  // A WebSocket client wired to an in-memory fake socket: it never touches the
  // network, so it never schedules a reconnect timer. Crucially it also never
  // reaches `connected`, which is exactly the cold-start state the gated
  // dashboard config provider (issue #38) must tolerate by staying on its
  // loading surface — letting us assert the shell renders without waiting on a
  // live connection that would otherwise hang `pumpAndSettle`.
  late HaWebSocketClient fakeClient;

  setUp(() {
    fakeClient = HaWebSocketClient(
      config: HaConnectionConfig(
        baseUrl: Uri.parse('https://ha.example.com'),
        accessToken: 'token',
      ),
      connector: FakeConnector().connect,
    );
  });

  tearDown(() => fakeClient.dispose());

  // Seed stored credentials so the app skips the connection screen and lands on
  // the shell — the smoke test is about the shell, not the first-run flow. The
  // WebSocket client is overridden with a fake-socket client so no real
  // connection (or reconnect timer) is ever opened.
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
      haWebSocketClientProvider.overrideWithValue(fakeClient),
      themeModeStoreProvider.overrideWithValue(FakeThemeModeStore()),
      chartSelectionStoreProvider.overrideWithValue(FakeChartSelectionStore()),
    ],
    child: const HomeAssistantApp(),
  );

  // Lay out the shell deterministically. The gated Dashboard destination stays
  // on its loading surface (a CircularProgressIndicator) because the fake client
  // never connects, and that spinner animates forever — so `pumpAndSettle()`
  // would never settle. Pump a bounded number of frames instead: enough to
  // resolve the stored-credentials future and build the shell + destinations.
  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pump(); // resolve connectionSessionProvider → _ConnectedApp
    await tester.pump(); // build the shell + its destinations
  }

  testWidgets('Home shell renders and the Riverpod counter increments', (
    WidgetTester tester,
  ) async {
    // ProviderScope is required for Riverpod providers to resolve.
    await tester.pumpWidget(appWithStoredCredentials());
    await pumpShell(tester);

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

  testWidgets('Switching to the History destination shows the history screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(appWithStoredCredentials());
    await pumpShell(tester);

    // History is the second navigation destination.
    await tester.tap(find.text('History').last);
    await tester.pump();

    // No entity states stream in under the test (the WebSocket never
    // connects), so the real-history screen shows its shared empty surface.
    expect(find.textContaining('No numeric sensor'), findsOneWidget);
  });
}
