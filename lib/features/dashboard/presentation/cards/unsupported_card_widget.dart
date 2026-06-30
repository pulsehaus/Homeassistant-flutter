import 'package:flutter/material.dart';

import '../../domain/lovelace_card.dart';

/// The graceful-degradation surface for any card the app can't render — an
/// unknown `type`, or a known type whose body was malformed.
///
/// Shows a muted placeholder naming the offending type (so the gap is
/// diagnosable) instead of crashing the dashboard. This is what lets new card
/// types ship incrementally: an instance using cards we haven't implemented
/// still renders, just with placeholders for the unknown ones.
class UnsupportedCardWidget extends StatelessWidget {
  const UnsupportedCardWidget({required this.card, super.key});

  final UnsupportedCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Icon(
          Icons.help_outline,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(
          'Unsupported card: ${card.type}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
