import 'package:flutter/material.dart';
import 'package:homeassistant_flutter/core/theme/theme_mode_store.dart';

/// In-memory [ThemeModeStore] for tests. Records writes so a test can assert
/// what was persisted, and can be seeded with [initial] to simulate a
/// returning user who already picked a mode.
class FakeThemeModeStore implements ThemeModeStore {
  FakeThemeModeStore({ThemeMode? initial}) : _stored = initial;

  ThemeMode? _stored;

  /// The modes handed to [write], in order. Empty until something is saved.
  final List<ThemeMode> writes = [];

  /// Whatever is currently stored — handy for assertions.
  ThemeMode? get current => _stored;

  @override
  Future<ThemeMode?> read() async => _stored;

  @override
  Future<void> write(ThemeMode mode) async {
    writes.add(mode);
    _stored = mode;
  }
}
