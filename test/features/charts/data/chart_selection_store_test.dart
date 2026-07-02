import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/charts/data/chart_selection_store.dart';
import 'package:homeassistant_flutter/features/charts/domain/history_range.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Reset the in-memory backing store shared_preferences uses under test,
    // so each test starts with nothing persisted.
    SharedPreferences.setMockInitialValues({});
  });

  ChartSelectionStore store() => SharedPreferencesChartSelectionStore();

  group('SharedPreferencesChartSelectionStore — entity id', () {
    test('readEntityId returns null when nothing is stored', () async {
      expect(await store().readEntityId(), isNull);
    });

    test('writeEntityId then readEntityId round-trips the id', () async {
      final s = store();
      await s.writeEntityId('sensor.temp');

      expect(await s.readEntityId(), 'sensor.temp');
    });

    test('a later write overwrites the previous id', () async {
      final s = store();
      await s.writeEntityId('sensor.a');
      await s.writeEntityId('sensor.b');

      expect(await s.readEntityId(), 'sensor.b');
    });

    test('writing null clears the stored id', () async {
      final s = store();
      await s.writeEntityId('sensor.a');
      await s.writeEntityId(null);

      expect(await s.readEntityId(), isNull);
    });

    test(
      'persists across separate store instances (same backing prefs)',
      () async {
        await store().writeEntityId('sensor.temp');

        expect(await store().readEntityId(), 'sensor.temp');
      },
    );
  });

  group('SharedPreferencesChartSelectionStore — range', () {
    test('readRange returns null when nothing is stored', () async {
      expect(await store().readRange(), isNull);
    });

    test('writeRange then readRange round-trips the range', () async {
      final s = store();
      await s.writeRange(HistoryRange.days7);

      expect(await s.readRange(), HistoryRange.days7);
    });

    test('a later write overwrites the previous range', () async {
      final s = store();
      await s.writeRange(HistoryRange.hour1);
      await s.writeRange(HistoryRange.days7);

      expect(await s.readRange(), HistoryRange.days7);
    });

    test(
      'persists across separate store instances (same backing prefs)',
      () async {
        await store().writeRange(HistoryRange.hour1);

        expect(await store().readRange(), HistoryRange.hour1);
      },
    );
  });
}
