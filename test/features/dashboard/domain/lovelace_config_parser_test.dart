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
