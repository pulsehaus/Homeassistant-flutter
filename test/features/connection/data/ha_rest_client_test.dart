import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/data/ha_rest_client.dart';
import 'package:homeassistant_flutter/features/connection/domain/ha_connection_config.dart';
import 'package:homeassistant_flutter/features/connection/domain/ha_exception.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _config = HaConnectionConfig(
  baseUrl: Uri.parse('http://localhost:8123'),
  accessToken: 'test-token',
);

HaRestClient _clientReturning(
  Future<http.Response> Function(http.Request request) handler,
) => HaRestClient(config: _config, httpClient: MockClient(handler));

void main() {
  group('HaRestClient', () {
    test('attaches the bearer token and parses /states', () async {
      late http.Request captured;
      final client = _clientReturning((request) async {
        captured = request;
        return http.Response(
          jsonEncode([
            {'entity_id': 'light.kitchen', 'state': 'on'},
            {'entity_id': 'sensor.temp', 'state': '21.5'},
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final states = await client.fetchStates();

      expect(captured.url.toString(), 'http://localhost:8123/api/states');
      expect(captured.headers['Authorization'], 'Bearer test-token');
      expect(states, hasLength(2));
      expect(states.first.entityId, 'light.kitchen');
    });

    test('fetchState targets the right endpoint', () async {
      late Uri url;
      final client = _clientReturning((request) async {
        url = request.url;
        return http.Response(
          jsonEncode({'entity_id': 'light.kitchen', 'state': 'on'}),
          200,
        );
      });

      final state = await client.fetchState('light.kitchen');

      expect(url.toString(), 'http://localhost:8123/api/states/light.kitchen');
      expect(state.state, 'on');
    });

    test(
      'callService posts to the service endpoint with a JSON body',
      () async {
        late http.Request captured;
        final client = _clientReturning((request) async {
          captured = request;
          return http.Response(jsonEncode([]), 200);
        });

        await client.callService(
          'light',
          'turn_on',
          data: {'entity_id': 'light.kitchen'},
        );

        expect(captured.method, 'POST');
        expect(
          captured.url.toString(),
          'http://localhost:8123/api/services/light/turn_on',
        );
        expect(jsonDecode(captured.body), {'entity_id': 'light.kitchen'});
      },
    );

    test('ping returns true on 200', () async {
      final client = _clientReturning(
        (_) async => http.Response('{"message": "API running."}', 200),
      );
      expect(await client.ping(), isTrue);
    });

    test('maps 401 to a HaAuthException', () async {
      final client = _clientReturning((_) async => http.Response('', 401));
      await expectLater(client.fetchStates(), throwsA(isA<HaAuthException>()));
    });

    test(
      'maps other errors to a HaRestException with the status code',
      () async {
        final client = _clientReturning((_) async => http.Response('', 500));
        await expectLater(
          client.fetchStates(),
          throwsA(
            isA<HaRestException>().having(
              (e) => e.statusCode,
              'statusCode',
              500,
            ),
          ),
        );
      },
    );

    test('maps a transport failure to a HaConnectionException', () async {
      final client = _clientReturning(
        (_) async => throw http.ClientException('network down'),
      );
      await expectLater(
        client.fetchStates(),
        throwsA(isA<HaConnectionException>()),
      );
    });

    test('maps a non-JSON 2xx body to a HaRestException', () async {
      final client = _clientReturning(
        (_) async => http.Response('not json', 200),
      );
      await expectLater(client.fetchStates(), throwsA(isA<HaRestException>()));
    });

    test(
      'updateAccessToken changes the bearer header on future requests',
      () async {
        late http.Request captured;
        final client = _clientReturning((request) async {
          captured = request;
          return http.Response(jsonEncode([]), 200);
        });

        client.updateAccessToken('refreshed-token');
        await client.fetchStates();

        expect(captured.headers['Authorization'], 'Bearer refreshed-token');
      },
    );
  });
}
