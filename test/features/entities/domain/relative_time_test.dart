import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/entities/domain/relative_time.dart';

void main() {
  final now = DateTime.utc(2024, 1, 1, 12);

  group('RelativeTime.format', () {
    test('reports "just now" for a timestamp under a minute old', () {
      expect(
        RelativeTime.format(
          now.subtract(const Duration(seconds: 30)),
          now: now,
        ),
        'just now',
      );
    });

    test('reports "just now" for a timestamp exactly at now', () {
      expect(RelativeTime.format(now, now: now), 'just now');
    });

    test('reports "just now" for a timestamp in the future (clock skew)', () {
      expect(
        RelativeTime.format(now.add(const Duration(minutes: 5)), now: now),
        'just now',
      );
    });

    test('formats singular minute', () {
      expect(
        RelativeTime.format(now.subtract(const Duration(minutes: 1)), now: now),
        '1 minute ago',
      );
    });

    test('formats plural minutes', () {
      expect(
        RelativeTime.format(now.subtract(const Duration(minutes: 2)), now: now),
        '2 minutes ago',
      );
    });

    test('formats minutes just under an hour', () {
      expect(
        RelativeTime.format(
          now.subtract(const Duration(minutes: 59)),
          now: now,
        ),
        '59 minutes ago',
      );
    });

    test('formats singular hour', () {
      expect(
        RelativeTime.format(now.subtract(const Duration(hours: 1)), now: now),
        '1 hour ago',
      );
    });

    test('formats plural hours', () {
      expect(
        RelativeTime.format(now.subtract(const Duration(hours: 5)), now: now),
        '5 hours ago',
      );
    });

    test('formats hours just under a day', () {
      expect(
        RelativeTime.format(now.subtract(const Duration(hours: 23)), now: now),
        '23 hours ago',
      );
    });

    test('formats singular day', () {
      expect(
        RelativeTime.format(now.subtract(const Duration(days: 1)), now: now),
        '1 day ago',
      );
    });

    test('formats plural days', () {
      expect(
        RelativeTime.format(now.subtract(const Duration(days: 3)), now: now),
        '3 days ago',
      );
    });

    test('uses DateTime.now() when now is omitted', () {
      final result = RelativeTime.format(
        DateTime.now().subtract(const Duration(minutes: 10)),
      );
      expect(result, '10 minutes ago');
    });
  });
}
