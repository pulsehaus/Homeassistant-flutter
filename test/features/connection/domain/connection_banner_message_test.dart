import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/domain/connection_banner_message.dart';
import 'package:homeassistant_flutter/features/connection/domain/connection_status.dart';

void main() {
  ConnectionBannerMessage? messageFor(HaConnectionStatus status) =>
      ConnectionBannerMessage.forState(HaConnectionState(status));

  group('ConnectionBannerMessage.forState', () {
    test('shows a reconnecting message while backing off', () {
      final message = messageFor(HaConnectionStatus.reconnecting);

      expect(message, isNotNull);
      expect(message!.title, contains('Reconnecting'));
      expect(message.showRetry, isTrue);
    });

    test('shows an error message on a fatal failure', () {
      final message = messageFor(HaConnectionStatus.error);

      expect(message, isNotNull);
      expect(message!.showRetry, isTrue);
    });

    test('shows nothing while connected', () {
      expect(messageFor(HaConnectionStatus.connected), isNull);
    });

    test('shows nothing during the quiet start-up phases', () {
      expect(messageFor(HaConnectionStatus.idle), isNull);
      expect(messageFor(HaConnectionStatus.connecting), isNull);
      expect(messageFor(HaConnectionStatus.authenticating), isNull);
    });

    test('shows nothing after a deliberate disconnect', () {
      expect(messageFor(HaConnectionStatus.disconnected), isNull);
    });

    test('value equality holds for identical messages', () {
      expect(
        messageFor(HaConnectionStatus.reconnecting),
        equals(messageFor(HaConnectionStatus.reconnecting)),
      );
    });
  });
}
