import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/application/connection_providers.dart';
import 'package:homeassistant_flutter/features/connection/domain/entity_state.dart';
import 'package:homeassistant_flutter/features/entities/presentation/entities_overview_page.dart';

EntityState _entity(String id, {String state = 'on', String? friendlyName}) {
  return EntityState(
    entityId: id,
    state: state,
    attributes: friendlyName == null
        ? const {}
        : {'friendly_name': friendlyName},
  );
}

Map<String, EntityState> _store(List<EntityState> entities) {
  return {for (final e in entities) e.entityId: e};
}

Widget _harness(Stream<Map<String, EntityState>> stream) => ProviderScope(
  overrides: [entityStatesProvider.overrideWith((ref) => stream)],
  child: const MaterialApp(home: EntitiesOverviewPage()),
);

void main() {
  testWidgets('lists entities grouped by domain with name and state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        Stream.value(
          _store([
            _entity('light.kitchen', state: 'on', friendlyName: 'Kitchen'),
            _entity(
              'sensor.temperature',
              state: '21.4',
              friendlyName: 'Temperature',
            ),
            _entity('switch.fan', state: 'off'),
          ]),
        ),
      ),
    );
    await tester.pump();

    // Title from the AppPage template.
    expect(find.text('Entities'), findsOneWidget);

    // Domain section headers (title-cased).
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Sensor'), findsOneWidget);
    expect(find.text('Switch'), findsOneWidget);

    // Friendly names + the id fallback for the unnamed switch.
    expect(find.text('Kitchen'), findsOneWidget);
    expect(find.text('Temperature'), findsOneWidget);
    expect(find.text('switch.fan'), findsWidgets);

    // Current states are shown.
    expect(find.text('on'), findsOneWidget);
    expect(find.text('21.4'), findsOneWidget);
    expect(find.text('off'), findsOneWidget);
  });

  testWidgets('shows the empty surface when there are no entities', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(Stream.value(const <String, EntityState>{})),
    );
    await tester.pump();

    expect(find.textContaining('No entities yet'), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('shows the loading surface before the first emission', (
    tester,
  ) async {
    final controller = StreamController<Map<String, EntityState>>();
    addTearDown(controller.close);

    await tester.pumpWidget(_harness(controller.stream));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the error surface when the stream errors', (tester) async {
    await tester.pumpWidget(
      _harness(Stream.error(StateError('connection lost'))),
    );
    await tester.pump();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.textContaining('connection lost'), findsOneWidget);
  });

  testWidgets('updates live as new entity states arrive', (tester) async {
    final controller = StreamController<Map<String, EntityState>>();
    addTearDown(controller.close);

    await tester.pumpWidget(_harness(controller.stream));

    controller.add(_store([_entity('light.kitchen', state: 'off')]));
    await tester.pump();
    expect(find.text('off'), findsOneWidget);
    expect(find.text('on'), findsNothing);

    // A state_changed event flips the light on.
    controller.add(_store([_entity('light.kitchen', state: 'on')]));
    await tester.pump();
    expect(find.text('on'), findsOneWidget);
    expect(find.text('off'), findsNothing);
  });
}
