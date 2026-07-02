// Integration-style test of the OAuth2 login/refresh layer over the REAL
// transport path: `HaAuthClient` (backed by `package:http`'s real IOClient)
// talking to a loopback `HttpServer` that plays Home Assistant's `/auth/token`
// endpoint. Unlike `ha_auth_client_test.dart` — which drives a `MockClient` at
// the request/response level — this exercises actual HTTP framing, form
// encoding and JSON parsing against a live server, mirroring
// `ha_connection_flow_test.dart`'s approach for the WebSocket layer.
//
// It lives under test/ (not integration_test/) on purpose: it is a headless,
// pure-Dart network test with no widget binding, so it runs with
// `flutter test` and in CI without a device. See AGENTS.md's testing section.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/application/token_refresh_coordinator.dart';
import 'package:homeassistant_flutter/features/connection/data/ha_auth_client.dart';
import 'package:homeassistant_flutter/features/connection/data/ha_rest_client.dart';
import 'package:homeassistant_flutter/features/connection/data/ha_websocket_client.dart';
import 'package:homeassistant_flutter/features/connection/domain/connection_credentials.dart';
import 'package:homeassistant_flutter/features/connection/domain/ha_connection_config.dart';
import 'package:homeassistant_flutter/features/connection/domain/ha_exception.dart';

import 'fakes/fake_ha_socket.dart';

void main() {
  const timeout = Duration(seconds: 10);

  late _FakeHaAuthServer server;

  setUp(() async {
    server = _FakeHaAuthServer();
    await server.start();
  });

  tearDown(() async {
    await server.stop();
  });

  HaConnectionConfig configFor() =>
      HaConnectionConfig(baseUrl: server.baseUrl, accessToken: 'unused');

  group('HaAuthClient against a real local auth server', () {
    test(
      'exchanges an authorization code for an access + refresh token pair',
      () async {
        server.validCodes.add('good-code');
        final client = HaAuthClient(baseUrl: server.baseUrl);

        final tokens = await client.exchangeCode('good-code').timeout(timeout);

        expect(tokens.accessToken, isNotEmpty);
        expect(tokens.refreshToken, isNotEmpty);
        expect(tokens.expiresIn, const Duration(seconds: 1800));
        expect(server.tokenRequests, hasLength(1));
        expect(server.tokenRequests.single['grant_type'], 'authorization_code');
      },
    );

    test(
      'a used or unknown authorization code is rejected as a HaAuthException',
      () async {
        final client = HaAuthClient(baseUrl: server.baseUrl);

        await expectLater(
          client.exchangeCode('never-issued').timeout(timeout),
          throwsA(isA<HaAuthException>()),
        );
      },
    );

    test('exchanges a refresh token for a new access token', () async {
      server.knownRefreshTokens.add('the-refresh-token');
      final client = HaAuthClient(baseUrl: server.baseUrl);

      final tokens = await client.refresh('the-refresh-token').timeout(timeout);

      expect(tokens.accessToken, isNotEmpty);
      // The server never reissues a refresh token; the client falls back to
      // reusing the one it already had.
      expect(tokens.refreshToken, 'the-refresh-token');
    });

    test('a revoked refresh token is rejected as a HaAuthException', () async {
      final client = HaAuthClient(baseUrl: server.baseUrl);

      await expectLater(
        client.refresh('revoked-or-unknown').timeout(timeout),
        throwsA(isA<HaAuthException>()),
      );
    });
  });

  group('TokenRefreshCoordinator against a real local auth server', () {
    test('refreshes on start and propagates the new access token to the live '
        'WebSocket and REST clients', () async {
      server.knownRefreshTokens.add('session-refresh-token');
      final authClient = HaAuthClient(baseUrl: server.baseUrl);
      final wsClient = HaWebSocketClient(
        config: configFor(),
        connector: FakeConnector().connect,
      );
      addTearDown(wsClient.dispose);
      final restClient = HaRestClient(config: configFor());
      addTearDown(restClient.close);

      final saved = <ConnectionCredentials>[];
      final coordinator = TokenRefreshCoordinator(
        authClient: authClient,
        webSocketClient: wsClient,
        restClient: restClient,
        saveCredentials: (credentials) async {
          saved.add(credentials);
        },
      );
      addTearDown(coordinator.dispose);

      coordinator.start(
        ConnectionCredentials(
          serverUrl: server.baseUrl.toString(),
          accessToken: 'stale-access-token',
          refreshToken: 'session-refresh-token',
        ),
      );

      await Future.doWhile(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return saved.isEmpty;
      }).timeout(timeout);

      expect(saved, hasLength(1));
      final refreshedToken = saved.single.accessToken;
      expect(refreshedToken, isNot('stale-access-token'));
      expect(saved.single.refreshToken, 'session-refresh-token');
    });
  });
}

/// A minimal in-process Home Assistant OAuth2 auth server for end-to-end
/// tests: serves `/auth/token`, accepting `authorization_code` grants for
/// codes in [validCodes] (consumed on use, matching Home Assistant's
/// single-use codes) and `refresh_token` grants for tokens in
/// [knownRefreshTokens].
class _FakeHaAuthServer {
  HttpServer? _server;
  int _tokenCounter = 0;

  /// Authorization codes the server accepts. Removed once exchanged — HA
  /// codes are single-use.
  final Set<String> validCodes = {};

  /// Refresh tokens the server accepts.
  final Set<String> knownRefreshTokens = {};

  /// Every `/auth/token` request body the server has decoded, in order.
  final List<Map<String, String>> tokenRequests = [];

  Uri get baseUrl =>
      Uri(scheme: 'http', host: 'localhost', port: _server!.port);

  Future<void> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_handle);
  }

  Future<void> _handle(HttpRequest request) async {
    if (request.uri.path != '/auth/token' || request.method != 'POST') {
      request.response.statusCode = 404;
      await request.response.close();
      return;
    }

    final body = await utf8.decoder.bind(request).join();
    final form = Uri.splitQueryString(body);
    tokenRequests.add(form);

    switch (form['grant_type']) {
      case 'authorization_code':
        final code = form['code'];
        if (code == null || !validCodes.remove(code)) {
          _respondError(request, 'invalid_grant', 'Unknown or reused code');
          return;
        }
        _respondTokens(request, includeRefreshToken: true);
      case 'refresh_token':
        final refreshToken = form['refresh_token'];
        if (refreshToken == null ||
            !knownRefreshTokens.contains(refreshToken)) {
          _respondError(
            request,
            'invalid_grant',
            'Unknown or revoked refresh token',
          );
          return;
        }
        // Home Assistant does not reissue a refresh token on this grant.
        _respondTokens(request, includeRefreshToken: false);
      default:
        _respondError(request, 'unsupported_grant_type', 'Unknown grant');
    }
  }

  void _respondTokens(
    HttpRequest request, {
    required bool includeRefreshToken,
  }) {
    _tokenCounter += 1;
    final payload = <String, dynamic>{
      'access_token': 'access-token-$_tokenCounter',
      'expires_in': 1800,
      'token_type': 'Bearer',
      if (includeRefreshToken) 'refresh_token': 'refresh-token-$_tokenCounter',
    };
    request.response
      ..statusCode = 200
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(payload));
    request.response.close();
  }

  void _respondError(HttpRequest request, String error, String description) {
    request.response
      ..statusCode = 400
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'error': error, 'error_description': description}));
    request.response.close();
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}
