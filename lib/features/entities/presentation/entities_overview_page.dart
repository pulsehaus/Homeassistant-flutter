import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/presentation/app_page.dart';
import '../../connection/domain/entity_state.dart';
import '../application/entities_providers.dart';
import '../domain/entity_group.dart';

/// Overview screen listing every known entity from the live store, grouped into
/// per-domain sections (`light`, `sensor`, `switch`, …).
///
/// Built on [AppPage.async]: the connection layer's [entityGroupsProvider] feeds
/// an [AsyncValue], so loading / error / empty all use the shared template
/// surfaces (#3). Because the underlying store is a stream, the list rebuilds
/// live as `state_changed` events arrive. The grouping/sorting itself is the
/// pure [groupEntitiesByDomain]; this widget stays a thin renderer.
class EntitiesOverviewPage extends ConsumerWidget {
  const EntitiesOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(entityGroupsProvider);

    return AppPage.async<List<EntityGroup>>(
      title: 'Entities',
      value: groups,
      isEmpty: (data) => data.isEmpty,
      emptyMessage:
          'No entities yet.\nConnect an instance to see its entities here.',
      builder: (context, data) => _EntitiesList(groups: data),
    );
  }
}

/// A sectioned, scrollable list of the grouped entities. Each domain is a
/// sticky-free section header followed by its entities, so the list stays
/// readable even with hundreds of entities.
class _EntitiesList extends StatelessWidget {
  const _EntitiesList({required this.groups});

  final List<EntityGroup> groups;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      // A small bottom inset keeps the last row clear of the navigation bar.
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _itemCount,
      itemBuilder: (context, index) => _itemAt(context, index),
    );
  }

  // The flat list is: [header, ...entities] per group, concatenated. Computing
  // the total and resolving an index avoids materialising a second list.
  int get _itemCount {
    var total = 0;
    for (final group in groups) {
      total += 1 + group.entities.length;
    }
    return total;
  }

  Widget _itemAt(BuildContext context, int index) {
    var cursor = index;
    for (final group in groups) {
      if (cursor == 0) {
        return _DomainHeader(domain: group.domain, count: group.count);
      }
      cursor -= 1;
      if (cursor < group.entities.length) {
        return _EntityTile(entity: group.entities[cursor]);
      }
      cursor -= group.entities.length;
    }
    // Unreachable given a correct _itemCount, but keep the builder total.
    return const SizedBox.shrink();
  }
}

/// Section header for one domain, e.g. "Light · 4".
class _DomainHeader extends StatelessWidget {
  const _DomainHeader({required this.domain, required this.count});

  final String domain;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _titleCase(domain),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$count',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  static String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}

/// One entity row: friendly name (or entity id) as the title, the entity id as a
/// subtitle, and the current state on the trailing edge.
class _EntityTile extends StatelessWidget {
  const _EntityTile({required this.entity});

  final EntityState entity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = entity.friendlyName;
    final hasName = name != null && name.trim().isNotEmpty;

    return ListTile(
      dense: true,
      title: Text(
        hasName ? name : entity.entityId,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      // Only show the id as a subtitle when it isn't already the title.
      subtitle: hasName
          ? Text(
              entity.entityId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: Text(
        entity.state,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
