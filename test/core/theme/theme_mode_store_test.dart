import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/core/theme/theme_mode_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Reset the in-memory backing store shared_preferences uses under test,
    // so each test starts with nothing persisted.
    SharedPreferences.setMockInitialValues({});
  });

  ThemeModeStore store() => SharedPreferencesThemeModeStore();

  group('SharedPreferencesThemeModeStore', () {
    test('read returns null when nothing is stored', () async {
      expect(await store().read(), isNull);
    });

    test('write then read round-trips the mode', () async {
      final s = store();
      await s.write(ThemeMode.dark);

      expect(await s.read(), ThemeMode.dark);
    });

    test('a later write overwrites the previous mode', () async {
      final s = store();
      await s.write(ThemeMode.light);
      await s.write(ThemeMode.dark);

      expect(await s.read(), ThemeMode.dark);
    });

    test(
      'persists across separate store instances (same backing prefs)',
      () async {
        await store().write(ThemeMode.light);

        expect(await store().read(), ThemeMode.light);
      },
    );
  });
}
