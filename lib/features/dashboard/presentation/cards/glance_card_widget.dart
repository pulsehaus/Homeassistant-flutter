import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../connection/application/connection_providers.dart';
import '../../../connection/domain/entity_state.dart';
import '../../domain/lovelace_card.dart';
import 'entity_card_widget.dart' show cardEntityLabel;

/// Renders a `glance` card: an optional title and a compact grid of entity
/// tiles (icon + name + state), each element individually toggleable via
/// [GlanceCard.showName] / [GlanceCard.showIcon] / [GlanceCard.showState].
///
/// The grid, not the `entities` card's list layout, is what makes a `glance`
/// card an "at-a-glance" overview: [GlanceCard.columns] picks the column
/// count when set, otherwise [_defaultColumns] scales with the available
/// width.
class GlanceCardWidget extends StatelessWidget {
  const GlanceCardWidget({required this.card, super.key});

  final GlanceCard card;

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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(card.title!, style: theme.textTheme.titleMedium),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = card.columns ?? _defaultColumns(constraints);
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: 88,
                  ),
                  itemCount: card.rows.length,
                  itemBuilder: (context, index) =>
                      _GlanceTile(row: card.rows[index], card: card),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// A sensible default column count when HA's config doesn't set `columns`:
  /// scales with the available width so tiles stay a reasonable size on both
  /// phones and wider screens, matching HA frontend's own auto-fit behaviour.
  static int _defaultColumns(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    if (width.isFinite && width > 0) {
      final columns = (width / 90).floor();
      return columns.clamp(3, 6);
    }
    return 4;
  }
}

/// One tile of a glance card: icon, name and state, each individually
/// omittable per the card's `show_*` flags. A [ConsumerWidget] so only the
/// changed tile rebuilds when its entity updates.
class _GlanceTile extends ConsumerWidget {
  const _GlanceTile({required this.row, required this.card});

  final EntitiesRow row;
  final GlanceCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final entity = ref.watch(entityProvider(row.entityId));

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (card.showIcon)
          Icon(
            _iconFor(entity, row.entityId),
            color: theme.colorScheme.onSurfaceVariant,
          ),
        if (card.showState)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              entity?.state ?? 'unavailable',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (card.showName)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              cardEntityLabel(row.name, entity, row.entityId),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  /// A minimal domain-based icon lookup for the glance grid — good enough to
  /// tell entity kinds apart at a glance without pulling in HA's full icon
  /// set. Falls back to a generic dot for domains without a specific icon.
  IconData _iconFor(EntityState? entity, String fallbackId) {
    final domain = entity?.domain ?? _domainOf(fallbackId);
    return switch (domain) {
      'light' => Icons.lightbulb_outline,
      'switch' => Icons.toggle_on_outlined,
      'binary_sensor' => Icons.sensors,
      'sensor' => Icons.speed,
      'climate' => Icons.thermostat,
      'cover' => Icons.blinds,
      'lock' => Icons.lock_outline,
      'fan' => Icons.mode_fan_off,
      'media_player' => Icons.smart_display,
      'person' => Icons.person_outline,
      'device_tracker' => Icons.my_location,
      _ => Icons.fiber_manual_record_outlined,
    };
  }

  String _domainOf(String entityId) {
    final dot = entityId.indexOf('.');
    return dot == -1 ? entityId : entityId.substring(0, dot);
  }
}
