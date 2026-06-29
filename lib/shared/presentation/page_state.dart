import 'package:flutter/material.dart';

/// The async surface a feature screen can be in, independent of any specific
/// state-management package. [AppPage] renders one of these consistently so
/// every screen shows the same loading / error / empty / content treatment.
enum PageStatus { loading, error, empty, content }

/// Describes what a page should render right now: a [status] plus the optional
/// data the [PageStatus.error] and content branches need.
///
/// This is intentionally a plain value type (no Riverpod dependency) so it can
/// be unit-tested and reused outside the Riverpod world. The Riverpod bridge
/// lives in [AppPage.async], which maps an `AsyncValue` onto this type.
@immutable
class PageState {
  const PageState.loading() : status = PageStatus.loading, error = null;

  const PageState.empty() : status = PageStatus.empty, error = null;

  const PageState.content() : status = PageStatus.content, error = null;

  const PageState.error(Object this.error) : status = PageStatus.error;

  final PageStatus status;

  /// Populated only when [status] is [PageStatus.error].
  final Object? error;
}
