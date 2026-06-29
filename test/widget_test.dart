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

import 'features/charts/fake_webview.dart';

void main() {
  // The app shell eagerly builds every destination (incl. the charts screen,
  // which embeds a WebView via graphify), so stub the WebView platform.
  setUpAll(setUpFakeWebView);

  testWidgets('Home shell renders and the Riverpod counter increments', (
    WidgetTester tester,
  ) async {
    // ProviderScope is required for Riverpod providers to resolve.
    await tester.pumpWidget(const ProviderScope(child: HomeAssistantApp()));

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
    await tester.pumpWidget(const ProviderScope(child: HomeAssistantApp()));

    // Charts is the second navigation destination.
    await tester.tap(find.text('Charts').last);
    await tester.pump();

    // The charts screen's line/bar toggle is now visible.
    expect(find.text('Line'), findsOneWidget);
    expect(find.text('Bar'), findsOneWidget);
  });
}
