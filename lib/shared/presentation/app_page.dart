import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'page_state.dart';

/// Reusable page scaffold every feature screen builds on, so screens share a
/// consistent structure (app bar + body) and a single, uniform treatment of the
/// **loading / error / empty** async states instead of each re-implementing it.
///
/// There are two ways to use it:
///
/// * [AppPage] — drive the [state] yourself (handy for synchronous screens or
///   when you already hold a [PageState]).
/// * [AppPage.async] — hand it a Riverpod [AsyncValue] and a `builder`; the
///   template maps loading/error/data onto the shared surfaces for you, with an
///   [isEmpty] predicate to opt into the empty state.
///
/// Customise any state via [loadingBuilder] / [errorBuilder] / [emptyBuilder];
/// each has a sensible default that reads colours and text styles from
/// `Theme.of(context)` (never hard-coded), so it follows the central theme.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.body,
    this.state = const PageState.content(),
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.loadingBuilder,
    this.errorBuilder,
    this.emptyBuilder,
    this.onRetry,
    this.emptyMessage = 'Nothing here yet.',
  });

  /// Title shown in the app bar.
  final String title;

  /// The page content, rendered when [state] is [PageStatus.content].
  final Widget body;

  /// Which async surface to show. Defaults to content.
  final PageState state;

  /// Optional app-bar actions (e.g. a filter or a toggle).
  final List<Widget>? actions;

  final Widget? floatingActionButton;

  /// Optional navigation bar — supplied by the app shell when the page is
  /// hosted inside it.
  final Widget? bottomNavigationBar;

  /// Overrides for each async surface. When null, the themed defaults are used.
  final WidgetBuilder? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final WidgetBuilder? emptyBuilder;

  /// Shown as a "Retry" button on the default error surface when non-null.
  final VoidCallback? onRetry;

  /// Message rendered by the default empty surface.
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(child: _buildBody(context)),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (state.status) {
      case PageStatus.loading:
        return loadingBuilder?.call(context) ?? const _LoadingState();
      case PageStatus.error:
        return errorBuilder?.call(context, state.error!) ??
            _ErrorState(error: state.error!, onRetry: onRetry);
      case PageStatus.empty:
        return emptyBuilder?.call(context) ??
            _EmptyState(message: emptyMessage);
      case PageStatus.content:
        return body;
    }
  }

  /// Riverpod bridge: render [value] through the shared surfaces.
  ///
  /// `loading` and `error` map onto the template's loading/error states; data
  /// is passed to [builder], unless [isEmpty] returns true for it, in which case
  /// the empty surface is shown. This keeps the `AsyncValue` plumbing in one
  /// place so feature screens stay declarative.
  static Widget async<T>({
    Key? key,
    required String title,
    required AsyncValue<T> value,
    required Widget Function(BuildContext context, T data) builder,
    bool Function(T data)? isEmpty,
    List<Widget>? actions,
    Widget? floatingActionButton,
    Widget? bottomNavigationBar,
    WidgetBuilder? loadingBuilder,
    Widget Function(BuildContext context, Object error)? errorBuilder,
    WidgetBuilder? emptyBuilder,
    VoidCallback? onRetry,
    String emptyMessage = 'Nothing here yet.',
  }) {
    return _AsyncAppPage<T>(
      key: key,
      title: title,
      value: value,
      builder: builder,
      isEmpty: isEmpty,
      actions: actions,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      loadingBuilder: loadingBuilder,
      errorBuilder: errorBuilder,
      emptyBuilder: emptyBuilder,
      onRetry: onRetry,
      emptyMessage: emptyMessage,
    );
  }
}

/// Internal widget backing [AppPage.async]. It collapses an [AsyncValue] into a
/// [PageState] + body and delegates rendering to [AppPage], so there is a single
/// implementation of the surfaces.
class _AsyncAppPage<T> extends StatelessWidget {
  const _AsyncAppPage({
    super.key,
    required this.title,
    required this.value,
    required this.builder,
    required this.isEmpty,
    required this.actions,
    required this.floatingActionButton,
    required this.bottomNavigationBar,
    required this.loadingBuilder,
    required this.errorBuilder,
    required this.emptyBuilder,
    required this.onRetry,
    required this.emptyMessage,
  });

  final String title;
  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) builder;
  final bool Function(T data)? isEmpty;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final WidgetBuilder? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final WidgetBuilder? emptyBuilder;
  final VoidCallback? onRetry;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final (state, body) = value.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      data: (data) {
        if (isEmpty?.call(data) ?? false) {
          return (const PageState.empty(), const SizedBox.shrink());
        }
        return (const PageState.content(), builder(context, data));
      },
      loading: () => (const PageState.loading(), const SizedBox.shrink()),
      error: (error, _) => (PageState.error(error), const SizedBox.shrink()),
    );

    return AppPage(
      title: title,
      state: state,
      actions: actions,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      loadingBuilder: loadingBuilder,
      errorBuilder: errorBuilder,
      emptyBuilder: emptyBuilder,
      onRetry: onRetry,
      emptyMessage: emptyMessage,
      body: body,
    );
  }
}

/// Default loading surface: a centred progress indicator.
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

/// Default error surface: an icon, the error message, and an optional retry.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Default empty surface: a muted icon and message.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
