import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_mode_providers.dart';

/// App-bar action that lets the user cycle the manual theme mode: system →
/// light → dark → system.
///
/// The chosen mode is applied immediately (via [ThemeModeController]) and
/// persisted so it survives restarts. While the stored mode is still loading,
/// the button falls back to the system icon and is disabled rather than
/// guessing at a value.
class ThemeModeToggle extends ConsumerWidget {
  const ThemeModeToggle({super.key});

  static const _icons = {
    ThemeMode.system: Icons.brightness_auto_outlined,
    ThemeMode.light: Icons.light_mode_outlined,
    ThemeMode.dark: Icons.dark_mode_outlined,
  };

  static const _labels = {
    ThemeMode.system: 'Theme: system',
    ThemeMode.light: 'Theme: light',
    ThemeMode.dark: 'Theme: dark',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeControllerProvider);
    final mode = themeMode.value ?? ThemeMode.system;

    return IconButton(
      key: const Key('theme_mode_toggle'),
      tooltip: '${_labels[mode]} (tap to change)',
      icon: Icon(_icons[mode]),
      onPressed: themeMode.isLoading
          ? null
          : () => ref.read(themeModeControllerProvider.notifier).cycle(),
    );
  }
}
