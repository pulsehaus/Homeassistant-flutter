import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ha_rest_client.dart';
import '../data/ha_websocket_client.dart';
import '../domain/connection_status.dart';
import '../domain/entity_state.dart';
import '../domain/ha_connection_config.dart';

/// The active Home Assistant connection settings.
///
/// Has no default: it must be overridden in the root `ProviderScope` (or with
/// `ProviderScope.overrides`) once the user has supplied a server URL and a
/// long-lived access token. Reading it before then is a programming error.
final haConnectionConfigProvider = Provider<HaConnectionConfig>((ref) {
  throw UnimplementedError(
    'haConnectionConfigProvider must be overridden with a HaConnectionConfig. '
    'Override it in ProviderScope once the server URL and access token are '
    'known.',
  );
});

/// The singleton WebSocket client. Opens the connection on first read and is
/// disposed (closing the socket) when no longer listened to.
final haWebSocketClientProvider = Provider<HaWebSocketClient>((ref) {
  final client = HaWebSocketClient(
    config: ref.watch(haConnectionConfigProvider),
  );
  ref.onDispose(client.dispose);
  client.connect();
  return client;
}, dependencies: [haConnectionConfigProvider]);

/// The REST client, sharing the same configuration.
final haRestClientProvider = Provider<HaRestClient>((ref) {
  final client = HaRestClient(config: ref.watch(haConnectionConfigProvider));
  ref.onDispose(client.close);
  return client;
}, dependencies: [haConnectionConfigProvider]);

/// Live connection lifecycle (connecting / connected / reconnecting / error),
/// seeded with the current value so late subscribers get it immediately.
final connectionStateProvider = StreamProvider<HaConnectionState>((ref) async* {
  final client = ref.watch(haWebSocketClientProvider);
  yield client.connectionState;
  yield* client.connectionStates;
}, dependencies: [haWebSocketClientProvider]);

/// Live store of all entity states, keyed by entity id.
final entityStatesProvider = StreamProvider<Map<String, EntityState>>((
  ref,
) async* {
  final client = ref.watch(haWebSocketClientProvider);
  yield client.entities;
  yield* client.entityStates;
}, dependencies: [haWebSocketClientProvider]);

/// A single entity's current state, or null if unknown. Rebuilds only when that
/// entity changes (see [EntityState] equality).
final entityProvider = Provider.family<EntityState?, String>((ref, entityId) {
  final states = ref.watch(entityStatesProvider).value ?? const {};
  return states[entityId];
}, dependencies: [entityStatesProvider]);
