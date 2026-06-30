import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/app/app.dart';
import 'package:homeassistant_flutter/features/connection/application/connection_providers.dart';
import 'package:homeassistant_flutter/features/connection/application/connection_setup_providers.dart';
import 'package:homeassistant_flutter/features/connection/data/ha_websocket_client.dart';
import 'package:homeassistant_flutter/features/connection/domain/connection_credentials.dart';
import 'package:homeassistant_flutter/features/connection/domain/ha_connection_config.dart';
import 'package:integration_test/integration_test.dart';

import '../test/features/charts/fake_webview.dart';
import '../test/features/connection/fakes/fake_credential_store.dart';
import '../test/features/connection/fakes/fake_ha_socket.dart';

/// On-device twin of the `test/widget_test.dart` shell smoke test: boot the real
/// app on a device/emulator and exercise the app shell built in #3 end to end —
/// land on Home (driving the Riverpod counter), navigate to the History
/// destination, then back, asserting Home kept its state (IndexedStack).
///
/// Like the headless twin, it seeds stored credentials so the app skips the
/// connection screen (#38 gating) and lands on the shell, and overrides the
/// WebSocket client with a fake-socket client so no real connection is ever
/// opened. graphify draws through a WebView; a fake WebView platform stands in.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setUpFakeWebView);

  // A WebSocket client wired to an in-memory fake socket: it never touches the
  // network and never reaches `connected`, which is the cold-start state the
  // gated dashboard config provider (#38) tolerates by staying on its loading
  // surface — so the shell renders without waiting on a live connection.
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
  // the shell, and override the WebSocket client so no real connection (or
  // reconnect timer) is ever opened.
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
    ],
    child: const HomeAssistantApp(),
  );

  // The gated Dashboard destination stays on an infinite spinner because the
  // fake client never connects, so `pumpAndSettle()` would never return. Pump a
  // bounded number of frames instead: enough to resolve the stored-credentials
  // future and build the shell + its destinations.
  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pump(); // resolve connectionSessionProvider → _ConnectedApp
    await tester.pump(); // build the shell + its destinations
  }

  testWidgets('navigates the app shell and preserves Home state on a device', (
    tester,
  ) async {
    await tester.pumpWidget(appWithStoredCredentials());
    await pumpShell(tester);

    // Lands on Home, built on the shared page template, with the counter at 0.
    expect(find.text('Foundation ready'), findsOneWidget);
    expect(find.text('Riverpod example — counter: 0'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    // The Home screen drives the Riverpod counter.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('Riverpod example — counter: 1'), findsOneWidget);

    // Navigate to History through the shell. With no entity states streaming in
    // (the WebSocket never connects), the real-history screen shows its shared
    // empty surface.
    await tester.tap(find.text('History').last);
    await tester.pump();
    expect(find.textContaining('No numeric sensor'), findsOneWidget);

    // Navigate back to Home; the counter kept its state (IndexedStack).
    await tester.tap(find.text('Home').last);
    await tester.pump();
    expect(find.text('Riverpod example — counter: 1'), findsOneWidget);
  });
}
