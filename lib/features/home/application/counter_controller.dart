import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reference example of the state-management pattern used across the app.
///
/// A [Notifier] holds a piece of state and exposes methods that mutate it.
/// UI widgets `watch` the provider to rebuild on change and `read` the
/// notifier to trigger actions. Real features (connection status, entity
/// state, dashboards…) will follow this same shape in their
/// `application/` layer.
///
/// This trivial counter exists only to wire one provider end to end; it can
/// be deleted once a real feature replaces the home screen.
class CounterController extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

final counterControllerProvider = NotifierProvider<CounterController, int>(
  CounterController.new,
);
