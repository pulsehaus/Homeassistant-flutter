import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/application/connection_providers.dart';
import 'package:homeassistant_flutter/features/connection/data/ha_websocket_client.dart';
import 'package:homeassistant_flutter/features/connection/domain/connection_status.dart';
import 'package:homeassistant_flutter/features/connection/domain/ha_connection_config.dart';
import 'package:homeassistant_flutter/features/connection/presentation/connection_banner.dart';

import '../fakes/fake_ha_socket.dart';

final _config = HaConnectionConfig(
  baseUrl: Uri.parse('http://localhost:8123'),
  accessToken: 'test-token',
);

void main() {
  // Drives connectionStateProvider in each test. Broadcast so it survives the
  // provider re-listening across rebuilds; closed in tearDown.
  late StreamController<HaConnectionState> states;

  setUp(() => states = StreamController<HaConnectionState>.broadcast());
  tearDown(() => states.close());

  /// Pumps the banner with [connectionStateProvider] fed by [states]. When a
  /// [connector] is supplied, the real client is overridden so Retry's
  /// `connect()` is observable through it.
  Future<void> pumpBanner(
    WidgetTester tester, {
    FakeConnector? connector,
  }) async {
    final overrides = <Override>[
      connectionStateProvider.overrideWith((ref) => states.stream),
    ];
    if (connector != null) {
      final client = HaWebSocketClient(
        config: _config,
        connector: connector.connect,
      );
      addTearDown(client.dispose);
      overrides.add(haWebSocketClientProvider.overrideWithValue(client));
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(home: Scaffold(body: ConnectionBanner())),
      ),
    );
    // Let the StreamProvider attach before tests emit states.
    await tester.pump();
  }

  testWidgets('hidden while connected', (tester) async {
    await pumpBanner(tester);
    states.add(const HaConnectionState(HaConnectionStatus.connected));
    await tester.pumpAndSettle();

    expect(find.textContaining('Reconnecting'), findsNothing);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('appears on reconnecting with a Retry action', (tester) async {
    await pumpBanner(tester);
    states.add(const HaConnectionState(HaConnectionStatus.reconnecting));
    await tester.pumpAndSettle();

    expect(find.textContaining('Reconnecting'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('appears on a fatal error', (tester) async {
    await pumpBanner(tester);
    states.add(const HaConnectionState(HaConnectionStatus.error));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('disappears once the connection recovers', (tester) async {
    await pumpBanner(tester);

    states.add(const HaConnectionState(HaConnectionStatus.reconnecting));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);

    states.add(const HaConnectionState(HaConnectionStatus.connected));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('Retry triggers a reconnection attempt', (tester) async {
    final connector = FakeConnector();
    await pumpBanner(tester, connector: connector);

    states.add(const HaConnectionState(HaConnectionStatus.reconnecting));
    await tester.pumpAndSettle();

    expect(connector.calls, 0);
    await tester.tap(find.text('Retry'));
    await tester.pump();

    // Tapping Retry asked the client to (re)open the socket.
    expect(connector.calls, 1);
  });
}
