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

    // Controllable entities (light, switch) render a toggle reflecting state;
    // the sensor still shows its reading as text.
    expect(find.byType(Switch), findsNWidgets(2)); // light + switch
    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches.where((s) => s.value), hasLength(1)); // light.kitchen on
    expect(switches.where((s) => !s.value), hasLength(1)); // switch.fan off
    expect(find.text('21.4'), findsOneWidget);
  });

  testWidgets('shows the empty surface when there are no entities', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(Stream.value(const <String, EntityState>{})),
    );
    await tester.pump();

    expect(find.text('No entities yet'), findsOneWidget);
    expect(
      find.textContaining('stream in from Home Assistant'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.sensors_off), findsOneWidget);
    // Not the shared template's generic default icon.
    expect(find.byIcon(Icons.inbox_outlined), findsNothing);
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

    // Use a non-controllable entity here so the row renders its state as text
    // (controllable lights/switches now render a Switch — that live-update path
    // is covered in entity_toggle_widget_test.dart).
    controller.add(_store([_entity('sensor.temperature', state: '20.1')]));
    await tester.pump();
    expect(find.text('20.1'), findsOneWidget);
    expect(find.text('21.5'), findsNothing);

    // A state_changed event updates the reading.
    controller.add(_store([_entity('sensor.temperature', state: '21.5')]));
    await tester.pump();
    expect(find.text('21.5'), findsOneWidget);
    expect(find.text('20.1'), findsNothing);
  });

  group('search field (#77)', () {
    Widget harnessWithEntities() => _harness(
      Stream.value(
        _store([
          _entity('light.kitchen', friendlyName: 'Kitchen Light'),
          _entity('light.living_room', friendlyName: 'Living Room Lamp'),
          _entity(
            'sensor.temperature',
            state: '21.4',
            friendlyName: 'Outside Temperature',
          ),
        ]),
      ),
    );

    testWidgets('is visible above the entities list', (tester) async {
      await tester.pumpWidget(harnessWithEntities());
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search entities'), findsOneWidget);
    });

    testWidgets('typing filters entities by name, case-insensitively', (
      tester,
    ) async {
      await tester.pumpWidget(harnessWithEntities());
      await tester.pump();

      expect(find.text('Kitchen Light'), findsOneWidget);
      expect(find.text('Living Room Lamp'), findsOneWidget);
      expect(find.text('Outside Temperature'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'kitchen');
      await tester.pump();

      expect(find.text('Kitchen Light'), findsOneWidget);
      expect(find.text('Living Room Lamp'), findsNothing);
      expect(find.text('Outside Temperature'), findsNothing);
    });

    testWidgets('typing filters entities by entity id', (tester) async {
      await tester.pumpWidget(harnessWithEntities());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'sensor.temperature');
      await tester.pump();

      expect(find.text('Outside Temperature'), findsOneWidget);
      expect(find.text('Kitchen Light'), findsNothing);
      expect(find.text('Living Room Lamp'), findsNothing);
    });

    testWidgets('clearing the field restores the full list', (tester) async {
      await tester.pumpWidget(harnessWithEntities());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'kitchen');
      await tester.pump();
      expect(find.text('Living Room Lamp'), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      expect(find.text('Kitchen Light'), findsOneWidget);
      expect(find.text('Living Room Lamp'), findsOneWidget);
      expect(find.text('Outside Temperature'), findsOneWidget);
    });

    testWidgets('a query matching nothing shows a no-results message', (
      tester,
    ) async {
      await tester.pumpWidget(harnessWithEntities());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'nonexistent');
      await tester.pump();

      expect(find.text('No matching entities'), findsOneWidget);
      expect(find.text('Kitchen Light'), findsNothing);
    });
  });
}
