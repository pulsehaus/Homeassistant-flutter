import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/charts/application/chart_providers.dart';
import 'package:homeassistant_flutter/features/charts/domain/chart_series.dart';
import 'package:homeassistant_flutter/features/dashboard/domain/lovelace_card.dart';
import 'package:homeassistant_flutter/features/dashboard/presentation/cards/history_graph_card_widget.dart';

import '../../../charts/fake_webview.dart';

ChartSeries _series(String name) => ChartSeries(
  name: name,
  points: [
    TimeSeriesPoint(time: DateTime.utc(2026, 6, 29, 10), value: 21.4),
    TimeSeriesPoint(time: DateTime.utc(2026, 6, 29, 11), value: 22.0),
  ],
);

Widget _harness(HistoryGraphCard card, List<Override> overrides) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Scaffold(body: HistoryGraphCardWidget(card: card)),
      ),
    );

void main() {
  // graphify renders through webview_flutter; stub the platform so the chart
  // can build under flutter_test without a real WebView.
  setUpAll(setUpFakeWebView);

  testWidgets('renders the title and a chart per entity', (tester) async {
    const card = HistoryGraphCard(
      title: 'Temperatures',
      entities: ['sensor.living_room', 'sensor.bedroom'],
    );

    await tester.pumpWidget(
      _harness(card, [
        entityHistorySeriesProvider.overrideWith(
          (ref, request) async => _series(request.entityId),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Temperatures'), findsOneWidget);
    expect(find.byKey(const ValueKey('fake-webview')), findsNWidgets(2));
  });

  testWidgets('shows a spinner for an entity whose history is still loading', (
    tester,
  ) async {
    const card = HistoryGraphCard(entities: ['sensor.living_room']);
    final completer = Completer<ChartSeries>();

    await tester.pumpWidget(
      _harness(card, [
        entityHistorySeriesProvider.overrideWith(
          (ref, request) => completer.future,
        ),
      ]),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(_series('sensor.living_room'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('fake-webview')), findsOneWidget);
  });

  testWidgets(
    'shows a per-entity error without blocking the rest of the card',
    (tester) async {
      const card = HistoryGraphCard(
        entities: ['sensor.broken', 'sensor.living_room'],
      );

      await tester.pumpWidget(
        _harness(card, [
          entityHistorySeriesProvider.overrideWith((ref, request) async {
            if (request.entityId == 'sensor.broken') {
              throw StateError('boom');
            }
            return _series(request.entityId);
          }),
        ]),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Could not load history for sensor.broken.'),
        findsOneWidget,
      );
      // The other entity still renders its chart.
      expect(find.byKey(const ValueKey('fake-webview')), findsOneWidget);
    },
  );

  testWidgets('shows an empty message when an entity has no history', (
    tester,
  ) async {
    const card = HistoryGraphCard(entities: ['sensor.living_room']);

    await tester.pumpWidget(
      _harness(card, [
        entityHistorySeriesProvider.overrideWith(
          (ref, request) async =>
              const ChartSeries(name: 'sensor.living_room', points: []),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('No history for sensor.living_room yet.'), findsOneWidget);
  });

  testWidgets('uses hoursToShow as the requested period', (tester) async {
    const card = HistoryGraphCard(
      entities: ['sensor.living_room'],
      hoursToShow: 48,
    );
    Duration? requestedPeriod;

    await tester.pumpWidget(
      _harness(card, [
        entityHistorySeriesProvider.overrideWith((ref, request) async {
          requestedPeriod = request.period;
          return _series(request.entityId);
        }),
      ]),
    );
    await tester.pumpAndSettle();

    expect(requestedPeriod, const Duration(hours: 48));
  });
}
