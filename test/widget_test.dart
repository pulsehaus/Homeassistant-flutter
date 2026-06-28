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

void main() {
  testWidgets('Home shell renders and the Riverpod counter increments', (
    WidgetTester tester,
  ) async {
    // ProviderScope is required for Riverpod providers to resolve.
    await tester.pumpWidget(const ProviderScope(child: HomeAssistantApp()));

    // The app shell is shown and the counter starts at 0.
    expect(find.text('Foundation ready'), findsOneWidget);
    expect(find.text('Riverpod example — counter: 0'), findsOneWidget);

    // Tapping the '+' button drives the provider and rebuilds the UI.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('Riverpod example — counter: 1'), findsOneWidget);
  });
}
