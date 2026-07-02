import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/charts/application/chart_providers.dart';
import 'package:homeassistant_flutter/features/charts/domain/chart_series.dart';
import 'package:homeassistant_flutter/features/charts/presentation/entity_history_page.dart';

import '../fake_webview.dart';
import '../fakes/fake_chart_selection_store.dart';

ChartSeries _series() => ChartSeries(
  name: 'Living room',
  unit: '°C',
  points: [
    TimeSeriesPoint(time: DateTime.utc(2026, 6, 29, 10), value: 21.4),
    TimeSeriesPoint(time: DateTime.utc(2026, 6, 29, 11), value: 22.0),
  ],
);

Widget _harness(List<Override> overrides) => ProviderScope(
  overrides: [
    // A fresh in-memory store by default so tests that don't care about
    // persistence (most of them) don't touch real platform storage; tests
    // that do care override chartSelectionStoreProvider themselves, which
    // takes precedence since it comes after this default in the list.
    chartSelectionStoreProvider.overrideWithValue(FakeChartSelectionStore()),
    ...overrides,
  ],
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

  testWidgets(
    'shows a history-specific empty surface when the entity has no history',
    (tester) async {
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

      expect(find.text('No history for this entity yet'), findsOneWidget);
      expect(find.textContaining('sensor.temp'), findsWidgets);
      expect(find.textContaining('last 24h'), findsOneWidget);
      expect(find.byIcon(Icons.show_chart), findsOneWidget);
      // Not the shared template's generic default icon.
      expect(find.byIcon(Icons.inbox_outlined), findsNothing);
    },
  );

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

  testWidgets('defaults to the 24h range and shows the three options', (
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

    expect(find.text('1h'), findsOneWidget);
    expect(find.text('24h'), findsOneWidget);
    expect(find.text('7d'), findsOneWidget);
    expect(find.textContaining('last 24h'), findsOneWidget);
  });

  testWidgets('switching the range re-fetches history for that window', (
    tester,
  ) async {
    final requestedPeriods = <Duration>[];
    await tester.pumpWidget(
      _harness([
        defaultChartEntityProvider.overrideWithValue('sensor.temp'),
        entityHistorySeriesProvider.overrideWith((ref, request) async {
          requestedPeriods.add(request.period);
          return _series();
        }),
      ]),
    );
    await tester.pumpAndSettle();
    expect(requestedPeriods, contains(const Duration(hours: 24)));

    await tester.tap(find.text('7d'));
    await tester.pumpAndSettle();

    expect(requestedPeriods, contains(const Duration(days: 7)));
    expect(find.textContaining('last 168h'), findsOneWidget);
  });

  testWidgets('the picker lists every known numeric sensor', (tester) async {
    await tester.pumpWidget(
      _harness([
        numericSensorEntitiesProvider.overrideWithValue([
          'sensor.a',
          'sensor.b',
        ]),
        defaultChartEntityProvider.overrideWithValue('sensor.a'),
        entityHistorySeriesProvider.overrideWith(
          (ref, request) async => _series(),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButton<String>), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('sensor.a').hitTestable(), findsOneWidget);
    expect(find.text('sensor.b'), findsOneWidget);
  });

  testWidgets('selecting a sensor in the picker charts that entity', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness([
        numericSensorEntitiesProvider.overrideWithValue([
          'sensor.a',
          'sensor.b',
        ]),
        defaultChartEntityProvider.overrideWithValue('sensor.a'),
        entityHistorySeriesProvider.overrideWith(
          (ref, request) async => ChartSeries(
            name: request.entityId,
            points: [TimeSeriesPoint(time: DateTime.utc(2026), value: 1)],
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Live history for sensor.a'), findsOneWidget);

    // Open the dropdown and pick the other sensor.
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('sensor.b').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Live history for sensor.b'), findsOneWidget);
  });

  testWidgets('no picker is shown when there are no numeric sensors', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness([
        numericSensorEntitiesProvider.overrideWithValue(const []),
        defaultChartEntityProvider.overrideWithValue('sensor.a'),
        entityHistorySeriesProvider.overrideWith(
          (ref, request) async => _series(),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButton<String>), findsNothing);
  });

  testWidgets('pulling to refresh re-fetches the history data', (tester) async {
    var fetchCount = 0;
    await tester.pumpWidget(
      _harness([
        defaultChartEntityProvider.overrideWithValue('sensor.temp'),
        entityHistorySeriesProvider.overrideWith((ref, request) async {
          fetchCount++;
          return _series();
        }),
      ]),
    );
    await tester.pumpAndSettle();
    expect(fetchCount, 1);
    expect(find.byType(RefreshIndicator), findsOneWidget);

    // Drag down from the top of the RefreshIndicator to trigger a
    // pull-to-refresh, then let the indicator's animation settle.
    await tester.fling(
      find.byType(RefreshIndicator),
      const Offset(0, 300),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(fetchCount, 2);
  });

  group('persisted selection (#61)', () {
    testWidgets('restores a previously selected entity and range on startup', (
      tester,
    ) async {
      // Simulates a returning user: the store already has a selection from
      // a previous session, before the widget is ever built.
      final store = FakeChartSelectionStore(
        initialEntityId: 'sensor.b',
        initialRange: HistoryRange.days7,
      );
      final requestedPeriods = <Duration>[];

      await tester.pumpWidget(
        _harness([
          chartSelectionStoreProvider.overrideWithValue(store),
          numericSensorEntitiesProvider.overrideWithValue([
            'sensor.a',
            'sensor.b',
          ]),
          defaultChartEntityProvider.overrideWithValue('sensor.a'),
          entityHistorySeriesProvider.overrideWith((ref, request) async {
            requestedPeriods.add(request.period);
            return ChartSeries(name: request.entityId, points: const []);
          }),
        ]),
      );
      await tester.pumpAndSettle();

      // The stored entity (not the default) and the stored range (not the
      // 24h default) are both restored, with no user interaction.
      expect(
        find.textContaining('No history for this entity yet'),
        findsOneWidget,
      );
      expect(find.textContaining('sensor.b'), findsWidgets);
      expect(requestedPeriods, contains(const Duration(days: 7)));
    });

    testWidgets(
      'a selection made in one session is loaded by a fresh widget tree '
      'reading the same store (simulated restart)',
      (tester) async {
        final store = FakeChartSelectionStore();

        // "Session 1": pick a non-default sensor and a non-default range.
        await tester.pumpWidget(
          _harness([
            chartSelectionStoreProvider.overrideWithValue(store),
            numericSensorEntitiesProvider.overrideWithValue([
              'sensor.a',
              'sensor.b',
            ]),
            defaultChartEntityProvider.overrideWithValue('sensor.a'),
            entityHistorySeriesProvider.overrideWith(
              (ref, request) async => _series(),
            ),
          ]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DropdownButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('sensor.b').last);
        await tester.pumpAndSettle();

        await tester.tap(find.text('7d'));
        await tester.pumpAndSettle();

        expect(store.entityIdWrites, ['sensor.b']);
        expect(store.rangeWrites, [HistoryRange.days7]);

        // Tear down session 1's widget tree entirely (disposing its
        // ProviderScope/container) before mounting session 2 — otherwise
        // Flutter's element reconciliation would just reuse the existing
        // ProviderScope element (same type/position) and its already-resolved
        // provider state, which wouldn't actually exercise a fresh read from
        // the store the way a real app restart does.
        await tester.pumpWidget(const SizedBox.shrink());

        // "Session 2": a brand new widget tree (simulating an app restart)
        // reading the same (now populated) store.
        final requestedPeriods = <Duration>[];
        await tester.pumpWidget(
          _harness([
            chartSelectionStoreProvider.overrideWithValue(store),
            numericSensorEntitiesProvider.overrideWithValue([
              'sensor.a',
              'sensor.b',
            ]),
            defaultChartEntityProvider.overrideWithValue('sensor.a'),
            entityHistorySeriesProvider.overrideWith((ref, request) async {
              requestedPeriods.add(request.period);
              return ChartSeries(name: request.entityId, points: const []);
            }),
          ]),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('sensor.b'), findsWidgets);
        expect(requestedPeriods, contains(const Duration(days: 7)));
      },
    );

    testWidgets('first launch (nothing stored) keeps today\'s defaults', (
      tester,
    ) async {
      final requestedPeriods = <Duration>[];
      await tester.pumpWidget(
        _harness([
          // FakeChartSelectionStore() from the harness default is empty,
          // simulating a fresh install with nothing persisted yet.
          defaultChartEntityProvider.overrideWithValue('sensor.temp'),
          entityHistorySeriesProvider.overrideWith((ref, request) async {
            requestedPeriods.add(request.period);
            return _series();
          }),
        ]),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Live history for sensor.temp'),
        findsOneWidget,
      );
      expect(requestedPeriods, [const Duration(hours: 24)]);
    });
  });
}
