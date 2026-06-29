import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/application/connection_providers.dart';
import 'package:homeassistant_flutter/features/connection/domain/entity_state.dart';
import 'package:homeassistant_flutter/features/entities/application/entity_toggle_controller.dart';
import 'package:homeassistant_flutter/features/entities/presentation/entities_overview_page.dart';

EntityState _entity(String id, {String state = 'off', String? friendlyName}) {
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

/// A fake controller that records toggle requests and returns a scripted
/// [ToggleResult], so widget tests can drive the UI without a real client.
///
/// Implements [EntityToggleController] (rather than subclassing it) so it
/// doesn't need a WebSocket client; the widget only calls [toggle].
class _FakeToggleController implements EntityToggleController {
  _FakeToggleController(this._result);

  final ToggleResult _result;
  final List<(String, bool)> calls = [];

  @override
  Future<ToggleResult> toggle(EntityState entity, {required bool on}) async {
    calls.add((entity.entityId, on));
    return _result;
  }
}

Widget _harness({
  required Stream<Map<String, EntityState>> stream,
  required EntityToggleController controller,
}) {
  return ProviderScope(
    overrides: [
      entityStatesProvider.overrideWith((ref) => stream),
      entityToggleControllerProvider.overrideWithValue(controller),
    ],
    child: const MaterialApp(home: EntitiesOverviewPage()),
  );
}

void main() {
  testWidgets('shows a Switch for lights and switches, text for others', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        stream: Stream.value(
          _store([
            _entity('light.kitchen', state: 'off', friendlyName: 'Kitchen'),
            _entity('switch.fan', state: 'on'),
            _entity('sensor.temp', state: '21.4', friendlyName: 'Temp'),
          ]),
        ),
        controller: _FakeToggleController(const ToggleResult.success()),
      ),
    );
    await tester.pump();

    // A light (off) and a switch (on) each get a Switch; the sensor does not.
    expect(find.byType(Switch), findsNWidgets(2));
    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches.where((s) => s.value == false), hasLength(1)); // light off
    expect(switches.where((s) => s.value == true), hasLength(1)); // switch on

    // The sensor still renders its state as text.
    expect(find.text('21.4'), findsOneWidget);
  });

  testWidgets('tapping the switch calls the controller to turn the light on', (
    tester,
  ) async {
    final controller = _FakeToggleController(const ToggleResult.success());
    await tester.pumpWidget(
      _harness(
        stream: Stream.value(_store([_entity('light.kitchen', state: 'off')])),
        controller: controller,
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(controller.calls, [('light.kitchen', true)]);
  });

  testWidgets('a failed toggle surfaces a SnackBar and rolls the switch back', (
    tester,
  ) async {
    final controller = _FakeToggleController(
      const ToggleResult.failure('Could not turn on light.kitchen: boom'),
    );
    await tester.pumpWidget(
      _harness(
        stream: Stream.value(_store([_entity('light.kitchen', state: 'off')])),
        controller: controller,
      ),
    );
    await tester.pump();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pump(); // run the toggle future + setState

    // Error surfaced.
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Could not turn on'), findsOneWidget);

    // Optimistic position rolled back to the real (off) state.
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('switch reflects a live state_changed update', (tester) async {
    final controller = StreamController<Map<String, EntityState>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      _harness(
        stream: controller.stream,
        controller: _FakeToggleController(const ToggleResult.success()),
      ),
    );

    controller.add(_store([_entity('light.kitchen', state: 'off')]));
    await tester.pump();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    // A state_changed event flips the light on; the switch follows.
    controller.add(_store([_entity('light.kitchen', state: 'on')]));
    await tester.pump();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });
}
