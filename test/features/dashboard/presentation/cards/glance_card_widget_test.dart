import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/application/connection_providers.dart';
import 'package:homeassistant_flutter/features/connection/domain/entity_state.dart';
import 'package:homeassistant_flutter/features/dashboard/domain/lovelace_card.dart';
import 'package:homeassistant_flutter/features/dashboard/presentation/cards/glance_card_widget.dart';

Widget _harness(GlanceCard card, Map<String, EntityState> states) =>
    ProviderScope(
      overrides: [
        entityProvider.overrideWith((ref, entityId) => states[entityId]),
      ],
      child: MaterialApp(
        home: Scaffold(body: GlanceCardWidget(card: card)),
      ),
    );

EntityState _entity(String id, String state, {String? friendlyName}) =>
    EntityState(
      entityId: id,
      state: state,
      attributes: friendlyName == null
          ? const {}
          : {'friendly_name': friendlyName},
    );

void main() {
  testWidgets('renders a grid of tiles with title, icon, name and state', (
    tester,
  ) async {
    const card = GlanceCard(
      title: 'Overview',
      rows: [
        EntitiesRow(entityId: 'light.kitchen'),
        EntitiesRow(entityId: 'light.living', name: 'Living Room'),
      ],
    );

    await tester.pumpWidget(
      _harness(card, {
        'light.kitchen': _entity(
          'light.kitchen',
          'on',
          friendlyName: 'Kitchen Light',
        ),
        'light.living': _entity('light.living', 'off'),
      }),
    );

    expect(find.text('Overview'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('Kitchen Light'), findsOneWidget);
    expect(find.text('Living Room'), findsOneWidget);
    expect(find.text('on'), findsOneWidget);
    expect(find.text('off'), findsOneWidget);
    // Icons are rendered per-tile (show_icon defaults to true).
    expect(find.byType(Icon), findsNWidgets(2));
  });

  testWidgets('falls back to entity id and "unavailable" when unknown', (
    tester,
  ) async {
    const card = GlanceCard(rows: [EntitiesRow(entityId: 'light.unknown')]);

    await tester.pumpWidget(_harness(card, const {}));

    expect(find.text('light.unknown'), findsOneWidget);
    expect(find.text('unavailable'), findsOneWidget);
  });

  testWidgets('show_name false hides the entity label', (tester) async {
    const card = GlanceCard(
      rows: [EntitiesRow(entityId: 'light.kitchen')],
      showName: false,
    );

    await tester.pumpWidget(
      _harness(card, {
        'light.kitchen': _entity(
          'light.kitchen',
          'on',
          friendlyName: 'Kitchen Light',
        ),
      }),
    );

    expect(find.text('Kitchen Light'), findsNothing);
    expect(find.text('on'), findsOneWidget);
  });

  testWidgets('show_icon false hides the icon', (tester) async {
    const card = GlanceCard(
      rows: [EntitiesRow(entityId: 'light.kitchen')],
      showIcon: false,
    );

    await tester.pumpWidget(_harness(card, const {}));

    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('show_state false hides the state text', (tester) async {
    const card = GlanceCard(
      rows: [EntitiesRow(entityId: 'light.kitchen')],
      showState: false,
    );

    await tester.pumpWidget(
      _harness(card, {'light.kitchen': _entity('light.kitchen', 'on')}),
    );

    expect(find.text('on'), findsNothing);
  });

  testWidgets('no title omits the heading', (tester) async {
    const card = GlanceCard(rows: [EntitiesRow(entityId: 'light.kitchen')]);

    await tester.pumpWidget(_harness(card, const {}));

    expect(find.byType(Text), findsWidgets);
    expect(find.textContaining('Overview'), findsNothing);
  });
}
