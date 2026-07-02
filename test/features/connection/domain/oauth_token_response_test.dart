import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/domain/oauth_token_response.dart';

void main() {
  group('OAuthTokenResponse.fromJson', () {
    test('parses a full authorization-code exchange response', () {
      final response = OAuthTokenResponse.fromJson({
        'access_token': 'access-123',
        'refresh_token': 'refresh-123',
        'expires_in': 1800,
        'token_type': 'Bearer',
      });

      expect(response.accessToken, 'access-123');
      expect(response.refreshToken, 'refresh-123');
      expect(response.expiresIn, const Duration(seconds: 1800));
    });

    test('defaults expiresIn to 1800s when expires_in is missing', () {
      final response = OAuthTokenResponse.fromJson({
        'access_token': 'access-123',
        'refresh_token': 'refresh-123',
      });

      expect(response.expiresIn, const Duration(seconds: 1800));
    });

    test('falls back to fallbackRefreshToken when the response has none '
        '(the refresh-token exchange path)', () {
      final response = OAuthTokenResponse.fromJson({
        'access_token': 'new-access',
        'expires_in': 1800,
      }, fallbackRefreshToken: 'still-the-same-refresh-token');

      expect(response.refreshToken, 'still-the-same-refresh-token');
    });

    test('a response refresh_token takes precedence over the fallback', () {
      final response = OAuthTokenResponse.fromJson({
        'access_token': 'new-access',
        'refresh_token': 'reissued-refresh',
        'expires_in': 1800,
      }, fallbackRefreshToken: 'old-refresh');

      expect(response.refreshToken, 'reissued-refresh');
    });

    test('throws FormatException when there is no refresh_token and no '
        'fallback', () {
      expect(
        () => OAuthTokenResponse.fromJson({
          'access_token': 'access-123',
          'expires_in': 1800,
        }),
        throwsFormatException,
      );
    });
  });
}
