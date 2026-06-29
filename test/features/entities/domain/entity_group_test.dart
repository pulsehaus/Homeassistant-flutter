import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/domain/entity_state.dart';
import 'package:homeassistant_flutter/features/entities/domain/entity_group.dart';

EntityState entity(String id, {String state = 'on', String? friendlyName}) {
  return EntityState(
    entityId: id,
    state: state,
    attributes: friendlyName == null
        ? const {}
        : {'friendly_name': friendlyName},
  );
}

Map<String, EntityState> store(List<EntityState> entities) {
  return {for (final e in entities) e.entityId: e};
}

void main() {
  group('groupEntitiesByDomain', () {
    test('empty store yields no groups', () {
      expect(groupEntitiesByDomain(const {}), isEmpty);
    });

    test('groups entities by their domain', () {
      final groups = groupEntitiesByDomain(
        store([
          entity('light.kitchen'),
          entity('light.living_room'),
          entity('sensor.temperature', state: '21'),
          entity('switch.fan'),
        ]),
      );

      expect(groups.map((g) => g.domain), ['light', 'sensor', 'switch']);
      expect(groups[0].count, 2);
      expect(groups[1].count, 1);
      expect(groups[2].count, 1);
    });

    test('orders groups alphabetically by domain', () {
      final groups = groupEntitiesByDomain(
        store([
          entity('switch.fan'),
          entity('light.kitchen'),
          entity('binary_sensor.door'),
        ]),
      );

      expect(groups.map((g) => g.domain), ['binary_sensor', 'light', 'switch']);
    });

    test(
      'sorts entities within a group by friendly name, case-insensitively',
      () {
        final groups = groupEntitiesByDomain(
          store([
            entity('light.b', friendlyName: 'Zebra lamp'),
            entity('light.a', friendlyName: 'apple lamp'),
            entity('light.c', friendlyName: 'Mango lamp'),
          ]),
        );

        expect(groups.single.entities.map((e) => e.entityId), [
          'light.a', // apple
          'light.c', // Mango
          'light.b', // Zebra
        ]);
      },
    );

    test('falls back to the entity id when no friendly name is present', () {
      final groups = groupEntitiesByDomain(
        store([entity('sensor.zulu'), entity('sensor.alpha')]),
      );

      expect(groups.single.entities.map((e) => e.entityId), [
        'sensor.alpha',
        'sensor.zulu',
      ]);
    });

    test('breaks display-label ties deterministically by entity id', () {
      final groups = groupEntitiesByDomain(
        store([
          entity('light.second', friendlyName: 'Lamp'),
          entity('light.first', friendlyName: 'Lamp'),
        ]),
      );

      expect(groups.single.entities.map((e) => e.entityId), [
        'light.first',
        'light.second',
      ]);
    });

    test('treats a blank friendly name as absent', () {
      final groups = groupEntitiesByDomain(
        store([
          entity('sensor.zulu', friendlyName: '   '),
          entity('sensor.alpha', friendlyName: '   '),
        ]),
      );

      // Both fall back to the id, so they sort by id.
      expect(groups.single.entities.map((e) => e.entityId), [
        'sensor.alpha',
        'sensor.zulu',
      ]);
    });
  });

  group('EntityGroup', () {
    test('value equality compares domain and entities', () {
      final a = EntityGroup(domain: 'light', entities: [entity('light.a')]);
      final b = EntityGroup(domain: 'light', entities: [entity('light.a')]);
      final c = EntityGroup(domain: 'light', entities: [entity('light.b')]);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
