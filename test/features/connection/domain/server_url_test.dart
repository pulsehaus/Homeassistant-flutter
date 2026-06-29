import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/domain/server_url.dart';

void main() {
  group('ServerUrl.tryParse', () {
    test('accepts an https URL and keeps scheme/host', () {
      final uri = ServerUrl.tryParse('https://ha.example.com');
      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'ha.example.com');
    });

    test('defaults a scheme-less address to http and keeps the port', () {
      final uri = ServerUrl.tryParse('192.168.1.10:8123');
      expect(uri, isNotNull);
      expect(uri!.scheme, 'http');
      expect(uri.host, '192.168.1.10');
      expect(uri.port, 8123);
    });

    test('drops any path, query and fragment', () {
      final uri = ServerUrl.tryParse('https://ha.example.com/lovelace?a=1#x');
      expect(uri!.path, isEmpty);
      expect(uri.query, isEmpty);
      expect(uri.fragment, isEmpty);
    });

    test('trims surrounding whitespace', () {
      expect(ServerUrl.tryParse('  https://ha.example.com  '), isNotNull);
    });

    test('rejects blank input', () {
      expect(ServerUrl.tryParse(''), isNull);
      expect(ServerUrl.tryParse('   '), isNull);
    });

    test('rejects a non-http(s) scheme', () {
      expect(ServerUrl.tryParse('ftp://ha.example.com'), isNull);
      expect(ServerUrl.tryParse('ws://ha.example.com'), isNull);
    });

    test('rejects input with no host', () {
      expect(ServerUrl.tryParse('https://'), isNull);
    });

    test('isValid mirrors tryParse', () {
      expect(ServerUrl.isValid('https://ha.example.com'), isTrue);
      expect(ServerUrl.isValid(''), isFalse);
    });
  });
}
