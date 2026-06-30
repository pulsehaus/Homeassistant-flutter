import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../connection/application/connection_providers.dart';
import '../../domain/lovelace_card.dart';
import 'entity_card_widget.dart' show cardEntityLabel;

/// Renders an `entities` card: an optional title and one tile per row, each
/// reading its entity's live state from the store.
class EntitiesCardWidget extends StatelessWidget {
  const EntitiesCardWidget({required this.card, super.key});

  final EntitiesCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTitle = card.title != null && card.title!.trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasTitle)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(card.title!, style: theme.textTheme.titleMedium),
            ),
          for (final row in card.rows) _EntitiesRowTile(row: row),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// One row of an entities card: its label and live trailing state. A
/// [ConsumerWidget] so only the changed row rebuilds when its entity updates.
class _EntitiesRowTile extends ConsumerWidget {
  const _EntitiesRowTile({required this.row});

  final EntitiesRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final entity = ref.watch(entityProvider(row.entityId));

    return ListTile(
      dense: true,
      title: Text(
        cardEntityLabel(row.name, entity, row.entityId),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        entity?.state ?? 'unavailable',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
