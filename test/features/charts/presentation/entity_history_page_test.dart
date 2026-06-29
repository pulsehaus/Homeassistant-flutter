import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/charts/application/chart_providers.dart';
import 'package:homeassistant_flutter/features/charts/domain/chart_series.dart';
import 'package:homeassistant_flutter/features/charts/presentation/entity_history_page.dart';

import '../fake_webview.dart';

ChartSeries _series() => ChartSeries(
  name: 'Living room',
  unit: '°C',
  points: [
    TimeSeriesPoint(time: DateTime.utc(2026, 6, 29, 10), value: 21.4),
    TimeSeriesPoint(time: DateTime.utc(2026, 6, 29, 11), value: 22.0),
  ],
);

Widget _harness(List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: const MaterialApp(home: EntityHistoryPage()),
);

void main() {
  // graphify renders through webview_flutter; stub the platform so the chart
  // can build under flutter_test without a real WebView.
  setUpAll(setUpFakeWebView);

  testWidgets('shows the empty surface when no numeric sensor is known', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness([defaultChartEntityProvider.overrideWithValue(null)]),
    );
    await tester.pump();

    expect(find.text('History'), findsOneWidget);
    expect(find.textContaining('No numeric sensor'), findsOneWidget);
  });

  testWidgets('shows the loading surface while history is fetched', (
    tester,
  ) async {
    final completer = Completer<ChartSeries>();
    await tester.pumpWidget(
      _harness([
        defaultChartEntityProvider.overrideWithValue('sensor.temp'),
        entityHistorySeriesProvider.overrideWith(
          (ref, request) => completer.future,
        ),
      ]),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(_series());
    await tester.pumpAndSettle();
  });

  testWidgets('shows the error surface (with retry) when the fetch fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness([
        defaultChartEntityProvider.overrideWithValue('sensor.temp'),
        entityHistorySeriesProvider.overrideWith(
          (ref, request) => Future<ChartSeries>.error('boom'),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('shows the empty surface when the entity has no history', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness([
        defaultChartEntityProvider.overrideWithValue('sensor.temp'),
        entityHistorySeriesProvider.overrideWith(
          (ref, request) async =>
              const ChartSeries(name: 'sensor.temp', points: []),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No recorded history'), findsOneWidget);
  });

  testWidgets('renders the chart content when history is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness([
        defaultChartEntityProvider.overrideWithValue('sensor.temp'),
        entityHistorySeriesProvider.overrideWith(
          (ref, request) async => _series(),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    // The descriptive caption and the chart (its faked webview) are present.
    expect(find.textContaining('Live history for sensor.temp'), findsOneWidget);
    expect(find.byKey(const ValueKey('fake-webview')), findsOneWidget);
  });
}
