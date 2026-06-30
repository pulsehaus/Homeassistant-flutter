import 'package:flutter/material.dart';

/// One entry in the app shell's navigation.
@immutable
class ShellDestination {
  const ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Builds the screen for this destination. The screen is expected to build on
  /// [AppPage] so it gets the shared app bar / async-state treatment.
  final WidgetBuilder builder;
}

/// Top-level app shell: provides the application's primary navigation and the
/// overall layout, so feature screens plug in consistently.
///
/// It owns the selected-destination state and swaps the body via an
/// [IndexedStack] (each destination keeps its state while you switch). The
/// shell renders a [NavigationBar]; individual destinations supply their own
/// app bar through [AppPage].
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.destinations,
    this.initialIndex = 0,
    this.banner,
  }) : assert(
         destinations.length > 0,
         'AppShell needs at least one destination',
       );

  final List<ShellDestination> destinations;
  final int initialIndex;

  /// Optional app-wide banner pinned above the body, visible across every
  /// destination (e.g. a connection-lost notice). Injected by the app so the
  /// shell stays free of feature-specific dependencies; defaults to nothing.
  final Widget? banner;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index = widget.initialIndex;

  void _select(int index) => setState(() => _index = index);

  /// Pins [widget.banner] above [body] so it shows across every destination.
  /// When no banner is supplied the body is returned untouched.
  Widget _withBanner(Widget body) {
    final banner = widget.banner;
    if (banner == null) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        banner,
        Expanded(child: body),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final destinations = widget.destinations;

    // A single destination needs no navigation chrome.
    if (destinations.length == 1) {
      return _withBanner(destinations.single.builder(context));
    }

    return Scaffold(
      body: _withBanner(
        IndexedStack(
          index: _index,
          children: [
            for (final destination in destinations)
              // KeyedSubtree keeps each destination's element/state stable
              // across rebuilds even as the selected index changes.
              KeyedSubtree(
                key: ValueKey(destination.label),
                child: Builder(builder: destination.builder),
              ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}
