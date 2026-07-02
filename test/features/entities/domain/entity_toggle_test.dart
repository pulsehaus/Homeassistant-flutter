import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/domain/entity_state.dart';
import 'package:homeassistant_flutter/features/entities/domain/entity_toggle.dart';

EntityState _entity(
  String id, {
  String state = 'on',
  Map<String, Object?> attributes = const {},
}) => EntityState(entityId: id, state: state, attributes: attributes);

void main() {
  group('isToggleable', () {
    test('is true for lights and switches', () {
      expect(EntityToggle.isToggleable(_entity('light.kitchen')), isTrue);
      expect(EntityToggle.isToggleable(_entity('switch.fan')), isTrue);
    });

    test('is false for non-controllable domains', () {
      expect(EntityToggle.isToggleable(_entity('sensor.temp')), isFalse);
      expect(EntityToggle.isToggleable(_entity('binary_sensor.door')), isFalse);
      expect(EntityToggle.isToggleable(_entity('climate.living')), isFalse);
    });
  });

  group('isOn', () {
    test('is true only for the canonical "on" state', () {
      expect(EntityToggle.isOn(_entity('light.kitchen', state: 'on')), isTrue);
    });

    test('is false for off and any non-on state', () {
      expect(
        EntityToggle.isOn(_entity('light.kitchen', state: 'off')),
        isFalse,
      );
      expect(
        EntityToggle.isOn(_entity('light.kitchen', state: 'unavailable')),
        isFalse,
      );
      expect(
        EntityToggle.isOn(_entity('light.kitchen', state: 'unknown')),
        isFalse,
      );
    });
  });

  group('toggleCommand', () {
    test('maps a light turn_on to light.turn_on with the entity target', () {
      final command = EntityToggle.toggleCommand(
        _entity('light.kitchen', state: 'off'),
        on: true,
      );

      expect(command.domain, 'light');
      expect(command.service, 'turn_on');
      expect(command.target, {'entity_id': 'light.kitchen'});
    });

    test(
      'maps a switch turn_off to switch.turn_off with the entity target',
      () {
        final command = EntityToggle.toggleCommand(
          _entity('switch.fan', state: 'on'),
          on: false,
        );

        expect(command.domain, 'switch');
        expect(command.service, 'turn_off');
        expect(command.target, {'entity_id': 'switch.fan'});
      },
    );

    test('throws for a non-toggleable entity', () {
      expect(
        () => EntityToggle.toggleCommand(_entity('sensor.temp'), on: true),
        throwsArgumentError,
      );
    });
  });

  group('ToggleCommand equality', () {
    test('equal commands compare equal', () {
      const a = ToggleCommand(
        domain: 'light',
        service: 'turn_on',
        target: {'entity_id': 'light.kitchen'},
      );
      const b = ToggleCommand(
        domain: 'light',
        service: 'turn_on',
        target: {'entity_id': 'light.kitchen'},
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('commands with different data are not equal', () {
      const a = ToggleCommand(
        domain: 'light',
        service: 'turn_on',
        target: {'entity_id': 'light.kitchen'},
        data: {'brightness': 100},
      );
      const b = ToggleCommand(
        domain: 'light',
        service: 'turn_on',
        target: {'entity_id': 'light.kitchen'},
        data: {'brightness': 200},
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('isDimmable', () {
    test('is true for a light reporting a brightness attribute', () {
      expect(
        EntityToggle.isDimmable(
          _entity('light.kitchen', attributes: {'brightness': 128}),
        ),
        isTrue,
      );
    });

    test('is false for a light without a brightness attribute', () {
      expect(EntityToggle.isDimmable(_entity('light.kitchen')), isFalse);
    });

    test('is false for a light with a null brightness attribute', () {
      expect(
        EntityToggle.isDimmable(
          _entity('light.kitchen', attributes: {'brightness': null}),
        ),
        isFalse,
      );
    });

    test('is false for non-light domains even with a brightness attribute', () {
      expect(
        EntityToggle.isDimmable(
          _entity('switch.fan', attributes: {'brightness': 128}),
        ),
        isFalse,
      );
    });
  });

  group('brightness', () {
    test('reads the numeric brightness attribute', () {
      expect(
        EntityToggle.brightness(
          _entity('light.kitchen', attributes: {'brightness': 200}),
        ),
        200,
      );
    });

    test('rounds a non-integer brightness attribute', () {
      expect(
        EntityToggle.brightness(
          _entity('light.kitchen', attributes: {'brightness': 199.6}),
        ),
        200,
      );
    });

    test('is null when the attribute is missing', () {
      expect(EntityToggle.brightness(_entity('light.kitchen')), isNull);
    });
  });

  group('brightnessCommand', () {
    test('maps to light.turn_on with brightness in data', () {
      final command = EntityToggle.brightnessCommand(
        _entity('light.kitchen', attributes: {'brightness': 50}),
        128,
      );

      expect(command.domain, 'light');
      expect(command.service, 'turn_on');
      expect(command.target, {'entity_id': 'light.kitchen'});
      expect(command.data, {'brightness': 128});
    });

    test('clamps the brightness to the valid 0-255 range', () {
      final tooHigh = EntityToggle.brightnessCommand(
        _entity('light.kitchen', attributes: {'brightness': 50}),
        999,
      );
      expect(tooHigh.data, {'brightness': 255});

      final tooLow = EntityToggle.brightnessCommand(
        _entity('light.kitchen', attributes: {'brightness': 50}),
        -10,
      );
      expect(tooLow.data, {'brightness': 0});
    });

    test('throws for a non-light entity', () {
      expect(
        () => EntityToggle.brightnessCommand(_entity('switch.fan'), 128),
        throwsArgumentError,
      );
    });
  });
}
