import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../connection/application/connection_providers.dart';
import '../../../connection/domain/entity_state.dart';
import '../../domain/lovelace_card.dart';

/// Renders an `entity` card: a single entity's label and its live state.
///
/// A [ConsumerWidget] watching [entityProvider] so the trailing state stays in
/// sync with the live store. The label precedence is: the card's explicit
/// `name` → the entity's friendly name → the entity id.
class EntityCardWidget extends ConsumerWidget {
  const EntityCardWidget({required this.card, super.key});

  final EntityCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final entity = ref.watch(entityProvider(card.entityId));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(
          cardEntityLabel(card.name, entity, card.entityId),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          entity?.state ?? 'unavailable',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Resolves the label for a Lovelace entity/row: an explicit config [name] wins,
/// otherwise the entity's friendly name, otherwise the raw [fallbackId]. Shared
/// by the entity and entities cards so they label consistently.
String cardEntityLabel(String? name, EntityState? entity, String fallbackId) {
  if (name != null && name.trim().isNotEmpty) return name;
  final friendly = entity?.friendlyName;
  if (friendly != null && friendly.trim().isNotEmpty) return friendly;
  return fallbackId;
}
