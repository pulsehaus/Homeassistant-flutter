import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homeassistant_flutter/features/about/presentation/about_page.dart';

import 'fake_package_info.dart';

void main() {
  setUpAll(() {
    setUpFakePackageInfo(
      appName: 'Home Assistant Flutter',
      version: '1.2.3',
      buildNumber: '45',
    );
  });

  testWidgets('AboutPage shows the app name and version', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AboutPage())),
    );

    // The package-info future resolves synchronously against the mock, but
    // still needs a frame to flow through the FutureProvider.
    await tester.pump();

    expect(find.text('Home Assistant Flutter'), findsOneWidget);
    expect(find.text('Version 1.2.3+45'), findsOneWidget);
  });

  testWidgets('AboutPage shows a loading indicator before info resolves', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AboutPage())),
    );

    // Before the first pump settles the FutureProvider, the shared loading
    // surface from AppPage.async is shown.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump();
  });
}
