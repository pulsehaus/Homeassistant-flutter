import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/domain/connection_credentials.dart';

void main() {
  group('ConnectionCredentials', () {
    test('refreshToken defaults to null for the manual token path', () {
      const credentials = ConnectionCredentials(
        serverUrl: 'https://ha.example.com',
        accessToken: 'long-lived-token',
      );

      expect(credentials.refreshToken, isNull);
      expect(credentials.canRefresh, isFalse);
    });

    test('canRefresh is true once a refreshToken is present', () {
      const credentials = ConnectionCredentials(
        serverUrl: 'https://ha.example.com',
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      );

      expect(credentials.canRefresh, isTrue);
    });

    test('equality and hashCode include refreshToken', () {
      const withRefresh = ConnectionCredentials(
        serverUrl: 'https://ha.example.com',
        accessToken: 'token',
        refreshToken: 'refresh',
      );
      const withoutRefresh = ConnectionCredentials(
        serverUrl: 'https://ha.example.com',
        accessToken: 'token',
      );
      const sameAsWithRefresh = ConnectionCredentials(
        serverUrl: 'https://ha.example.com',
        accessToken: 'token',
        refreshToken: 'refresh',
      );

      expect(withRefresh, isNot(withoutRefresh));
      expect(withRefresh, sameAsWithRefresh);
      expect(withRefresh.hashCode, sameAsWithRefresh.hashCode);
    });

    test('copyWith replaces accessToken and refreshToken independently', () {
      const original = ConnectionCredentials(
        serverUrl: 'https://ha.example.com',
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
      );

      final refreshed = original.copyWith(
        accessToken: 'new-access',
        refreshToken: 'new-refresh',
      );

      expect(refreshed.serverUrl, original.serverUrl);
      expect(refreshed.accessToken, 'new-access');
      expect(refreshed.refreshToken, 'new-refresh');
    });

    test('copyWith with no arguments keeps every field unchanged', () {
      const original = ConnectionCredentials(
        serverUrl: 'https://ha.example.com',
        accessToken: 'access',
        refreshToken: 'refresh',
      );

      expect(original.copyWith(), original);
    });
  });
}
