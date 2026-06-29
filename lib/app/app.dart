import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/charts/presentation/chart_example_page.dart';
import '../features/home/presentation/home_page.dart';
import 'app_shell.dart';

/// Root widget of the application: the minimal app shell that every feature
/// plugs into. Keep this thin — it only wires global concerns (theme, and
/// later routing/localization) and delegates the actual UI to the [AppShell],
/// which owns the top-level navigation between feature destinations.
class HomeAssistantApp extends StatelessWidget {
  const HomeAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Home Assistant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: AppShell(
        destinations: [
          ShellDestination(
            label: 'Home',
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
            builder: (_) => const HomePage(),
          ),
          ShellDestination(
            label: 'Charts',
            icon: Icons.insights_outlined,
            selectedIcon: Icons.insights,
            builder: (_) => const ChartExamplePage(),
          ),
        ],
      ),
    );
  }
}
