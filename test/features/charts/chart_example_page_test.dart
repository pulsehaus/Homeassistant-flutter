import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/charts/domain/chart_series.dart';
import 'package:homeassistant_flutter/features/charts/presentation/chart_example_page.dart';

import 'fake_webview.dart';

void main() {
  // graphify renders through webview_flutter; stub the platform so the widget
  // tree can build under flutter_test without a real WebView.
  setUpAll(setUpFakeWebView);

  testWidgets('renders the chart scaffold and toggles line/bar', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ChartExamplePage()));
    await tester.pump();

    // App chrome and the line/bar selector are present.
    expect(find.text('Charts'), findsOneWidget);
    expect(find.byType(SegmentedButton<ChartType>), findsOneWidget);
    expect(find.text('Line'), findsOneWidget);
    expect(find.text('Bar'), findsOneWidget);

    // Switching to Bar updates the selected segment without throwing.
    await tester.tap(find.text('Bar'));
    await tester.pump();

    final segmented = tester.widget<SegmentedButton<ChartType>>(
      find.byType(SegmentedButton<ChartType>),
    );
    expect(segmented.selected, {ChartType.bar});
  });
}
