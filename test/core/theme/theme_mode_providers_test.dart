import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/core/theme/theme_mode_providers.dart';

import 'fakes/fake_theme_mode_store.dart';

void main() {
  ProviderContainer containerWith(FakeThemeModeStore store) {
    final container = ProviderContainer(
      overrides: [themeModeStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('ThemeModeController', () {
    test('loads the stored mode on build', () async {
      final container = containerWith(
        FakeThemeModeStore(initial: ThemeMode.dark),
      );

      final value = await container.read(themeModeControllerProvider.future);
      expect(value, ThemeMode.dark);
    });

    test('build defaults to ThemeMode.system when nothing is stored', () async {
      final container = containerWith(FakeThemeModeStore());

      final value = await container.read(themeModeControllerProvider.future);
      expect(value, ThemeMode.system);
    });

    test(
      'setThemeMode persists the mode and updates state immediately',
      () async {
        final store = FakeThemeModeStore();
        final container = containerWith(store);
        await container.read(themeModeControllerProvider.future);

        await container
            .read(themeModeControllerProvider.notifier)
            .setThemeMode(ThemeMode.light);

        expect(store.writes, [ThemeMode.light]);
        expect(
          container.read(themeModeControllerProvider).value,
          ThemeMode.light,
        );
      },
    );

    test('cycle advances system -> light -> dark -> system', () async {
      final store = FakeThemeModeStore();
      final container = containerWith(store);
      await container.read(themeModeControllerProvider.future);
      final notifier = container.read(themeModeControllerProvider.notifier);

      expect(
        container.read(themeModeControllerProvider).value,
        ThemeMode.system,
      );

      await notifier.cycle();
      expect(
        container.read(themeModeControllerProvider).value,
        ThemeMode.light,
      );

      await notifier.cycle();
      expect(container.read(themeModeControllerProvider).value, ThemeMode.dark);

      await notifier.cycle();
      expect(
        container.read(themeModeControllerProvider).value,
        ThemeMode.system,
      );

      expect(store.writes, [ThemeMode.light, ThemeMode.dark, ThemeMode.system]);
    });
  });
}
