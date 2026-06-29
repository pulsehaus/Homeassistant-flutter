import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/domain/entity_state.dart';
import 'package:homeassistant_flutter/features/entities/domain/entity_toggle.dart';

EntityState _entity(String id, {String state = 'on'}) =>
    EntityState(entityId: id, state: state);

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
  });
}
