import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/domain/entity_state.dart';

void main() {
  group('EntityState.fromJson', () {
    test('parses a full state object', () {
      final entity = EntityState.fromJson({
        'entity_id': 'light.kitchen',
        'state': 'on',
        'attributes': {'friendly_name': 'Kitchen', 'brightness': 200},
        'last_changed': '2024-01-01T10:00:00+00:00',
        'last_updated': '2024-01-01T10:05:00+00:00',
      });

      expect(entity.entityId, 'light.kitchen');
      expect(entity.state, 'on');
      expect(entity.domain, 'light');
      expect(entity.friendlyName, 'Kitchen');
      expect(entity.attributes['brightness'], 200);
      expect(entity.lastChanged, DateTime.utc(2024, 1, 1, 10, 0, 0));
      expect(entity.lastUpdated, DateTime.utc(2024, 1, 1, 10, 5, 0));
    });

    test('tolerates missing optional fields', () {
      final entity = EntityState.fromJson({'entity_id': 'sensor.temp'});

      expect(entity.state, 'unknown');
      expect(entity.attributes, isEmpty);
      expect(entity.friendlyName, isNull);
      expect(entity.lastChanged, isNull);
      expect(entity.lastUpdated, isNull);
    });

    test('ignores an unparseable timestamp', () {
      final entity = EntityState.fromJson({
        'entity_id': 'sensor.temp',
        'state': '21',
        'last_updated': 'not-a-date',
      });

      expect(entity.lastUpdated, isNull);
    });
  });

  group('EntityState equality', () {
    EntityState build({String state = 'on', String? updated}) =>
        EntityState.fromJson({
          'entity_id': 'light.kitchen',
          'state': state,
          'last_updated': updated,
        });

    test('equal when id, state and last_updated match', () {
      expect(
        build(updated: '2024-01-01T10:00:00Z'),
        equals(build(updated: '2024-01-01T10:00:00Z')),
      );
    });

    test('differs when the state changes', () {
      expect(
        build(state: 'on', updated: '2024-01-01T10:00:00Z'),
        isNot(equals(build(state: 'off', updated: '2024-01-01T10:00:00Z'))),
      );
    });

    test('differs when last_updated changes', () {
      expect(
        build(updated: '2024-01-01T10:00:00Z'),
        isNot(equals(build(updated: '2024-01-01T10:05:00Z'))),
      );
    });
  });
}
