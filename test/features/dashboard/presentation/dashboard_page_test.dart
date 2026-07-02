import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/application/connection_providers.dart';
import 'package:homeassistant_flutter/features/connection/domain/entity_state.dart';
import 'package:homeassistant_flutter/features/dashboard/application/dashboard_providers.dart';
import 'package:homeassistant_flutter/features/dashboard/domain/lovelace_card.dart';
import 'package:homeassistant_flutter/features/dashboard/domain/lovelace_config.dart';
import 'package:homeassistant_flutter/features/dashboard/presentation/dashboard_page.dart';

EntityState _entity(String id, {String state = 'on', String? friendlyName}) {
  return EntityState(
    entityId: id,
    state: state,
    attributes: friendlyName == null
        ? const {}
        : {'friendly_name': friendlyName},
  );
}

Map<String, EntityState> _store(List<EntityState> entities) {
  return {for (final e in entities) e.entityId: e};
}

Widget _harness(List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: const MaterialApp(home: DashboardPage()),
);

void main() {
  testWidgets(
    'renders entities, entity and unsupported cards with live state',
    (tester) async {
      const config = LovelaceConfig(
        title: 'Home',
        views: [
          LovelaceView(
            cards: [
              EntitiesCard(
                title: 'Lights',
                rows: [
                  EntitiesRow(entityId: 'light.kitchen'),
                  EntitiesRow(entityId: 'light.living', name: 'Living'),
                ],
              ),
              EntityCard(entityId: 'sensor.temperature'),
              UnsupportedCard(type: 'thermostat'),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        _harness([
          dashboardConfigProvider.overrideWithValue(
            const AsyncValue.data(config),
          ),
          entityStatesProvider.overrideWith(
            (ref) => Stream.value(
              _store([
                _entity('light.kitchen', state: 'on', friendlyName: 'Kitchen'),
                _entity(
                  'light.living',
                  state: 'off',
                  friendlyName: 'Living room',
                ),
                _entity(
                  'sensor.temperature',
                  state: '21.4',
                  friendlyName: 'Temperature',
                ),
              ]),
            ),
          ),
        ]),
      );
      await tester.pump();

      // AppPage title + entities-card title.
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Lights'), findsOneWidget);

      // Label precedence: friendly name, explicit row name wins over friendly,
      // entity-card uses the entity friendly name.
      expect(find.text('Kitchen'), findsOneWidget);
      expect(find.text('Living'), findsOneWidget);
      expect(find.text('Living room'), findsNothing);
      expect(find.text('Temperature'), findsOneWidget);

      // Live states from the store.
      expect(find.text('on'), findsOneWidget);
      expect(find.text('off'), findsOneWidget);
      expect(find.text('21.4'), findsOneWidget);

      // Unknown card type degrades gracefully without crashing.
      expect(find.text('Unsupported card: thermostat'), findsOneWidget);
    },
  );

  testWidgets('shows the empty surface when the first view has no cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness([
        dashboardConfigProvider.overrideWithValue(
          const AsyncValue.data(
            LovelaceConfig(views: [LovelaceView(cards: [])]),
          ),
        ),
        entityStatesProvider.overrideWith(
          (ref) => Stream.value(const <String, EntityState>{}),
        ),
      ]),
    );
    await tester.pump();

    expect(find.text('No dashboard cards yet.'), findsOneWidget);
  });

  testWidgets('shows the loading surface while the config is pending', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness([
        dashboardConfigProvider.overrideWithValue(const AsyncValue.loading()),
      ]),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the error surface when the fetch fails', (tester) async {
    await tester.pumpWidget(
      _harness([
        dashboardConfigProvider.overrideWithValue(
          AsyncValue.error(StateError('config not found'), StackTrace.current),
        ),
      ]),
    );
    await tester.pump();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.textContaining('config not found'), findsOneWidget);
  });

  testWidgets(
    'a single-view config shows no tab chrome, just that view\'s cards',
    (tester) async {
      const config = LovelaceConfig(
        title: 'Home',
        views: [
          LovelaceView(
            title: 'Only view',
            cards: [EntityCard(entityId: 'sensor.temperature')],
          ),
        ],
      );

      await tester.pumpWidget(
        _harness([
          dashboardConfigProvider.overrideWithValue(
            const AsyncValue.data(config),
          ),
          entityStatesProvider.overrideWith(
            (ref) => Stream.value(
              _store([
                _entity(
                  'sensor.temperature',
                  state: '21.4',
                  friendlyName: 'Temperature',
                ),
              ]),
            ),
          ),
        ]),
      );
      await tester.pump();

      // Only one view: no TabBar/Tab chrome, and its title isn't shown as a tab.
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('Only view'), findsNothing);

      // The single view's cards render directly.
      expect(find.text('Temperature'), findsOneWidget);
    },
  );

  testWidgets('switching between views renders the correct cards for each', (
    tester,
  ) async {
    const config = LovelaceConfig(
      title: 'Home',
      views: [
        LovelaceView(
          title: 'Living Room',
          cards: [EntityCard(entityId: 'light.living')],
        ),
        LovelaceView(
          title: 'Kitchen',
          cards: [EntityCard(entityId: 'light.kitchen')],
        ),
      ],
    );

    await tester.pumpWidget(
      _harness([
        dashboardConfigProvider.overrideWithValue(
          const AsyncValue.data(config),
        ),
        entityStatesProvider.overrideWith(
          (ref) => Stream.value(
            _store([
              _entity('light.living', state: 'on', friendlyName: 'Living'),
              _entity('light.kitchen', state: 'off', friendlyName: 'Kitchen'),
            ]),
          ),
        ),
      ]),
    );
    await tester.pump();

    // Both tabs are reachable, and the first view's cards render initially.
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('Living Room'), findsOneWidget);
    expect(find.text('Kitchen'), findsWidgets);
    expect(find.text('Living'), findsOneWidget);

    // Switch to the second tab: its cards now render, the first view's don't.
    await tester.tap(find.widgetWithText(Tab, 'Kitchen'));
    await tester.pumpAndSettle();

    expect(find.text('Living'), findsNothing);
    expect(find.text('Kitchen'), findsWidgets);
  });

  testWidgets(
    'pulling to refresh re-fetches the dashboard config (single view)',
    (tester) async {
      var fetchCount = 0;
      const config = LovelaceConfig(
        views: [
          LovelaceView(cards: [EntityCard(entityId: 'sensor.temperature')]),
        ],
      );

      await tester.pumpWidget(
        _harness([
          dashboardConfigStreamProvider.overrideWith((ref) async* {
            fetchCount++;
            yield config;
          }),
          entityStatesProvider.overrideWith(
            (ref) => Stream.value(
              _store([
                _entity(
                  'sensor.temperature',
                  state: '21.4',
                  friendlyName: 'Temperature',
                ),
              ]),
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();
      expect(fetchCount, 1);
      expect(find.byType(RefreshIndicator), findsOneWidget);

      // Drag down from the top of the RefreshIndicator to trigger a
      // pull-to-refresh, then let the indicator's animation settle.
      await tester.fling(
        find.byType(RefreshIndicator),
        const Offset(0, 300),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(fetchCount, 2);
    },
  );

  testWidgets(
    'pulling to refresh re-fetches the dashboard config (tabbed views)',
    (tester) async {
      var fetchCount = 0;
      const config = LovelaceConfig(
        views: [
          LovelaceView(
            title: 'Living Room',
            cards: [EntityCard(entityId: 'light.living')],
          ),
          LovelaceView(
            title: 'Kitchen',
            cards: [EntityCard(entityId: 'light.kitchen')],
          ),
        ],
      );

      await tester.pumpWidget(
        _harness([
          dashboardConfigStreamProvider.overrideWith((ref) async* {
            fetchCount++;
            yield config;
          }),
          entityStatesProvider.overrideWith(
            (ref) => Stream.value(
              _store([
                _entity('light.living', state: 'on', friendlyName: 'Living'),
                _entity('light.kitchen', state: 'off', friendlyName: 'Kitchen'),
              ]),
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();
      expect(fetchCount, 1);
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);

      // Drag down from the top of the active tab's RefreshIndicator to
      // trigger a pull-to-refresh, then let the indicator's animation settle.
      await tester.fling(
        find.byType(RefreshIndicator),
        const Offset(0, 300),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(fetchCount, 2);
    },
  );
}
