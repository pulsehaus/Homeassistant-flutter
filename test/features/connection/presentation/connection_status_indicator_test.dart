import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/application/connection_providers.dart';
import 'package:homeassistant_flutter/features/connection/domain/connection_status.dart';
import 'package:homeassistant_flutter/features/connection/presentation/connection_status_indicator.dart';

void main() {
  // Drives connectionStateProvider in each test. Broadcast so it survives the
  // provider re-listening across rebuilds; closed in tearDown.
  late StreamController<HaConnectionState> states;

  setUp(() => states = StreamController<HaConnectionState>.broadcast());
  tearDown(() => states.close());

  Future<void> pumpIndicator(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectionStateProvider.overrideWith((ref) => states.stream),
        ],
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(actions: const [ConnectionStatusIndicator()]),
          ),
        ),
      ),
    );
    // Let the StreamProvider attach before tests emit states.
    await tester.pump();
  }

  Icon iconOf(WidgetTester tester) =>
      tester.widget<Icon>(find.byType(Icon).last);

  testWidgets('connected renders a distinct healthy icon/colour', (
    tester,
  ) async {
    await pumpIndicator(tester);
    states.add(const HaConnectionState(HaConnectionStatus.connected));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ConnectionStatusIndicator));
    final colors = Theme.of(context).colorScheme;
    final icon = iconOf(tester);

    expect(icon.icon, Icons.cloud_done_outlined);
    expect(icon.color, colors.primary);
    expect(find.byTooltip('Connected to Home Assistant'), findsOneWidget);
  });

  testWidgets('reconnecting renders a distinct warning icon/colour', (
    tester,
  ) async {
    await pumpIndicator(tester);
    states.add(const HaConnectionState(HaConnectionStatus.reconnecting));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ConnectionStatusIndicator));
    final colors = Theme.of(context).colorScheme;
    final icon = iconOf(tester);

    expect(icon.icon, Icons.cloud_sync_outlined);
    expect(icon.color, colors.tertiary);
    expect(find.byTooltip('Reconnecting to Home Assistant…'), findsOneWidget);
  });

  testWidgets('error renders a distinct error icon/colour from the theme', (
    tester,
  ) async {
    await pumpIndicator(tester);
    states.add(const HaConnectionState(HaConnectionStatus.error));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ConnectionStatusIndicator));
    final colors = Theme.of(context).colorScheme;
    final icon = iconOf(tester);

    expect(icon.icon, Icons.cloud_off_outlined);
    expect(icon.color, colors.error);
    expect(find.byTooltip("Can't reach Home Assistant"), findsOneWidget);
  });

  testWidgets('connected, reconnecting and error all render distinct icons', (
    tester,
  ) async {
    await pumpIndicator(tester);

    states.add(const HaConnectionState(HaConnectionStatus.connected));
    await tester.pumpAndSettle();
    final connectedIcon = iconOf(tester);

    states.add(const HaConnectionState(HaConnectionStatus.reconnecting));
    await tester.pumpAndSettle();
    final reconnectingIcon = iconOf(tester);

    states.add(const HaConnectionState(HaConnectionStatus.error));
    await tester.pumpAndSettle();
    final errorIcon = iconOf(tester);

    expect(connectedIcon.icon, isNot(reconnectingIcon.icon));
    expect(reconnectingIcon.icon, isNot(errorIcon.icon));
    expect(connectedIcon.color, isNot(reconnectingIcon.color));
    expect(reconnectingIcon.color, isNot(errorIcon.color));
  });

  testWidgets('before any status arrives, shows the quiet idle visual', (
    tester,
  ) async {
    await pumpIndicator(tester);

    final icon = iconOf(tester);
    final context = tester.element(find.byType(ConnectionStatusIndicator));
    final colors = Theme.of(context).colorScheme;

    expect(icon.icon, Icons.cloud_queue_outlined);
    expect(icon.color, colors.onSurfaceVariant);
  });
}
