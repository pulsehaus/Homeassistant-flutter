import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/charts/domain/chart_series.dart';
import 'package:homeassistant_flutter/features/charts/presentation/chart_example_page.dart';
import 'package:integration_test/integration_test.dart';

import '../test/features/charts/fake_webview.dart';

/// End-to-end flow: open the charts example screen, render a line chart from
/// sample data, switch it to a bar chart, and back.
///
/// graphify draws through a WebView; a fake WebView platform stands in so the
/// flow runs headless. When the communication layer (#2) lands, the same flow
/// runs against real entity history by swapping the screen's data source.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setUpFakeWebView);

  testWidgets('charts example screen renders and switches chart type', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ChartExamplePage()));
    await tester.pumpAndSettle();

    // Lands on the line chart.
    SegmentedButton<ChartType> selector() =>
        tester.widget(find.byType(SegmentedButton<ChartType>));
    expect(selector().selected, {ChartType.line});

    // Switch to bar and back; the screen rebuilds the chart each time.
    await tester.tap(find.text('Bar'));
    await tester.pumpAndSettle();
    expect(selector().selected, {ChartType.bar});

    await tester.tap(find.text('Line'));
    await tester.pumpAndSettle();
    expect(selector().selected, {ChartType.line});
  });
}
