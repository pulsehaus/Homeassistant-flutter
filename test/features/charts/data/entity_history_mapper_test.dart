import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/charts/data/entity_history_mapper.dart';

void main() {
  group('EntityHistoryMapper.toSeries', () {
    test('maps a full HA history payload to a ChartSeries', () {
      final payload = [
        [
          {
            'state': '21.4',
            'last_changed': '2026-06-29T10:00:00+00:00',
            'attributes': {
              'unit_of_measurement': '°C',
              'friendly_name': 'Living room',
            },
          },
          {'state': '21.9', 'last_changed': '2026-06-29T11:00:00+00:00'},
          {'state': '22.3', 'last_changed': '2026-06-29T12:00:00+00:00'},
        ],
      ];

      final series = EntityHistoryMapper.toSeries(
        payload,
        'sensor.living_room_temperature',
      );

      expect(series.name, 'Living room');
      expect(series.unit, '°C');
      expect(series.points, hasLength(3));
      expect(series.points.first.value, 21.4);
      expect(series.points.first.time, DateTime.utc(2026, 6, 29, 10));
      expect(series.points.last.value, 22.3);
    });

    test('falls back to entity id when no friendly_name is present', () {
      final payload = [
        [
          {'state': '5', 'last_changed': '2026-06-29T10:00:00+00:00'},
        ],
      ];

      final series = EntityHistoryMapper.toSeries(payload, 'sensor.count');

      expect(series.name, 'sensor.count');
      expect(series.unit, isNull);
      expect(series.points.single.value, 5);
    });

    test('uses the supplied fallbackName over the entity id', () {
      final payload = [
        [
          {'state': '5', 'last_changed': '2026-06-29T10:00:00+00:00'},
        ],
      ];

      final series = EntityHistoryMapper.toSeries(
        payload,
        'sensor.count',
        fallbackName: 'Counter',
      );

      expect(series.name, 'Counter');
    });

    test('skips non-numeric and malformed states', () {
      final payload = [
        [
          {
            'state': '21.4',
            'last_changed': '2026-06-29T10:00:00+00:00',
            'attributes': {'unit_of_measurement': '°C'},
          },
          {'state': 'unavailable', 'last_changed': '2026-06-29T10:30:00+00:00'},
          {'state': 'unknown', 'last_changed': '2026-06-29T10:45:00+00:00'},
          {'state': '22.0', 'last_changed': '2026-06-29T11:00:00+00:00'},
          // No timestamp -> skipped.
          {'state': '99.9'},
        ],
      ];

      final series = EntityHistoryMapper.toSeries(payload, 'sensor.temp');

      expect(series.points.map((p) => p.value), [21.4, 22.0]);
    });

    test('returns an empty series for an empty payload', () {
      final series = EntityHistoryMapper.toSeries(const [], 'sensor.temp');

      expect(series.name, 'sensor.temp');
      expect(series.points, isEmpty);
    });

    test('returns an empty series when the entity has no recorded history', () {
      // HA answers `[[]]` when the entity exists but has no history in range.
      final series = EntityHistoryMapper.toSeries([<dynamic>[]], 'sensor.temp');

      expect(series.points, isEmpty);
    });

    test('accepts numeric states and epoch-second timestamps', () {
      final payload = [
        [
          {'state': 1, 'lu': 1751191200}, // 2025-06-29T10:00:00Z
          {'state': 2, 'lu': 1751194800}, // 2025-06-29T11:00:00Z
        ],
      ];

      final series = EntityHistoryMapper.toSeries(payload, 'sensor.count');

      expect(series.points.map((p) => p.value), [1.0, 2.0]);
      expect(series.points.first.time.isUtc, isTrue);
      expect(
        series.points.first.time,
        DateTime.fromMillisecondsSinceEpoch(1751191200 * 1000, isUtc: true),
      );
    });

    test('sorts out-of-order entries chronologically', () {
      final payload = [
        [
          {'state': '3', 'last_changed': '2026-06-29T12:00:00+00:00'},
          {'state': '1', 'last_changed': '2026-06-29T10:00:00+00:00'},
          {'state': '2', 'last_changed': '2026-06-29T11:00:00+00:00'},
        ],
      ];

      final series = EntityHistoryMapper.toSeries(payload, 'sensor.temp');

      expect(series.points.map((p) => p.value), [1.0, 2.0, 3.0]);
    });
  });
}
