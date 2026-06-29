import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/app/app.dart';
import 'package:integration_test/integration_test.dart';

import '../test/features/charts/fake_webview.dart';

/// End-to-end flow exercising the app shell built in #3: boot the real app,
/// land on the Home destination (driving the Riverpod counter), then navigate
/// via the shell's bottom navigation to the Charts destination and back.
///
/// graphify draws the chart through a WebView; a fake WebView platform stands in
/// so the flow runs headless.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setUpFakeWebView);

  testWidgets('navigates between Home and Charts via the app shell', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: HomeAssistantApp()));
    await tester.pumpAndSettle();

    // Lands on Home, built on the shared page template.
    expect(find.text('Foundation ready'), findsOneWidget);
    expect(find.text('Riverpod example — counter: 0'), findsOneWidget);

    // The Home screen still drives the Riverpod counter.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Riverpod example — counter: 1'), findsOneWidget);

    // Navigate to Charts through the shell.
    await tester.tap(find.text('Charts').last);
    await tester.pumpAndSettle();
    expect(find.text('Line'), findsOneWidget);
    expect(find.text('Bar'), findsOneWidget);

    // Navigate back to Home; the counter kept its state (IndexedStack).
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    expect(find.text('Riverpod example — counter: 1'), findsOneWidget);
  });
}
