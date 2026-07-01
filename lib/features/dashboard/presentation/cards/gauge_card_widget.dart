import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../connection/application/connection_providers.dart';
import '../../domain/lovelace_card.dart';
import 'entity_card_widget.dart' show cardEntityLabel;

/// Renders a `gauge` card: the entity's live numeric state as a
/// [CircularProgressIndicator] clamped to `[min, max]`, labelled with the
/// value, unit and name/entity id.
///
/// A [ConsumerWidget] watching [entityProvider] so the gauge stays in sync
/// with the live store. A non-numeric or missing state falls back to a
/// muted placeholder rather than crashing — the same graceful-degradation
/// spirit as [UnsupportedCard], but scoped to this one card since the config
/// itself was valid.
class GaugeCardWidget extends ConsumerWidget {
  const GaugeCardWidget({required this.card, super.key});

  final GaugeCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final entity = ref.watch(entityProvider(card.entityId));
    final label = cardEntityLabel(card.name, entity, card.entityId);
    final rawValue = entity == null ? null : double.tryParse(entity.state);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (rawValue == null)
              _GaugePlaceholder(theme: theme)
            else
              _Gauge(
                value: rawValue,
                unit:
                    card.unit ??
                    entity?.attributes['unit_of_measurement'] as String?,
                min: card.min,
                max: card.max,
                severity: card.severity,
                theme: theme,
              ),
          ],
        ),
      ),
    );
  }
}

/// The numeric gauge itself: a [CircularProgressIndicator] driven by the
/// value's fraction of `[min, max]`, with the value + unit stacked in the
/// centre.
class _Gauge extends StatelessWidget {
  const _Gauge({
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.severity,
    required this.theme,
  });

  final double value;
  final String? unit;
  final double min;
  final double max;
  final GaugeSeverity? severity;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(min, max);
    final range = max - min;
    final fraction = range == 0 ? 0.0 : (clamped - min) / range;
    final color = _severityColor(clamped, severity, theme);

    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CircularProgressIndicator(
              value: fraction,
              strokeWidth: 10,
              color: color,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatValue(value),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (unit != null && unit!.trim().isNotEmpty)
                Text(unit!, style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatValue(double value) {
    // Whole numbers render without a trailing ".0" (e.g. HA's own gauge card).
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  /// HA colours the gauge by walking the thresholds top-down: at or above
  /// [GaugeSeverity.red] is red, at or above [GaugeSeverity.yellow] (and
  /// below `red`) is yellow, otherwise green. Absent thresholds are simply
  /// skipped in that walk. No `severity` at all keeps the theme's default
  /// indicator colour.
  static Color? _severityColor(
    double value,
    GaugeSeverity? severity,
    ThemeData theme,
  ) {
    if (severity == null) return null;
    final red = severity.red;
    if (red != null && value >= red) return Colors.red;
    final yellow = severity.yellow;
    if (yellow != null && value >= yellow) return Colors.amber;
    return Colors.green;
  }
}

/// Shown when the entity's state can't be parsed as a number (or the entity
/// is missing) — a valid `gauge` config with an unusable live value, so the
/// card itself still renders rather than dropping to [UnsupportedCard].
class _GaugePlaceholder extends StatelessWidget {
  const _GaugePlaceholder({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.speed_outlined,
            size: 32,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'unavailable',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
