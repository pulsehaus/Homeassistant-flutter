import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/domain/entity_state.dart';
import 'package:homeassistant_flutter/features/entities/domain/climate_control.dart';

EntityState _climate(
  String id, {
  String state = 'heat',
  Map<String, Object?> attributes = const {},
}) {
  return EntityState(entityId: id, state: state, attributes: attributes);
}

void main() {
  group('ClimateControl.currentTemperature', () {
    test('reads the current_temperature attribute', () {
      final entity = _climate(
        'climate.living_room',
        attributes: {'current_temperature': 21.5},
      );
      expect(ClimateControl.currentTemperature(entity), 21.5);
    });

    test('is null when the attribute is missing', () {
      expect(
        ClimateControl.currentTemperature(_climate('climate.living_room')),
        isNull,
      );
    });

    test('is null when the attribute is non-numeric', () {
      final entity = _climate(
        'climate.living_room',
        attributes: {'current_temperature': 'n/a'},
      );
      expect(ClimateControl.currentTemperature(entity), isNull);
    });
  });

  group('ClimateControl.targetTemperature', () {
    test('reads the temperature attribute', () {
      final entity = _climate(
        'climate.living_room',
        attributes: {'temperature': 22},
      );
      expect(ClimateControl.targetTemperature(entity), 22.0);
    });

    test('is null when absent (e.g. hvac_mode off, or a range-based mode)', () {
      expect(
        ClimateControl.targetTemperature(_climate('climate.living_room')),
        isNull,
      );
    });
  });

  group('ClimateControl.temperatureStep', () {
    test('reads the target_temp_step attribute', () {
      final entity = _climate(
        'climate.living_room',
        attributes: {'target_temp_step': 1.0},
      );
      expect(ClimateControl.temperatureStep(entity), 1.0);
    });

    test('defaults to 0.5 when absent', () {
      expect(
        ClimateControl.temperatureStep(_climate('climate.living_room')),
        0.5,
      );
      expect(ClimateControl.defaultTemperatureStep, 0.5);
    });
  });

  group('ClimateControl.hvacMode', () {
    test('is the entity state itself', () {
      expect(
        ClimateControl.hvacMode(_climate('climate.living_room', state: 'cool')),
        'cool',
      );
    });
  });

  group('ClimateControl.hvacModes', () {
    test('reads the hvac_modes attribute, skipping non-string entries', () {
      final entity = _climate(
        'climate.living_room',
        attributes: {
          'hvac_modes': ['off', 'heat', 'cool', 42],
        },
      );
      expect(ClimateControl.hvacModes(entity), ['off', 'heat', 'cool']);
    });

    test('is empty when absent or not a list', () {
      expect(
        ClimateControl.hvacModes(_climate('climate.living_room')),
        isEmpty,
      );
      expect(
        ClimateControl.hvacModes(
          _climate(
            'climate.living_room',
            attributes: {'hvac_modes': 'not-a-list'},
          ),
        ),
        isEmpty,
      );
    });
  });

  group('ClimateControl.setTemperatureCommand', () {
    test('builds a climate.set_temperature call targeting the entity', () {
      final entity = _climate('climate.living_room');
      final command = ClimateControl.setTemperatureCommand(
        entity,
        temperature: 21.5,
      );

      expect(command.domain, 'climate');
      expect(command.service, 'set_temperature');
      expect(command.serviceData, {'temperature': 21.5});
      expect(command.target, {'entity_id': 'climate.living_room'});
    });
  });

  group('ClimateControl.setHvacModeCommand', () {
    test('builds a climate.set_hvac_mode call targeting the entity', () {
      final entity = _climate('climate.living_room');
      final command = ClimateControl.setHvacModeCommand(entity, 'cool');

      expect(command.domain, 'climate');
      expect(command.service, 'set_hvac_mode');
      expect(command.serviceData, {'hvac_mode': 'cool'});
      expect(command.target, {'entity_id': 'climate.living_room'});
    });
  });

  test('ClimateCommand uses value equality', () {
    final a = ClimateControl.setTemperatureCommand(
      _climate('climate.living_room'),
      temperature: 21,
    );
    final b = ClimateControl.setTemperatureCommand(
      _climate('climate.living_room'),
      temperature: 21,
    );
    final c = ClimateControl.setTemperatureCommand(
      _climate('climate.living_room'),
      temperature: 22,
    );

    expect(a, b);
    expect(a, isNot(c));
  });
}
