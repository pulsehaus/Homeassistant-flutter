import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../connection/application/connection_providers.dart';
import '../data/lovelace_repository.dart';
import '../domain/lovelace_config.dart';

/// Fetches the default dashboard's Lovelace config as a single-emission stream.
///
/// Mirrors [entityStatesProvider] — a [StreamProvider] reading
/// [haWebSocketClientProvider] directly — so it resolves in the same scope as
/// the connection config, which the app overrides in a nested `ProviderScope`.
/// Not consumed by widgets directly (see [dashboardConfigProvider]); exposed so
/// Retry can `ref.invalidate(dashboardConfigStreamProvider)` to re-fetch.
///
/// NOTE (follow-up): `lovelace/config` needs a live socket. On a cold start the
/// fetch can race the WebSocket handshake and surface the shared error surface
/// until the user taps Retry. Gating the fetch on the `connected` state is the
/// clean fix but needs the shell smoke test to stop using `pumpAndSettle` for a
/// live-connecting app; tracked as a follow-up rather than reworked here.
final dashboardConfigStreamProvider = StreamProvider<LovelaceConfig>((ref) {
  final client = ref.watch(haWebSocketClientProvider);
  return Stream.fromFuture(LovelaceRepository(client).fetchConfig());
}, dependencies: [haWebSocketClientProvider]);

/// The default dashboard config as an [AsyncValue], the way the page consumes it.
///
/// A plain [Provider] wrapping [dashboardConfigStreamProvider] — mirroring how
/// `entityGroupsProvider` wraps `entityStatesProvider`. Reading the stream
/// through this regular provider keeps Riverpod's scoped-dependency resolution
/// happy: a widget that reads a `StreamProvider`/`FutureProvider` which
/// transitively depends on the overridden connection config trips the
/// scoped-override assertion, whereas a plain `Provider` layer does not.
/// `AppPage.async` maps the value onto its loading / error / empty surfaces.
final dashboardConfigProvider = Provider<AsyncValue<LovelaceConfig>>(
  (ref) => ref.watch(dashboardConfigStreamProvider),
  dependencies: [dashboardConfigStreamProvider],
);
