import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/data/ha_auth_client.dart';
import 'package:homeassistant_flutter/features/connection/domain/ha_exception.dart';
import 'package:homeassistant_flutter/features/connection/domain/oauth_client_config.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _baseUrl = Uri.parse('http://localhost:8123');

HaAuthClient _clientReturning(
  Future<http.Response> Function(http.Request request) handler,
) => HaAuthClient(baseUrl: _baseUrl, httpClient: MockClient(handler));

void main() {
  group('HaAuthClient.authorizeUrl', () {
    test('points at /auth/authorize with client_id and redirect_uri', () {
      final client = HaAuthClient(baseUrl: _baseUrl);
      final url = client.authorizeUrl();

      expect(url.scheme, 'http');
      expect(url.host, 'localhost');
      expect(url.port, 8123);
      expect(url.path, '/auth/authorize');
      expect(url.queryParameters['client_id'], OAuthClientConfig.clientId);
      expect(
        url.queryParameters['redirect_uri'],
        OAuthClientConfig.redirectUri,
      );
      expect(url.queryParameters['response_type'], 'code');
    });
  });

  group('HaAuthClient.exchangeCode', () {
    test('posts a authorization_code grant to /auth/token', () async {
      late http.Request captured;
      final client = _clientReturning((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'access_token': 'access-123',
            'refresh_token': 'refresh-123',
            'expires_in': 1800,
            'token_type': 'Bearer',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final tokens = await client.exchangeCode('the-auth-code');

      expect(captured.method, 'POST');
      expect(captured.url.path, '/auth/token');
      expect(
        captured.headers['Content-Type'],
        startsWith('application/x-www-form-urlencoded'),
      );
      final body = Uri.splitQueryString(captured.body);
      expect(body['grant_type'], 'authorization_code');
      expect(body['code'], 'the-auth-code');
      expect(body['client_id'], OAuthClientConfig.clientId);
      expect(tokens.accessToken, 'access-123');
      expect(tokens.refreshToken, 'refresh-123');
      expect(tokens.expiresIn, const Duration(seconds: 1800));
    });

    test('maps a rejected code (400) to a HaAuthException', () async {
      final client = _clientReturning(
        (_) async => http.Response(
          jsonEncode({
            'error': 'invalid_grant',
            'error_description': 'Invalid code',
          }),
          400,
        ),
      );

      await expectLater(
        client.exchangeCode('bad-code'),
        throwsA(
          isA<HaAuthException>().having(
            (e) => e.message,
            'message',
            'Invalid code',
          ),
        ),
      );
    });

    test('maps a transport failure to a HaConnectionException', () async {
      final client = _clientReturning(
        (_) async => throw http.ClientException('network down'),
      );

      await expectLater(
        client.exchangeCode('any-code'),
        throwsA(isA<HaConnectionException>()),
      );
    });

    test('maps a non-JSON 2xx body to a HaRestException', () async {
      final client = _clientReturning(
        (_) async => http.Response('not json', 200),
      );

      await expectLater(
        client.exchangeCode('any-code'),
        throwsA(isA<HaRestException>()),
      );
    });

    test('maps other error codes to a HaRestException', () async {
      final client = _clientReturning((_) async => http.Response('', 500));

      await expectLater(
        client.exchangeCode('any-code'),
        throwsA(
          isA<HaRestException>().having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });
  });

  group('HaAuthClient.refresh', () {
    test('posts a refresh_token grant to /auth/token', () async {
      late http.Request captured;
      final client = _clientReturning((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'access_token': 'new-access', 'expires_in': 1800}),
          200,
        );
      });

      final tokens = await client.refresh('the-refresh-token');

      final body = Uri.splitQueryString(captured.body);
      expect(body['grant_type'], 'refresh_token');
      expect(body['refresh_token'], 'the-refresh-token');
      expect(body['client_id'], OAuthClientConfig.clientId);
      expect(tokens.accessToken, 'new-access');
    });

    test('reuses the supplied refresh token when the response omits one '
        '(HA does not reissue on refresh)', () async {
      final client = _clientReturning(
        (_) async => http.Response(
          jsonEncode({'access_token': 'new-access', 'expires_in': 1800}),
          200,
        ),
      );

      final tokens = await client.refresh('the-refresh-token');

      expect(tokens.refreshToken, 'the-refresh-token');
    });

    test('maps a revoked refresh token (401) to a HaAuthException', () async {
      final client = _clientReturning(
        (_) async => http.Response(jsonEncode({'error': 'invalid_grant'}), 401),
      );

      await expectLater(
        client.refresh('revoked-token'),
        throwsA(isA<HaAuthException>()),
      );
    });
  });
}
