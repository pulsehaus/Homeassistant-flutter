import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/dashboard/domain/lovelace_card.dart';
import 'package:homeassistant_flutter/features/dashboard/domain/lovelace_config_parser.dart';

void main() {
  group('parseLovelaceConfig', () {
    test('parses title, views and the first view cards', () {
      final config = parseLovelaceConfig({
        'title': 'Home',
        'views': [
          {
            'title': 'Main',
            'path': 'main',
            'cards': [
              {'type': 'entity', 'entity': 'sensor.temp'},
            ],
          },
          {'title': 'Second', 'cards': <dynamic>[]},
        ],
      });

      expect(config.title, 'Home');
      expect(config.views, hasLength(2));
      expect(config.firstView!.title, 'Main');
      expect(config.firstView!.path, 'main');
      expect(
        config.firstView!.cards.single,
        const EntityCard(entityId: 'sensor.temp'),
      );
    });

    test('absent, non-list or empty views give an empty config', () {
      expect(parseLovelaceConfig(<String, dynamic>{}).firstView, isNull);
      expect(parseLovelaceConfig({'views': 'nope'}).firstView, isNull);
      expect(parseLovelaceConfig({'views': <dynamic>[]}).firstView, isNull);
    });

    test('skips malformed views and cards instead of throwing', () {
      final config = parseLovelaceConfig({
        'views': [
          'not a map',
          {
            'cards': [
              'nope',
              42,
              {'type': 'entity', 'entity': 'light.k'},
            ],
          },
        ],
      });

      expect(config.views, hasLength(1));
      expect(
        config.firstView!.cards.single,
        const EntityCard(entityId: 'light.k'),
      );
    });
  });

  group('cardFromJson', () {
    test('entity card maps entity + name', () {
      expect(
        cardFromJson({
          'type': 'entity',
          'entity': 'light.k',
          'name': 'Kitchen',
        }),
        const EntityCard(entityId: 'light.k', name: 'Kitchen'),
      );
    });

    test('entities card normalises both row shapes and skips bad rows', () {
      final card = cardFromJson({
        'type': 'entities',
        'title': 'Lights',
        'entities': [
          'light.kitchen',
          {'entity': 'light.living', 'name': 'Living'},
          {'no_entity': true},
          42,
        ],
      });

      expect(
        card,
        const EntitiesCard(
          title: 'Lights',
          rows: [
            EntitiesRow(entityId: 'light.kitchen'),
            EntitiesRow(entityId: 'light.living', name: 'Living'),
          ],
        ),
      );
    });

    test('history-graph card parses entities, title and hours_to_show', () {
      final card = cardFromJson({
        'type': 'history-graph',
        'title': 'Temperatures',
        'hours_to_show': 48,
        'entities': ['sensor.living_room', 'sensor.bedroom'],
      });

      expect(
        card,
        const HistoryGraphCard(
          title: 'Temperatures',
          hoursToShow: 48,
          entities: ['sensor.living_room', 'sensor.bedroom'],
        ),
      );
    });

    test('history-graph card defaults hours_to_show to 24 when absent', () {
      final card = cardFromJson({
        'type': 'history-graph',
        'entities': ['sensor.living_room'],
      });

      expect(
        card,
        const HistoryGraphCard(
          entities: ['sensor.living_room'],
          hoursToShow: 24,
        ),
      );
    });

    test('history-graph card skips non-string entity entries', () {
      final card = cardFromJson({
        'type': 'history-graph',
        'entities': [
          'sensor.living_room',
          42,
          {'entity': 'sensor.should_be_skipped'},
        ],
      });

      expect(card, const HistoryGraphCard(entities: ['sensor.living_room']));
    });

    test('history-graph card with missing or empty entities degrades to '
        'UnsupportedCard', () {
      expect(
        cardFromJson({'type': 'history-graph'}),
        const UnsupportedCard(type: 'history-graph'),
      );
      expect(
        cardFromJson({'type': 'history-graph', 'entities': <dynamic>[]}),
        const UnsupportedCard(type: 'history-graph'),
      );
      expect(
        cardFromJson({'type': 'history-graph', 'entities': 'not-a-list'}),
        const UnsupportedCard(type: 'history-graph'),
      );
    });

    test('button card parses entity, name, icon and show flags', () {
      expect(
        cardFromJson({
          'type': 'button',
          'entity': 'light.kitchen',
          'name': 'Kitchen',
          'icon': 'mdi:lightbulb',
          'show_name': false,
          'show_state': true,
        }),
        const ButtonCard(
          entityId: 'light.kitchen',
          name: 'Kitchen',
          icon: 'mdi:lightbulb',
          showName: false,
          showState: true,
        ),
      );
    });

    test('button card defaults show_name to true and show_state to false', () {
      expect(
        cardFromJson({'type': 'button', 'entity': 'light.kitchen'}),
        const ButtonCard(entityId: 'light.kitchen'),
      );
    });

    test('button card with a missing/non-string entity is NOT UnsupportedCard '
        '(HA allows entity-less buttons)', () {
      expect(cardFromJson({'type': 'button'}), const ButtonCard());
      expect(
        cardFromJson({'type': 'button', 'entity': 42}),
        const ButtonCard(),
      );
      expect(
        cardFromJson({'type': 'button', 'name': 'Go somewhere'}),
        const ButtonCard(name: 'Go somewhere'),
      );
    });

    test('unknown type degrades to UnsupportedCard carrying the type', () {
      expect(
        cardFromJson({'type': 'thermostat'}),
        const UnsupportedCard(type: 'thermostat'),
      );
    });

    test('missing or non-string type degrades to UnsupportedCard(unknown)', () {
      expect(
        cardFromJson(<String, dynamic>{}),
        const UnsupportedCard(type: 'unknown'),
      );
      expect(
        cardFromJson({'type': 42}),
        const UnsupportedCard(type: 'unknown'),
      );
    });

    test('a known type with a malformed body never throws', () {
      // entity card without an entity id -> placeholder for that type
      expect(
        cardFromJson({'type': 'entity'}),
        const UnsupportedCard(type: 'entity'),
      );
      // entities card with a non-list body -> still an EntitiesCard, no rows
      expect(
        cardFromJson({'type': 'entities', 'entities': 'nope'}),
        const EntitiesCard(),
      );
    });
  });

  test('models use value equality (cheap rebuilds and assertions)', () {
    expect(
      const EntitiesCard(
        title: 'A',
        rows: [EntitiesRow(entityId: 'x')],
      ),
      const EntitiesCard(
        title: 'A',
        rows: [EntitiesRow(entityId: 'x')],
      ),
    );
    expect(
      const EntityCard(entityId: 'x'),
      isNot(const EntityCard(entityId: 'y')),
    );
  });
}
