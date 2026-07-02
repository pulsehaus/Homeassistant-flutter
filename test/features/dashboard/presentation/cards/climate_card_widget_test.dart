import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/application/connection_providers.dart';
import 'package:homeassistant_flutter/features/connection/domain/entity_state.dart';
import 'package:homeassistant_flutter/features/dashboard/domain/lovelace_card.dart';
import 'package:homeassistant_flutter/features/dashboard/presentation/cards/climate_card_widget.dart';
import 'package:homeassistant_flutter/features/entities/application/climate_control_controller.dart';

EntityState _climate(
  String id, {
  String state = 'heat',
  String? friendlyName,
  Map<String, Object?> attributes = const {},
}) {
  return EntityState(
    entityId: id,
    state: state,
    attributes: {...attributes, 'friendly_name': ?friendlyName},
  );
}

Map<String, EntityState> _store(List<EntityState> entities) {
  return {for (final e in entities) e.entityId: e};
}

/// A fake controller that records requests and returns a scripted
/// [ClimateActionResult], mirroring `button_card_widget_test.dart`'s fake
/// toggle controller.
class _FakeClimateController implements ClimateControlController {
  _FakeClimateController(this._result);

  final ClimateActionResult _result;
  final List<(String, double)> temperatureCalls = [];
  final List<(String, String)> modeCalls = [];

  @override
  Future<ClimateActionResult> setTemperature(
    EntityState entity, {
    required double temperature,
  }) async {
    temperatureCalls.add((entity.entityId, temperature));
    return _result;
  }

  @override
  Future<ClimateActionResult> setHvacMode(
    EntityState entity,
    String mode,
  ) async {
    modeCalls.add((entity.entityId, mode));
    return _result;
  }
}

Widget _harness({
  required ClimateCard card,
  required Stream<Map<String, EntityState>> stream,
  required ClimateControlController controller,
}) {
  return ProviderScope(
    overrides: [
      entityStatesProvider.overrideWith((ref) => stream),
      climateControlControllerProvider.overrideWithValue(controller),
    ],
    child: MaterialApp(
      home: Scaffold(body: ClimateCardWidget(card: card)),
    ),
  );
}

void main() {
  const card = ClimateCard(entityId: 'climate.living_room');

  testWidgets(
    'renders label, current temperature, target temperature and hvac mode',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          card: const ClimateCard(
            entityId: 'climate.living_room',
            name: 'Living Room',
          ),
          stream: Stream.value(
            _store([
              _climate(
                'climate.living_room',
                state: 'heat',
                attributes: {
                  'current_temperature': 19.5,
                  'temperature': 21.0,
                  'hvac_modes': ['off', 'heat', 'cool'],
                },
              ),
            ]),
          ),
          controller: _FakeClimateController(
            const ClimateActionResult.success(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Living Room'), findsOneWidget);
      expect(find.text('Current: 19.5°'), findsOneWidget);
      expect(find.text('21°'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsOneWidget);
    },
  );

  testWidgets('tapping + calls set_temperature with the increased target', (
    tester,
  ) async {
    final controller = _FakeClimateController(
      const ClimateActionResult.success(),
    );
    await tester.pumpWidget(
      _harness(
        card: card,
        stream: Stream.value(
          _store([
            _climate(
              'climate.living_room',
              attributes: {'temperature': 21.0, 'target_temp_step': 0.5},
            ),
          ]),
        ),
        controller: controller,
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();

    expect(controller.temperatureCalls, [('climate.living_room', 21.5)]);
    // Optimistic display updates immediately.
    expect(find.text('21.5°'), findsOneWidget);
  });

  testWidgets('tapping - calls set_temperature with the decreased target', (
    tester,
  ) async {
    final controller = _FakeClimateController(
      const ClimateActionResult.success(),
    );
    await tester.pumpWidget(
      _harness(
        card: card,
        stream: Stream.value(
          _store([
            _climate(
              'climate.living_room',
              attributes: {'temperature': 21.0, 'target_temp_step': 0.5},
            ),
          ]),
        ),
        controller: controller,
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.remove_circle_outline));
    await tester.pump();

    expect(controller.temperatureCalls, [('climate.living_room', 20.5)]);
    expect(find.text('20.5°'), findsOneWidget);
  });

  testWidgets('a failed temperature adjustment rolls back and shows a '
      'SnackBar', (tester) async {
    final controller = _FakeClimateController(
      const ClimateActionResult.failure('Could not set temperature: boom'),
    );
    await tester.pumpWidget(
      _harness(
        card: card,
        stream: Stream.value(
          _store([
            _climate('climate.living_room', attributes: {'temperature': 21.0}),
          ]),
        ),
        controller: controller,
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump(); // run the future + setState

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Could not set temperature'), findsOneWidget);
    // Rolled back to the real (unchanged) target.
    expect(find.text('21°'), findsOneWidget);
  });

  testWidgets('changing the hvac mode dropdown calls set_hvac_mode', (
    tester,
  ) async {
    final controller = _FakeClimateController(
      const ClimateActionResult.success(),
    );
    await tester.pumpWidget(
      _harness(
        card: card,
        stream: Stream.value(
          _store([
            _climate(
              'climate.living_room',
              state: 'heat',
              attributes: {
                'temperature': 21.0,
                'hvac_modes': ['off', 'heat', 'cool'],
              },
            ),
          ]),
        ),
        controller: controller,
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();

    // The dropdown menu shows each mode; tap the 'cool' entry.
    await tester.tap(find.text('cool').last);
    await tester.pumpAndSettle();

    expect(controller.modeCalls, [('climate.living_room', 'cool')]);
  });

  testWidgets('a missing entity shows a placeholder instead of crashing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        card: const ClimateCard(
          entityId: 'climate.missing',
          name: 'Missing Thermostat',
        ),
        stream: Stream.value(const <String, EntityState>{}),
        controller: _FakeClimateController(const ClimateActionResult.success()),
      ),
    );
    await tester.pump();

    expect(find.text('Missing Thermostat'), findsOneWidget);
    expect(find.text('unavailable'), findsOneWidget);
  });

  testWidgets('a missing current_temperature attribute shows "unavailable" for '
      'current but still renders the target', (tester) async {
    await tester.pumpWidget(
      _harness(
        card: card,
        stream: Stream.value(
          _store([
            _climate('climate.living_room', attributes: {'temperature': 21.0}),
          ]),
        ),
        controller: _FakeClimateController(const ClimateActionResult.success()),
      ),
    );
    await tester.pump();

    expect(find.text('Current: unavailable'), findsOneWidget);
    expect(find.text('21°'), findsOneWidget);
  });

  testWidgets(
    'a missing target temperature (e.g. off mode) disables the +/- buttons',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          card: card,
          stream: Stream.value(
            _store([_climate('climate.living_room', state: 'off')]),
          ),
          controller: _FakeClimateController(
            const ClimateActionResult.success(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('--'), findsOneWidget);
      final plus = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.add_circle_outline),
          matching: find.byType(IconButton),
        ),
      );
      expect(plus.onPressed, isNull);
    },
  );
}
