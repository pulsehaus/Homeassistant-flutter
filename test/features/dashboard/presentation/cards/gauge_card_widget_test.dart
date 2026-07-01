import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/application/connection_providers.dart';
import 'package:homeassistant_flutter/features/connection/domain/entity_state.dart';
import 'package:homeassistant_flutter/features/dashboard/domain/lovelace_card.dart';
import 'package:homeassistant_flutter/features/dashboard/presentation/cards/gauge_card_widget.dart';

EntityState _entity(
  String id, {
  required String state,
  Map<String, Object?> attributes = const {},
}) {
  return EntityState(entityId: id, state: state, attributes: attributes);
}

Widget _harness(GaugeCard card, EntityState? entity) => ProviderScope(
  overrides: [
    entityStatesProvider.overrideWith(
      (ref) => Stream.value(entity == null ? {} : {entity.entityId: entity}),
    ),
  ],
  child: MaterialApp(
    home: Scaffold(body: GaugeCardWidget(card: card)),
  ),
);

void main() {
  testWidgets('renders the numeric value and unit from entity attributes', (
    tester,
  ) async {
    const card = GaugeCard(entityId: 'sensor.humidity', name: 'Humidity');

    await tester.pumpWidget(
      _harness(
        card,
        _entity(
          'sensor.humidity',
          state: '42',
          attributes: {'unit_of_measurement': '%'},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Humidity'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('%'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('an explicit unit from the config overrides the entity unit', (
    tester,
  ) async {
    const card = GaugeCard(entityId: 'sensor.humidity', unit: 'percent');

    await tester.pumpWidget(
      _harness(
        card,
        _entity(
          'sensor.humidity',
          state: '10',
          attributes: {'unit_of_measurement': '%'},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('percent'), findsOneWidget);
    expect(find.text('%'), findsNothing);
  });

  testWidgets('clamps a value above max to the max fraction', (tester) async {
    const card = GaugeCard(entityId: 'sensor.humidity', min: 0, max: 100);

    await tester.pumpWidget(
      _harness(card, _entity('sensor.humidity', state: '150')),
    );
    await tester.pump();

    // The label still shows the raw value...
    expect(find.text('150'), findsOneWidget);
    // ...but the indicator itself is clamped to 1.0 (fully filled).
    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(indicator.value, 1.0);
  });

  testWidgets('formats whole numbers without a trailing decimal', (
    tester,
  ) async {
    const card = GaugeCard(entityId: 'sensor.humidity');

    await tester.pumpWidget(
      _harness(card, _entity('sensor.humidity', state: '50.0')),
    );
    await tester.pump();

    expect(find.text('50'), findsOneWidget);
  });

  group('severity colouring', () {
    testWidgets('value at or above red renders red', (tester) async {
      const card = GaugeCard(
        entityId: 'sensor.humidity',
        severity: GaugeSeverity(green: 0, yellow: 50, red: 80),
      );

      await tester.pumpWidget(
        _harness(card, _entity('sensor.humidity', state: '90')),
      );
      await tester.pump();

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.color, Colors.red);
    });

    testWidgets('value at or above yellow but below red renders yellow', (
      tester,
    ) async {
      const card = GaugeCard(
        entityId: 'sensor.humidity',
        severity: GaugeSeverity(green: 0, yellow: 50, red: 80),
      );

      await tester.pumpWidget(
        _harness(card, _entity('sensor.humidity', state: '60')),
      );
      await tester.pump();

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.color, Colors.amber);
    });

    testWidgets('value below yellow renders green', (tester) async {
      const card = GaugeCard(
        entityId: 'sensor.humidity',
        severity: GaugeSeverity(green: 0, yellow: 50, red: 80),
      );

      await tester.pumpWidget(
        _harness(card, _entity('sensor.humidity', state: '10')),
      );
      await tester.pump();

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.color, Colors.green);
    });

    testWidgets('no severity configured leaves the indicator uncoloured', (
      tester,
    ) async {
      const card = GaugeCard(entityId: 'sensor.humidity');

      await tester.pumpWidget(
        _harness(card, _entity('sensor.humidity', state: '90')),
      );
      await tester.pump();

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.color, isNull);
    });
  });

  testWidgets('a non-numeric state shows a placeholder instead of crashing', (
    tester,
  ) async {
    const card = GaugeCard(entityId: 'sensor.humidity');

    await tester.pumpWidget(
      _harness(card, _entity('sensor.humidity', state: 'unavailable')),
    );
    await tester.pump();

    expect(find.text('unavailable'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a missing entity shows a placeholder instead of crashing', (
    tester,
  ) async {
    const card = GaugeCard(entityId: 'sensor.missing');

    await tester.pumpWidget(_harness(card, null));
    await tester.pump();

    expect(find.text('unavailable'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
