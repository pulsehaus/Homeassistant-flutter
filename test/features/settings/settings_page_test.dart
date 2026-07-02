import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/core/theme/theme_mode_providers.dart';
import 'package:homeassistant_flutter/features/about/presentation/about_page.dart';
import 'package:homeassistant_flutter/features/connection/application/connection_setup_providers.dart';
import 'package:homeassistant_flutter/features/home/presentation/home_page.dart';
import 'package:homeassistant_flutter/features/settings/presentation/settings_page.dart';

import '../../core/theme/fakes/fake_theme_mode_store.dart';
import '../about/fake_package_info.dart';
import '../connection/fakes/fake_credential_store.dart';

void main() {
  setUpAll(() {
    setUpFakePackageInfo(
      appName: 'Home Assistant Flutter',
      version: '1.2.3',
      buildNumber: '45',
    );
  });

  /// Hosts [HomePage] behind the same provider wiring the real app uses for
  /// theme mode and credentials, so navigating into Settings and exercising
  /// each action runs through the real controllers.
  Widget host({FakeThemeModeStore? themeStore, FakeCredentialStore? store}) {
    return ProviderScope(
      overrides: [
        themeModeStoreProvider.overrideWithValue(
          themeStore ?? FakeThemeModeStore(),
        ),
        credentialStoreProvider.overrideWithValue(
          store ?? FakeCredentialStore(),
        ),
      ],
      child: const MaterialApp(home: HomePage()),
    );
  }

  testWidgets('Home app bar exposes a single Settings icon', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.byKey(const Key('settings_action')), findsOneWidget);
    // The individual actions no longer live in the Home app bar.
    expect(find.byKey(const Key('theme_mode_toggle')), findsNothing);
    expect(find.byKey(const Key('about_action')), findsNothing);
    expect(find.byKey(const Key('disconnect_action')), findsNothing);
  });

  testWidgets('tapping Settings opens a screen with all three actions', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pump();

    await tester.tap(find.byKey(const Key('settings_action')));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byKey(const Key('theme_mode_toggle')), findsOneWidget);
    expect(find.byKey(const Key('about_action')), findsOneWidget);
    expect(find.byKey(const Key('disconnect_action')), findsOneWidget);
  });

  testWidgets('the theme toggle in Settings still cycles the app theme', (
    tester,
  ) async {
    final themeStore = FakeThemeModeStore();
    await tester.pumpWidget(host(themeStore: themeStore));
    await tester.pump();

    await tester.tap(find.byKey(const Key('settings_action')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('theme_mode_toggle')));
    await tester.pump();

    expect(themeStore.writes, [ThemeMode.light]);
  });

  testWidgets('the About action in Settings still opens the About page', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pump();

    await tester.tap(find.byKey(const Key('settings_action')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('about_action')));
    await tester.pumpAndSettle();

    expect(find.byType(AboutPage), findsOneWidget);
    expect(find.text('Home Assistant Flutter'), findsOneWidget);
  });

  testWidgets(
    'the Disconnect action in Settings still clears stored credentials',
    (tester) async {
      final store = FakeCredentialStore();
      await tester.pumpWidget(host(store: store));
      await tester.pump();

      await tester.tap(find.byKey(const Key('settings_action')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('disconnect_action')));
      await tester.pumpAndSettle();

      // The confirmation dialog guards the destructive clear.
      expect(find.text('Disconnect?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Disconnect'));
      await tester.pumpAndSettle();

      expect(store.clears, 1);
    },
  );
}
