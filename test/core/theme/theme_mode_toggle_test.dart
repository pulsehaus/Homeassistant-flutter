import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/core/theme/theme_mode_providers.dart';
import 'package:homeassistant_flutter/core/theme/theme_mode_toggle.dart';

import 'fakes/fake_theme_mode_store.dart';

void main() {
  /// Hosts [ThemeModeToggle] inside a real `MaterialApp` whose `themeMode` is
  /// driven by [themeModeControllerProvider] — the same wiring `HomeAssistantApp`
  /// uses — so the test can assert the *applied* theme mode changes, not just
  /// the provider's internal state.
  Widget host(FakeThemeModeStore store) {
    return ProviderScope(
      overrides: [themeModeStoreProvider.overrideWithValue(store)],
      child: Consumer(
        builder: (context, ref, _) {
          final mode = ref.watch(themeModeControllerProvider).value;
          return MaterialApp(
            themeMode: mode,
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            home: Scaffold(appBar: AppBar(actions: const [ThemeModeToggle()])),
          );
        },
      ),
    );
  }

  testWidgets('defaults to system and applies it to MaterialApp', (
    tester,
  ) async {
    await tester.pumpWidget(host(FakeThemeModeStore()));
    await tester.pump(); // resolve the AsyncNotifier's build future

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
  });

  testWidgets('tapping the toggle cycles system -> light -> dark -> system', (
    tester,
  ) async {
    final store = FakeThemeModeStore();
    await tester.pumpWidget(host(store));
    await tester.pump();

    final button = find.byKey(const Key('theme_mode_toggle'));

    await tester.tap(button);
    await tester.pump();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );

    await tester.tap(button);
    await tester.pump();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );

    await tester.tap(button);
    await tester.pump();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );

    // Every step along the cycle was persisted, in order.
    expect(store.writes, [ThemeMode.light, ThemeMode.dark, ThemeMode.system]);
  });

  testWidgets('loads a previously persisted mode on startup', (tester) async {
    await tester.pumpWidget(host(FakeThemeModeStore(initial: ThemeMode.dark)));
    await tester.pump();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
  });
}
