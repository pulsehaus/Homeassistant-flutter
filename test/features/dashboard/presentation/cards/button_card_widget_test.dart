import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/application/connection_providers.dart';
import 'package:homeassistant_flutter/features/connection/domain/entity_state.dart';
import 'package:homeassistant_flutter/features/dashboard/domain/lovelace_card.dart';
import 'package:homeassistant_flutter/features/dashboard/presentation/cards/button_card_widget.dart';
import 'package:homeassistant_flutter/features/entities/application/entity_toggle_controller.dart';
import 'package:material_design_icons_flutter/icon_map.dart';

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
/// [ToggleResult], mirroring `entity_toggle_widget_test.dart`'s fake so the
/// button card's tap-to-toggle can be driven without a real WebSocket client.
class _FakeToggleController implements EntityToggleController {
  _FakeToggleController(this._result);

  final ToggleResult _result;
  final List<(String, bool)> calls = [];

  @override
  Future<ToggleResult> toggle(EntityState entity, {required bool on}) async {
    calls.add((entity.entityId, on));
    return _result;
  }

  @override
  Future<ToggleResult> setBrightness(EntityState entity, int brightness) async {
    return _result;
  }
}

Widget _harness({
  required ButtonCard card,
  required Stream<Map<String, EntityState>> stream,
  required EntityToggleController controller,
}) {
  return ProviderScope(
    overrides: [
      entityStatesProvider.overrideWith((ref) => stream),
      entityToggleControllerProvider.overrideWithValue(controller),
    ],
    child: MaterialApp(
      home: Scaffold(body: ButtonCardWidget(card: card)),
    ),
  );
}

void main() {
  testWidgets('renders the resolved label and, when enabled, the state text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        card: const ButtonCard(entityId: 'light.kitchen', showState: true),
        stream: Stream.value(
          _store([
            _entity('light.kitchen', state: 'on', friendlyName: 'Kitchen'),
          ]),
        ),
        controller: _FakeToggleController(const ToggleResult.success()),
      ),
    );
    await tester.pump();

    expect(find.text('Kitchen'), findsOneWidget);
    expect(find.text('on'), findsOneWidget);
  });

  testWidgets('an explicit name wins over the entity friendly name', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        card: const ButtonCard(
          entityId: 'light.kitchen',
          name: 'Kitchen light',
        ),
        stream: Stream.value(
          _store([
            _entity('light.kitchen', state: 'on', friendlyName: 'Kitchen'),
          ]),
        ),
        controller: _FakeToggleController(const ToggleResult.success()),
      ),
    );
    await tester.pump();

    expect(find.text('Kitchen light'), findsOneWidget);
    expect(find.text('Kitchen'), findsNothing);
  });

  testWidgets('show_name: false hides the label', (tester) async {
    await tester.pumpWidget(
      _harness(
        card: const ButtonCard(entityId: 'light.kitchen', showName: false),
        stream: Stream.value(
          _store([
            _entity('light.kitchen', state: 'on', friendlyName: 'Kitchen'),
          ]),
        ),
        controller: _FakeToggleController(const ToggleResult.success()),
      ),
    );
    await tester.pump();

    expect(find.text('Kitchen'), findsNothing);
  });

  testWidgets('tapping a toggleable entity calls the controller to flip it', (
    tester,
  ) async {
    final controller = _FakeToggleController(const ToggleResult.success());
    await tester.pumpWidget(
      _harness(
        card: const ButtonCard(entityId: 'light.kitchen'),
        stream: Stream.value(_store([_entity('light.kitchen', state: 'off')])),
        controller: controller,
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(InkWell));
    await tester.pump();

    expect(controller.calls, [('light.kitchen', true)]);
  });

  testWidgets('a failed toggle surfaces a SnackBar', (tester) async {
    final controller = _FakeToggleController(
      const ToggleResult.failure('Could not turn on light.kitchen: boom'),
    );
    await tester.pumpWidget(
      _harness(
        card: const ButtonCard(entityId: 'light.kitchen'),
        stream: Stream.value(_store([_entity('light.kitchen', state: 'off')])),
        controller: controller,
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(InkWell));
    await tester.pump(); // run the toggle future + setState

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Could not turn on'), findsOneWidget);
  });

  testWidgets(
    'tapping a non-toggleable entity does nothing (no crash, no call)',
    (tester) async {
      final controller = _FakeToggleController(const ToggleResult.success());
      await tester.pumpWidget(
        _harness(
          card: const ButtonCard(entityId: 'sensor.temperature'),
          stream: Stream.value(
            _store([_entity('sensor.temperature', state: '21.4')]),
          ),
          controller: controller,
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(controller.calls, isEmpty);
    },
  );

  testWidgets(
    'tapping an entity-less button does nothing (no crash, no call)',
    (tester) async {
      final controller = _FakeToggleController(const ToggleResult.success());
      await tester.pumpWidget(
        _harness(
          card: const ButtonCard(name: 'Go to garage'),
          stream: Stream.value(const <String, EntityState>{}),
          controller: controller,
        ),
      );
      await tester.pump();

      expect(find.text('Go to garage'), findsOneWidget);

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(controller.calls, isEmpty);
    },
  );

  testWidgets('falls back to "Button" when neither name nor entity is set', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        card: const ButtonCard(),
        stream: Stream.value(const <String, EntityState>{}),
        controller: _FakeToggleController(const ToggleResult.success()),
      ),
    );
    await tester.pump();

    expect(find.text('Button'), findsOneWidget);
  });

  testWidgets('a resolvable mdi:xxx icon renders the real MDI icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        card: const ButtonCard(
          entityId: 'sensor.humidity',
          icon: 'mdi:water-pump',
        ),
        stream: Stream.value(_store([_entity('sensor.humidity')])),
        controller: _FakeToggleController(const ToggleResult.success()),
      ),
    );
    await tester.pump();

    expect(find.byIcon(iconMap['waterPump']!), findsOneWidget);
  });

  testWidgets('an unresolvable icon name falls back gracefully (no crash)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        card: const ButtonCard(
          entityId: 'light.kitchen',
          icon: 'mdi:not-a-real-icon-name',
        ),
        stream: Stream.value(_store([_entity('light.kitchen', state: 'off')])),
        controller: _FakeToggleController(const ToggleResult.success()),
      ),
    );
    await tester.pump();

    // Falls back to the domain-based default for 'light', same as when no
    // icon is configured at all.
    expect(find.byIcon(Icons.lightbulb_outline), findsOneWidget);
  });

  testWidgets('no icon configured keeps the domain-based fallback behaviour', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        card: const ButtonCard(entityId: 'light.kitchen'),
        stream: Stream.value(_store([_entity('light.kitchen', state: 'off')])),
        controller: _FakeToggleController(const ToggleResult.success()),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.lightbulb_outline), findsOneWidget);
  });

  testWidgets('reflects a live state_changed update', (tester) async {
    final controller = StreamController<Map<String, EntityState>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      _harness(
        card: const ButtonCard(entityId: 'light.kitchen', showState: true),
        stream: controller.stream,
        controller: _FakeToggleController(const ToggleResult.success()),
      ),
    );

    controller.add(_store([_entity('light.kitchen', state: 'off')]));
    await tester.pump();
    expect(find.text('off'), findsOneWidget);

    controller.add(_store([_entity('light.kitchen', state: 'on')]));
    // ButtonCardWidget is a ConsumerStatefulWidget, so the provider
    // listener's notification lands one microtask later than a
    // ConsumerWidget's — a second pump lets that settle before asserting.
    await tester.pump();
    await tester.pump();
    expect(find.text('on'), findsOneWidget);
  });
}
