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
}
