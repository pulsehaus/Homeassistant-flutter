import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/dashboard/presentation/cards/mdi_icon_resolver.dart';
import 'package:material_design_icons_flutter/icon_map.dart';

void main() {
  group('resolveMdiIcon', () {
    test('resolves a simple single-word icon name', () {
      expect(resolveMdiIcon('mdi:lightbulb'), iconMap['lightbulb']);
    });

    test('resolves a kebab-case name by converting it to camelCase', () {
      expect(resolveMdiIcon('mdi:water-pump'), iconMap['waterPump']);
    });

    test('resolves a multi-hyphen kebab-case name', () {
      expect(
        resolveMdiIcon('mdi:access-point-network-off'),
        iconMap['accessPointNetworkOff'],
      );
    });

    test('resolves names that collide with Dart reserved words', () {
      expect(resolveMdiIcon('mdi:switch'), iconMap['switchIcon']);
      expect(resolveMdiIcon('mdi:sync'), iconMap['syncIcon']);
      expect(resolveMdiIcon('mdi:factory'), iconMap['factoryIcon']);
      expect(resolveMdiIcon('mdi:null'), iconMap['nullIcon']);
    });

    test('returns null for an unresolvable/malformed icon name', () {
      expect(resolveMdiIcon('mdi:not-a-real-icon-name'), isNull);
    });

    test('returns null when the icon string has no mdi: prefix', () {
      expect(resolveMdiIcon('lightbulb'), isNull);
    });

    test('returns null for a null icon', () {
      expect(resolveMdiIcon(null), isNull);
    });

    test('returns null for an empty icon string', () {
      expect(resolveMdiIcon(''), isNull);
    });

    test('returns null when the name after the prefix is empty', () {
      expect(resolveMdiIcon('mdi:'), isNull);
    });
  });
}
