import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/icon_map.dart';

/// Resolves a Home Assistant `icon` config string (e.g. `mdi:water-pump`) to
/// a real [IconData] from the Material Design Icons set.
///
/// HA's Lovelace config uses MDI icon *name* strings for the `icon` field.
/// The `material_design_icons_flutter` package bundles the full MDI set and
/// exposes `iconMap`, a plain `Map<String, IconData>` keyed by camelCase
/// names (e.g. `waterPump`) — the same data backing its generated `MdiIcons`
/// class (each `MdiIcons.xxx` getter is just `iconMap['xxx']!`). Looking the
/// converted name up in that map directly avoids both reflection and the
/// `fromString`-style helpers some MDI packages ship, which disable
/// tree-shaking and require building with `--no-tree-shake-icons`.
///
/// Returns null when [icon] is null/empty, doesn't have the `mdi:` prefix, or
/// doesn't match a known icon name — callers should fall back to their own
/// default in that case. Never throws on an unrecognized name.
IconData? resolveMdiIcon(String? icon) {
  if (icon == null) return null;
  const prefix = 'mdi:';
  if (!icon.startsWith(prefix)) return null;
  final name = icon.substring(prefix.length).trim();
  if (name.isEmpty) return null;
  return iconMap[_camelCase(name)];
}

/// A handful of MDI names collide with Dart reserved words once converted to
/// a bare identifier, so the package's generated `MdiIcons` class (and, in
/// turn, `iconMap`) suffixes those specific entries with `Icon` instead of
/// using the bare camelCase form. See the package's `icon_map.dart` for the
/// authoritative set.
const Map<String, String> _reservedWordIcons = {
  'null': 'nullIcon',
  'switch': 'switchIcon',
  'sync': 'syncIcon',
  'factory': 'factoryIcon',
};

/// Converts an MDI kebab-case name (e.g. `water-pump`) to the camelCase key
/// used by `iconMap` (e.g. `waterPump`), special-casing the small set of
/// names that collide with Dart reserved words.
String _camelCase(String kebabName) {
  final reserved = _reservedWordIcons[kebabName];
  if (reserved != null) return reserved;

  final parts = kebabName.split('-').where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return kebabName;

  final buffer = StringBuffer(parts.first);
  for (final part in parts.skip(1)) {
    buffer.write(part[0].toUpperCase());
    buffer.write(part.substring(1));
  }
  return buffer.toString();
}
