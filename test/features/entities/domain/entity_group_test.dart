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

  group('filterEntityGroups', () {
    late List<EntityGroup> groups;

    setUp(() {
      groups = groupEntitiesByDomain(
        store([
          entity('light.kitchen', friendlyName: 'Kitchen Light'),
          entity('light.living_room', friendlyName: 'Living Room Lamp'),
          entity('sensor.temperature', friendlyName: 'Outside Temperature'),
          entity('switch.fan'),
        ]),
      );
    });

    test('a blank query returns the groups unchanged', () {
      expect(filterEntityGroups(groups, ''), same(groups));
      expect(filterEntityGroups(groups, '   '), same(groups));
    });

    test('matches by friendly name, case-insensitively', () {
      final filtered = filterEntityGroups(groups, 'kitchen');

      expect(filtered.map((g) => g.domain), ['light']);
      expect(filtered.single.entities.map((e) => e.entityId), [
        'light.kitchen',
      ]);
    });

    test('matches by entity id when no friendly name matches', () {
      final filtered = filterEntityGroups(groups, 'switch.fan');

      expect(filtered.single.entities.map((e) => e.entityId), ['switch.fan']);
    });

    test('matches a substring anywhere in the name or id', () {
      final filtered = filterEntityGroups(groups, 'temp');

      expect(filtered.single.domain, 'sensor');
      expect(filtered.single.entities.single.entityId, 'sensor.temperature');
    });

    test('drops groups that end up with no matching entities', () {
      final filtered = filterEntityGroups(groups, 'kitchen');

      expect(filtered.map((g) => g.domain), isNot(contains('sensor')));
      expect(filtered.map((g) => g.domain), isNot(contains('switch')));
    });

    test('a query matching nothing returns an empty list', () {
      expect(filterEntityGroups(groups, 'nonexistent'), isEmpty);
    });

    test('a query matching multiple groups keeps all of them', () {
      final filtered = filterEntityGroups(groups, 'light');

      // "light" matches the light domain's friendly names AND
      // sensor.temperature's entity id is unaffected, but light.* entity ids
      // themselves contain "light.".
      expect(filtered.map((g) => g.domain), ['light']);
      expect(filtered.single.count, 2);
    });
  });
}
