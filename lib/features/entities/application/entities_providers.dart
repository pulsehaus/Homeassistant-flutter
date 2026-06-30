import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../connection/application/connection_providers.dart';
import '../domain/entity_group.dart';

/// The live entity store, grouped into per-domain sections for the overview.
///
/// Derives from [entityStatesProvider] (the connection layer's live
/// `Map<String, EntityState>`), so it inherits its loading/error states and
/// re-emits whenever a `state_changed` event updates the store — the overview
/// then rebuilds with the new grouping. The pure grouping/sorting logic lives in
/// [groupEntitiesByDomain]; this provider only wires it to Riverpod.
final entityGroupsProvider = Provider<AsyncValue<List<EntityGroup>>>((ref) {
  final states = ref.watch(entityStatesProvider);
  return states.whenData(groupEntitiesByDomain);
}, dependencies: [entityStatesProvider]);
