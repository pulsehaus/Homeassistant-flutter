import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/charts/application/chart_providers.dart';
import 'package:homeassistant_flutter/features/charts/domain/history_range.dart';

import '../fakes/fake_chart_selection_store.dart';

void main() {
  ProviderContainer containerWith(FakeChartSelectionStore store) {
    final container = ProviderContainer(
      overrides: [chartSelectionStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('SelectedChartEntityController', () {
    test('loads the stored entity id on build', () async {
      final container = containerWith(
        FakeChartSelectionStore(initialEntityId: 'sensor.temp'),
      );

      final value = await container.read(selectedChartEntityProvider.future);
      expect(value, 'sensor.temp');
    });

    test('build defaults to null when nothing is stored', () async {
      final container = containerWith(FakeChartSelectionStore());

      final value = await container.read(selectedChartEntityProvider.future);
      expect(value, isNull);
    });

    test(
      'select persists the entity id and updates state immediately',
      () async {
        final store = FakeChartSelectionStore();
        final container = containerWith(store);
        await container.read(selectedChartEntityProvider.future);

        await container
            .read(selectedChartEntityProvider.notifier)
            .select('sensor.temp');

        expect(store.entityIdWrites, ['sensor.temp']);
        expect(
          container.read(selectedChartEntityProvider).value,
          'sensor.temp',
        );
      },
    );

    test('select(null) clears the stored entity id', () async {
      final store = FakeChartSelectionStore(initialEntityId: 'sensor.temp');
      final container = containerWith(store);
      await container.read(selectedChartEntityProvider.future);

      await container.read(selectedChartEntityProvider.notifier).select(null);

      expect(store.entityIdWrites, [null]);
      expect(container.read(selectedChartEntityProvider).value, isNull);
    });
  });

  group('SelectedHistoryRangeController', () {
    test('loads the stored range on build', () async {
      final container = containerWith(
        FakeChartSelectionStore(initialRange: HistoryRange.days7),
      );

      final value = await container.read(selectedHistoryRangeProvider.future);
      expect(value, HistoryRange.days7);
    });

    test(
      'build defaults to HistoryRange.hours24 when nothing is stored',
      () async {
        final container = containerWith(FakeChartSelectionStore());

        final value = await container.read(selectedHistoryRangeProvider.future);
        expect(value, HistoryRange.hours24);
      },
    );

    test('select persists the range and updates state immediately', () async {
      final store = FakeChartSelectionStore();
      final container = containerWith(store);
      await container.read(selectedHistoryRangeProvider.future);

      await container
          .read(selectedHistoryRangeProvider.notifier)
          .select(HistoryRange.hour1);

      expect(store.rangeWrites, [HistoryRange.hour1]);
      expect(
        container.read(selectedHistoryRangeProvider).value,
        HistoryRange.hour1,
      );
    });
  });
}
