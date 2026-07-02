import 'package:flutter/material.dart';

import '../../../core/theme/theme_mode_toggle.dart';
import '../../../shared/presentation/app_page.dart';
import '../../about/presentation/about_action.dart';
import '../../connection/presentation/disconnect_action.dart';

/// Consolidated settings screen (#76).
///
/// The Home app bar used to grow one icon per settings-like action (theme
/// toggle, About, disconnect) as each was added issue by issue, cluttering the
/// bar. This screen gathers them as list entries instead, so the app bar only
/// ever exposes a single "Settings" icon (see [HomePage]).
///
/// Each row reuses the existing action widget verbatim as its trailing
/// control — [ThemeModeToggle], [AboutAction], [DisconnectAction] — so their
/// behaviour (and their state/keys, for tests) is unchanged; only *where*
/// they're invoked from moves.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Settings',
      body: ListView(
        children: const [
          _SettingsTile(
            icon: Icons.brightness_6_outlined,
            title: 'Appearance',
            subtitle: 'Switch between system, light and dark theme',
            trailing: ThemeModeToggle(),
          ),
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'App name, version and build info',
            trailing: AboutAction(),
          ),
          _SettingsTile(
            icon: Icons.logout,
            title: 'Disconnect',
            subtitle: 'Remove this instance and connect to another one',
            trailing: DisconnectAction(),
          ),
        ],
      ),
    );
  }
}

/// One settings row: a leading icon, a title/subtitle pair describing the
/// action, and the actual action widget as the trailing control.
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing,
    );
  }
}
