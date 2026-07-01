import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/shared/presentation/app_page.dart';
import 'package:homeassistant_flutter/shared/presentation/page_state.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: child);

  group('AppPage explicit state', () {
    testWidgets('content state renders the body and the title', (tester) async {
      await tester.pumpWidget(
        host(const AppPage(title: 'My Page', body: Text('the body'))),
      );

      expect(find.text('My Page'), findsOneWidget);
      expect(find.text('the body'), findsOneWidget);
    });

    testWidgets('loading state shows a progress indicator, not the body', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const AppPage(
            title: 'My Page',
            state: PageState.loading(),
            body: Text('the body'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('the body'), findsNothing);
    });

    testWidgets('empty state shows the empty message, not the body', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const AppPage(
            title: 'My Page',
            state: PageState.empty(),
            emptyMessage: 'No devices found',
            body: Text('the body'),
          ),
        ),
      );

      expect(find.text('No devices found'), findsOneWidget);
      expect(find.text('the body'), findsNothing);
    });

    testWidgets('error state shows the error and a working retry button', (
      tester,
    ) async {
      var retried = false;

      await tester.pumpWidget(
        host(
          AppPage(
            title: 'My Page',
            state: const PageState.error('boom'),
            onRetry: () => retried = true,
            body: const Text('the body'),
          ),
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('boom'), findsOneWidget);
      expect(find.text('the body'), findsNothing);

      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('error state hides retry when no callback is given', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const AppPage(
            title: 'My Page',
            state: PageState.error('boom'),
            body: Text('the body'),
          ),
        ),
      );

      expect(find.text('Retry'), findsNothing);
    });
  });

  group('AppPage.async (Riverpod bridge)', () {
    testWidgets('loading AsyncValue maps to the loading surface', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          AppPage.async<int>(
            title: 'Async',
            value: const AsyncValue.loading(),
            builder: (_, data) => Text('data: $data'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('error AsyncValue maps to the error surface', (tester) async {
      await tester.pumpWidget(
        host(
          AppPage.async<int>(
            title: 'Async',
            value: const AsyncValue.error('kaboom', StackTrace.empty),
            builder: (_, data) => Text('data: $data'),
          ),
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('kaboom'), findsOneWidget);
    });

    testWidgets('data AsyncValue renders the builder', (tester) async {
      await tester.pumpWidget(
        host(
          AppPage.async<int>(
            title: 'Async',
            value: const AsyncValue.data(42),
            builder: (_, data) => Text('data: $data'),
          ),
        ),
      );

      expect(find.text('data: 42'), findsOneWidget);
    });

    testWidgets('isEmpty data AsyncValue maps to the empty surface', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          AppPage.async<List<int>>(
            title: 'Async',
            value: const AsyncValue.data(<int>[]),
            isEmpty: (data) => data.isEmpty,
            emptyMessage: 'Nothing to show',
            builder: (_, data) => Text('items: ${data.length}'),
          ),
        ),
      );

      expect(find.text('Nothing to show'), findsOneWidget);
      expect(find.textContaining('items:'), findsNothing);
    });
  });
}
