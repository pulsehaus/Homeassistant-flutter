import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/domain/ha_connection_config.dart';

void main() {
  group('HaConnectionConfig', () {
    test('derives a wss WebSocket URL from an https base', () {
      final config = HaConnectionConfig(
        baseUrl: Uri.parse('https://ha.example.com'),
        accessToken: 'token',
      );

      expect(
        config.webSocketUrl.toString(),
        'wss://ha.example.com/api/websocket',
      );
      expect(config.restBaseUrl.toString(), 'https://ha.example.com/api');
    });

    test('derives a ws WebSocket URL from an http base and keeps the port', () {
      final config = HaConnectionConfig(
        baseUrl: Uri.parse('http://192.168.1.10:8123'),
        accessToken: 'token',
      );

      expect(
        config.webSocketUrl.toString(),
        'ws://192.168.1.10:8123/api/websocket',
      );
      expect(config.restBaseUrl.toString(), 'http://192.168.1.10:8123/api');
    });

    test('ignores any path on the base URL', () {
      final config = HaConnectionConfig(
        baseUrl: Uri.parse('https://ha.example.com/lovelace?foo=bar'),
        accessToken: 'token',
      );

      expect(
        config.webSocketUrl.toString(),
        'wss://ha.example.com/api/websocket',
      );
      expect(config.restBaseUrl.toString(), 'https://ha.example.com/api');
    });

    test('value equality is based on URL and token', () {
      final a = HaConnectionConfig(
        baseUrl: Uri.parse('https://ha.example.com'),
        accessToken: 'token',
      );
      final b = HaConnectionConfig(
        baseUrl: Uri.parse('https://ha.example.com'),
        accessToken: 'token',
      );
      final c = HaConnectionConfig(
        baseUrl: Uri.parse('https://ha.example.com'),
        accessToken: 'other',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });
}
