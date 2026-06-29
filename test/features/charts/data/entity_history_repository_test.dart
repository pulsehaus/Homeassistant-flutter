import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/charts/data/entity_history_repository.dart';
import 'package:homeassistant_flutter/features/connection/data/ha_rest_client.dart';
import 'package:homeassistant_flutter/features/connection/domain/ha_connection_config.dart';
import 'package:homeassistant_flutter/features/connection/domain/ha_exception.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _config = HaConnectionConfig(
  baseUrl: Uri.parse('http://localhost:8123'),
  accessToken: 'test-token',
);

EntityHistoryRepository _repoReturning(
  Future<http.Response> Function(http.Request request) handler,
) => EntityHistoryRepository(
  HaRestClient(config: _config, httpClient: MockClient(handler)),
);

void main() {
  group('EntityHistoryRepository.fetchSeries', () {
    test('hits the history endpoint with auth, entity filter and time window, '
        'then maps the payload to a ChartSeries', () async {
      late http.Request captured;
      final repo = _repoReturning((request) async {
        captured = request;
        return http.Response(
          jsonEncode([
            [
              {
                'state': '21.4',
                'last_changed': '2026-06-29T10:00:00+00:00',
                'attributes': {
                  'unit_of_measurement': '°C',
                  'friendly_name': 'Living room',
                },
              },
              {'state': '22.0', 'last_changed': '2026-06-29T11:00:00+00:00'},
            ],
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final now = DateTime.utc(2026, 6, 29, 12);
      final series = await repo.fetchSeries(
        'sensor.living_room_temperature',
        period: const Duration(hours: 24),
        now: now,
      );

      // Endpoint + bearer token come from the connection layer's REST client.
      expect(captured.url.path, '/api/history/period/2026-06-28T12:00:00.000Z');
      expect(
        captured.url.queryParameters['filter_entity_id'],
        'sensor.living_room_temperature',
      );
      expect(
        captured.url.queryParameters.containsKey('minimal_response'),
        isTrue,
      );
      expect(
        captured.url.queryParameters['end_time'],
        '2026-06-29T12:00:00.000Z',
      );
      expect(captured.headers['Authorization'], 'Bearer test-token');

      // Mapping result.
      expect(series.name, 'Living room');
      expect(series.unit, '°C');
      expect(series.points.map((p) => p.value), [21.4, 22.0]);
    });

    test('returns an empty series when HA has no history', () async {
      final repo = _repoReturning(
        (_) async => http.Response(jsonEncode([]), 200),
      );

      final series = await repo.fetchSeries('sensor.temp');

      expect(series.points, isEmpty);
    });

    test('propagates auth failures from the REST client', () async {
      final repo = _repoReturning((_) async => http.Response('', 401));

      await expectLater(
        repo.fetchSeries('sensor.temp'),
        throwsA(isA<HaAuthException>()),
      );
    });
  });
}
