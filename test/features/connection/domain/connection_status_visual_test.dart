import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/domain/connection_status.dart';
import 'package:homeassistant_flutter/features/connection/domain/connection_status_visual.dart';

void main() {
  const colors = ColorScheme.light();

  group('ConnectionStatusVisual.forStatus', () {
    test('connected uses the primary colour', () {
      final visual = ConnectionStatusVisual.forStatus(
        HaConnectionStatus.connected,
      );

      expect(visual.colorOf(colors), colors.primary);
    });

    test('reconnecting uses the tertiary colour', () {
      final visual = ConnectionStatusVisual.forStatus(
        HaConnectionStatus.reconnecting,
      );

      expect(visual.colorOf(colors), colors.tertiary);
    });

    test('error uses the theme error colour', () {
      final visual = ConnectionStatusVisual.forStatus(HaConnectionStatus.error);

      expect(visual.colorOf(colors), colors.error);
    });

    test('connected, reconnecting and error each have a distinct icon', () {
      final connected = ConnectionStatusVisual.forStatus(
        HaConnectionStatus.connected,
      );
      final reconnecting = ConnectionStatusVisual.forStatus(
        HaConnectionStatus.reconnecting,
      );
      final error = ConnectionStatusVisual.forStatus(HaConnectionStatus.error);

      expect(connected.icon, isNot(reconnecting.icon));
      expect(reconnecting.icon, isNot(error.icon));
      expect(connected.icon, isNot(error.icon));
    });

    test('quiet start-up phases use a muted, neutral colour', () {
      for (final status in [
        HaConnectionStatus.idle,
        HaConnectionStatus.connecting,
        HaConnectionStatus.authenticating,
      ]) {
        final visual = ConnectionStatusVisual.forStatus(status);
        expect(visual.colorOf(colors), colors.onSurfaceVariant);
      }
    });

    test('disconnected uses a muted, neutral colour', () {
      final visual = ConnectionStatusVisual.forStatus(
        HaConnectionStatus.disconnected,
      );

      expect(visual.colorOf(colors), colors.onSurfaceVariant);
    });
  });
}
