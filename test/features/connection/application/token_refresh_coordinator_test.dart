import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/application/token_refresh_coordinator.dart';
import 'package:homeassistant_flutter/features/connection/data/ha_auth_client.dart';
import 'package:homeassistant_flutter/features/connection/data/ha_rest_client.dart';
import 'package:homeassistant_flutter/features/connection/data/ha_websocket_client.dart';
import 'package:homeassistant_flutter/features/connection/domain/connection_credentials.dart';
import 'package:homeassistant_flutter/features/connection/domain/ha_connection_config.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../fakes/fake_ha_socket.dart';

final _config = HaConnectionConfig(
  baseUrl: Uri.parse('http://localhost:8123'),
  accessToken: 'initial-access-token',
);

const _oauthCredentials = ConnectionCredentials(
  serverUrl: 'http://localhost:8123',
  accessToken: 'initial-access-token',
  refreshToken: 'initial-refresh-token',
);

const _manualCredentials = ConnectionCredentials(
  serverUrl: 'http://localhost:8123',
  accessToken: 'long-lived-token',
);

void main() {
  group('TokenRefreshCoordinator', () {
    test('start is a no-op for the manual long-lived-token path', () {
      fakeAsync((async) {
        var refreshCalls = 0;
        final authClient = HaAuthClient(
          baseUrl: _config.baseUrl,
          httpClient: MockClient((_) async {
            refreshCalls += 1;
            return http.Response('{}', 200);
          }),
        );
        final wsClient = HaWebSocketClient(
          config: _config,
          connector: FakeConnector().connect,
        );
        final restClient = HaRestClient(config: _config, httpClient: null);
        final coordinator = TokenRefreshCoordinator(
          authClient: authClient,
          webSocketClient: wsClient,
          restClient: restClient,
          saveCredentials: (_) async {},
        );

        coordinator.start(_manualCredentials);
        async.flushMicrotasks();

        expect(refreshCalls, 0);

        coordinator.dispose();
        wsClient.dispose();
      });
    });

    test('start performs an immediate refresh, updates both clients and '
        'persists the new credentials', () {
      fakeAsync((async) {
        http.Request? captured;
        final authClient = HaAuthClient(
          baseUrl: _config.baseUrl,
          httpClient: MockClient((request) async {
            captured = request;
            return http.Response(
              jsonEncode({
                'access_token': 'refreshed-access-token',
                'refresh_token': 'refreshed-refresh-token',
                'expires_in': 1800,
              }),
              200,
            );
          }),
        );
        final wsClient = HaWebSocketClient(
          config: _config,
          connector: FakeConnector().connect,
        );
        final restClient = HaRestClient(config: _config, httpClient: null);
        final saved = <ConnectionCredentials>[];
        final coordinator = TokenRefreshCoordinator(
          authClient: authClient,
          webSocketClient: wsClient,
          restClient: restClient,
          saveCredentials: (credentials) async {
            saved.add(credentials);
          },
        );

        coordinator.start(_oauthCredentials);
        async.flushMicrotasks();

        expect(
          Uri.splitQueryString(captured!.body)['refresh_token'],
          'initial-refresh-token',
        );
        expect(saved, [
          const ConnectionCredentials(
            serverUrl: 'http://localhost:8123',
            accessToken: 'refreshed-access-token',
            refreshToken: 'refreshed-refresh-token',
          ),
        ]);

        coordinator.dispose();
        wsClient.dispose();
      });
    });

    test(
      'schedules the next refresh at expires_in minus the refresh margin',
      () {
        fakeAsync((async) {
          var refreshCalls = 0;
          final authClient = HaAuthClient(
            baseUrl: _config.baseUrl,
            httpClient: MockClient((_) async {
              refreshCalls += 1;
              return http.Response(
                jsonEncode({
                  'access_token': 'access-$refreshCalls',
                  'refresh_token': 'refresh-$refreshCalls',
                  'expires_in': 1800, // 30 minutes
                }),
                200,
              );
            }),
          );
          final wsClient = HaWebSocketClient(
            config: _config,
            connector: FakeConnector().connect,
          );
          final restClient = HaRestClient(config: _config, httpClient: null);
          final coordinator = TokenRefreshCoordinator(
            authClient: authClient,
            webSocketClient: wsClient,
            restClient: restClient,
            saveCredentials: (_) async {},
            refreshMargin: const Duration(minutes: 5),
          );

          coordinator.start(_oauthCredentials);
          async.flushMicrotasks();
          expect(refreshCalls, 1);

          // Just short of the scheduled refresh (30 - 5 = 25 minutes) — no
          // second refresh yet.
          async.elapse(const Duration(minutes: 24));
          expect(refreshCalls, 1);

          // Past the scheduled refresh.
          async.elapse(const Duration(minutes: 2));
          expect(refreshCalls, 2);

          coordinator.dispose();
          wsClient.dispose();
        });
      },
    );

    test('pushes the refreshed access token to both the WebSocket and REST '
        'clients', () {
      fakeAsync((async) {
        final authClient = HaAuthClient(
          baseUrl: _config.baseUrl,
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'access_token': 'refreshed-access-token',
                'refresh_token': 'refreshed-refresh-token',
                'expires_in': 1800,
              }),
              200,
            ),
          ),
        );
        final connector = FakeConnector();
        final wsClient = HaWebSocketClient(
          config: _config,
          connector: connector.connect,
        );
        http.Request? restRequest;
        final restClient = HaRestClient(
          config: _config,
          httpClient: MockClient((request) async {
            restRequest = request;
            return http.Response('[]', 200);
          }),
        );
        final coordinator = TokenRefreshCoordinator(
          authClient: authClient,
          webSocketClient: wsClient,
          restClient: restClient,
          saveCredentials: (_) async {},
        );

        coordinator.start(_oauthCredentials);
        async.flushMicrotasks();

        // WS: the next handshake uses the refreshed token.
        wsClient.connect();
        async.flushMicrotasks();
        connector.last.serverSend({'type': 'auth_required'});
        async.flushMicrotasks();
        expect(
          connector.last.sent.first['access_token'],
          'refreshed-access-token',
        );

        // REST: immediately reflected in the next request's header.
        restClient.fetchStates();
        async.flushMicrotasks();
        expect(
          restRequest?.headers['Authorization'],
          'Bearer refreshed-access-token',
        );

        coordinator.dispose();
        wsClient.dispose();
      });
    });

    test(
      'stops retrying once the refresh token itself is rejected (revoked)',
      () {
        fakeAsync((async) {
          var refreshCalls = 0;
          final authClient = HaAuthClient(
            baseUrl: _config.baseUrl,
            httpClient: MockClient((_) async {
              refreshCalls += 1;
              return http.Response(jsonEncode({'error': 'invalid_grant'}), 400);
            }),
          );
          final wsClient = HaWebSocketClient(
            config: _config,
            connector: FakeConnector().connect,
          );
          final restClient = HaRestClient(config: _config, httpClient: null);
          final coordinator = TokenRefreshCoordinator(
            authClient: authClient,
            webSocketClient: wsClient,
            restClient: restClient,
            saveCredentials: (_) async {},
          );

          coordinator.start(_oauthCredentials);
          async.flushMicrotasks();
          expect(refreshCalls, 1);

          // No further refresh is ever scheduled after an auth rejection.
          async.elapse(const Duration(hours: 2));
          expect(refreshCalls, 1);

          coordinator.dispose();
          wsClient.dispose();
        });
      },
    );

    test('retries after the refresh margin on a transport failure, without '
        'giving up', () {
      fakeAsync((async) {
        var attempt = 0;
        final authClient = HaAuthClient(
          baseUrl: _config.baseUrl,
          httpClient: MockClient((_) async {
            attempt += 1;
            if (attempt == 1) {
              throw http.ClientException('network down');
            }
            return http.Response(
              jsonEncode({
                'access_token': 'access-2',
                'refresh_token': 'refresh-2',
                'expires_in': 1800,
              }),
              200,
            );
          }),
        );
        final wsClient = HaWebSocketClient(
          config: _config,
          connector: FakeConnector().connect,
        );
        final restClient = HaRestClient(config: _config, httpClient: null);
        final coordinator = TokenRefreshCoordinator(
          authClient: authClient,
          webSocketClient: wsClient,
          restClient: restClient,
          saveCredentials: (_) async {},
          refreshMargin: const Duration(minutes: 5),
        );

        coordinator.start(_oauthCredentials);
        async.flushMicrotasks();
        expect(attempt, 1);

        async.elapse(const Duration(minutes: 5));
        expect(attempt, 2);

        coordinator.dispose();
        wsClient.dispose();
      });
    });

    test('dispose cancels any pending scheduled refresh', () {
      fakeAsync((async) {
        var refreshCalls = 0;
        final authClient = HaAuthClient(
          baseUrl: _config.baseUrl,
          httpClient: MockClient((_) async {
            refreshCalls += 1;
            return http.Response(
              jsonEncode({
                'access_token': 'access-1',
                'refresh_token': 'refresh-1',
                'expires_in': 1800,
              }),
              200,
            );
          }),
        );
        final wsClient = HaWebSocketClient(
          config: _config,
          connector: FakeConnector().connect,
        );
        final restClient = HaRestClient(config: _config, httpClient: null);
        final coordinator = TokenRefreshCoordinator(
          authClient: authClient,
          webSocketClient: wsClient,
          restClient: restClient,
          saveCredentials: (_) async {},
        );

        coordinator.start(_oauthCredentials);
        async.flushMicrotasks();
        expect(refreshCalls, 1);

        coordinator.dispose();
        async.elapse(const Duration(hours: 1));
        expect(refreshCalls, 1);

        wsClient.dispose();
      });
    });
  });
}
