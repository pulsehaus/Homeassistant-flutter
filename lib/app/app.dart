import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/theme_mode_providers.dart';
import '../features/charts/presentation/entity_history_page.dart';
import '../features/connection/application/connection_providers.dart';
import '../features/connection/application/connection_session_controller.dart';
import '../features/connection/domain/connection_credentials.dart';
import '../features/connection/domain/ha_connection_config.dart';
import '../features/connection/domain/server_url.dart';
import '../features/connection/presentation/connection_banner.dart';
import '../features/connection/presentation/connection_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/entities/presentation/entities_overview_page.dart';
import '../features/home/presentation/home_page.dart';
import 'app_shell.dart';

/// Root widget of the application. Keep this thin — it wires global concerns
/// (theme) and chooses the top-level screen based on the connection session:
///
/// - while the stored credentials are loading → a splash spinner;
/// - no instance configured → the [ConnectionPage];
/// - an instance configured → the [AppShell], with `haConnectionConfigProvider`
///   overridden from the stored credentials so the live connection layer can
///   reach the user's instance.
class HomeAssistantApp extends ConsumerWidget {
  const HomeAssistantApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(connectionSessionProvider);
    // Defaults to ThemeMode.system while the stored preference is still
    // loading (or if nothing has been chosen yet), matching the previous
    // implicit behaviour before a manual toggle existed.
    final themeMode =
        ref.watch(themeModeControllerProvider).value ?? ThemeMode.system;

    return MaterialApp(
      title: 'Home Assistant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: session.when(
        loading: () => const _SplashScreen(),
        // A failure to read secure storage shouldn't strand the user — fall back
        // to the connection screen so they can (re-)enter their credentials.
        error: (_, _) => const ConnectionPage(),
        data: (credentials) => credentials == null
            ? const ConnectionPage()
            : _ConnectedApp(credentials: credentials),
      ),
    );
  }
}

/// The connected experience: the app shell scoped to the user's instance.
///
/// It overrides [haConnectionConfigProvider] with the stored credentials so the
/// WebSocket/REST clients in the connection layer talk to the right server.
class _ConnectedApp extends StatelessWidget {
  const _ConnectedApp({required this.credentials});

  final ConnectionCredentials credentials;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        haConnectionConfigProvider.overrideWithValue(
          HaConnectionConfig(
            // Re-normalise here so the live connection layer gets a clean base
            // URL even if storage holds the user's raw input.
            baseUrl:
                ServerUrl.tryParse(credentials.serverUrl) ??
                Uri.parse(credentials.serverUrl),
            accessToken: credentials.accessToken,
          ),
        ),
      ],
      child: AppShell(
        // App-wide connection-lost notice, visible across every destination.
        banner: const ConnectionBanner(),
        destinations: const [
          ShellDestination(
            label: 'Home',
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
            builder: _buildHome,
          ),
          ShellDestination(
            label: 'Dashboard',
            icon: Icons.space_dashboard_outlined,
            selectedIcon: Icons.space_dashboard,
            builder: _buildDashboard,
          ),
          ShellDestination(
            label: 'Entities',
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
            builder: _buildEntities,
          ),
          ShellDestination(
            label: 'History',
            icon: Icons.insights_outlined,
            selectedIcon: Icons.insights,
            builder: _buildHistory,
          ),
        ],
      ),
    );
  }

  static Widget _buildHome(BuildContext context) => const HomePage();

  static Widget _buildDashboard(BuildContext context) => const DashboardPage();

  static Widget _buildEntities(BuildContext context) =>
      const EntitiesOverviewPage();

  static Widget _buildHistory(BuildContext context) =>
      const EntityHistoryPage();
}

/// Minimal splash shown while the stored credentials are read from secure
/// storage on startup.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
