import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../connection/application/connection_providers.dart';
import '../../connection/domain/connection_status.dart';
import '../../connection/domain/ha_exception.dart';
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
/// `lovelace/config` needs a live socket, so on a cold start the fetch races the
/// WebSocket handshake. To avoid surfacing a spurious "disconnected" error (and
/// a manual Retry), the stream **gates on the connection becoming `connected`**:
/// while the socket is still connecting it stays loading (yields nothing), then
/// fetches automatically once connected. A fatal connection error (e.g. an
/// invalid token → [HaConnectionStatus.error]) is rethrown so the page surfaces
/// it instead of spinning forever.
final dashboardConfigStreamProvider = StreamProvider<LovelaceConfig>((
  ref,
) async* {
  final client = ref.watch(haWebSocketClientProvider);

  // Wait for the socket to be ready before fetching. If it isn't connected yet,
  // watch the lifecycle until it connects (proceed) or fails fatally (throw).
  if (!client.connectionState.isConnected) {
    await for (final state in client.connectionStates) {
      if (state.isConnected) break;
      if (state.status == HaConnectionStatus.error) {
        throw state.error ?? const HaConnectionException('Connection failed');
      }
    }
  }

  yield await LovelaceRepository(client).fetchConfig();
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
