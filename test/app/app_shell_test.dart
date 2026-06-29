import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/app/app_shell.dart';
import 'package:homeassistant_flutter/shared/presentation/app_page.dart';

void main() {
  List<ShellDestination> destinations() => [
    ShellDestination(
      label: 'First',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      builder: (_) => const AppPage(title: 'First', body: Text('first body')),
    ),
    ShellDestination(
      label: 'Second',
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights,
      builder: (_) => const AppPage(title: 'Second', body: Text('second body')),
    ),
  ];

  testWidgets('renders the first destination and a navigation bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AppShell(destinations: destinations())),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('first body'), findsOneWidget);
  });

  testWidgets('selecting a destination updates the selected index', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AppShell(destinations: destinations())),
    );

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );

    // Tap the second navigation destination.
    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();

    // IndexedStack keeps both bodies in the tree; the visible one is driven by
    // the navigation bar's selected index.
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
  });

  testWidgets('a single destination renders without navigation chrome', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          destinations: [
            ShellDestination(
              label: 'Only',
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              builder: (_) =>
                  const AppPage(title: 'Only', body: Text('only body')),
            ),
          ],
        ),
      ),
    );

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('only body'), findsOneWidget);
  });

  testWidgets('honours initialIndex', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(destinations: destinations(), initialIndex: 1),
      ),
    );

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
  });
}
