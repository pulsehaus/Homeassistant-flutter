import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/data/credential_validator.dart';
import 'package:homeassistant_flutter/features/connection/domain/ha_connection_config.dart';

import '../fakes/fake_ha_socket.dart';

void main() {
  final config = HaConnectionConfig(
    baseUrl: Uri.parse('https://ha.example.com'),
    accessToken: 'good-token',
  );

  group('CredentialValidator', () {
    test('succeeds when the auth handshake completes', () async {
      final connector = FakeConnector();
      final validator = WebSocketCredentialValidator(
        connector: connector.connect,
      );

      final future = validator.validate(config);
      // Let the client open the socket before driving the handshake.
      await pumpEventQueue();
      await completeHandshake(connector.last);

      expect(await future, isA<CredentialValidationSuccess>());
    });

    test('reports an auth failure on auth_invalid (not retried)', () async {
      final connector = FakeConnector();
      final validator = WebSocketCredentialValidator(
        connector: connector.connect,
      );

      final future = validator.validate(config);
      await pumpEventQueue();
      connector.last.serverSend({'type': 'auth_required'});
      await pumpEventQueue();
      connector.last.serverSend({
        'type': 'auth_invalid',
        'message': 'Invalid access token',
      });

      final result = await future;
      expect(result, isA<CredentialValidationFailure>());
      final failure = result as CredentialValidationFailure;
      expect(failure.isAuth, isTrue);
      expect(failure.message, contains('Invalid access token'));
      // A bad token is fatal — the client must not have retried.
      expect(connector.calls, 1);
    });

    test('reports a connection failure (timeout) when the server is '
        'unreachable', () async {
      final connector = FakeConnector()..failNextConnections = 100;
      // Short timeout so the bounded reconnect loop gives up quickly.
      final validator = WebSocketCredentialValidator(
        connector: connector.connect,
        timeout: const Duration(milliseconds: 200),
      );

      final result = await validator.validate(config);
      expect(result, isA<CredentialValidationFailure>());
      expect((result as CredentialValidationFailure).isAuth, isFalse);
    });
  });
}
