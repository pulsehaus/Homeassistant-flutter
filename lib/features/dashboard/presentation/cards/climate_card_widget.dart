import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../connection/application/connection_providers.dart';
import '../../../connection/domain/entity_state.dart';
import '../../../entities/application/climate_control_controller.dart';
import '../../../entities/domain/climate_control.dart';
import '../../domain/lovelace_card.dart';
import 'entity_card_widget.dart' show cardEntityLabel;

/// Renders a `climate` card: a thermostat/AC/heat-pump entity showing the
/// current temperature, the target temperature and the `hvac_mode`, with
/// controls to adjust both.
///
/// A [ConsumerStatefulWidget] (like `ButtonCardWidget`) so it can hold an
/// optimistic target temperature while a `set_temperature` call is in
/// flight, reconciling from the live entity once the resulting
/// `state_changed` event lands — the same optimistic-then-reconcile pattern
/// as the button card's toggle, applied to a numeric value instead of a
/// boolean. `hvac_mode` changes are dispatched directly without local
/// optimistic state since the dropdown already reflects the pending
/// selection via the live entity once HA processes it; a failed call simply
/// reverts to the entity's real mode on the next build.
class ClimateCardWidget extends ConsumerStatefulWidget {
  const ClimateCardWidget({required this.card, super.key});

  final ClimateCard card;

  @override
  ConsumerState<ClimateCardWidget> createState() => _ClimateCardWidgetState();
}

class _ClimateCardWidgetState extends ConsumerState<ClimateCardWidget> {
  /// Optimistic target temperature shown while a `set_temperature` call is in
  /// flight, mirroring `ButtonCardWidget._pending`. Cleared once the live
  /// state matches what was requested, or on failure (rollback).
  double? _pendingTemperature;

  ClimateCard get _card => widget.card;

  @override
  void didUpdateWidget(ClimateCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final entity = ref.read(entityProvider(_card.entityId));
    if (_pendingTemperature != null &&
        entity != null &&
        ClimateControl.targetTemperature(entity) == _pendingTemperature) {
      _pendingTemperature = null;
    }
  }

  Future<void> _adjustTemperature(EntityState entity, double delta) async {
    final current =
        _pendingTemperature ?? ClimateControl.targetTemperature(entity);
    if (current == null) return;
    final next = current + delta;
    setState(() => _pendingTemperature = next);
    final result = await ref
        .read(climateControlControllerProvider)
        .setTemperature(entity, temperature: next);
    if (!mounted) return;
    if (!result.isSuccess) {
      setState(() => _pendingTemperature = null);
      _showError((result as ClimateActionFailure).message);
    }
  }

  Future<void> _changeMode(EntityState entity, String mode) async {
    final result = await ref
        .read(climateControlControllerProvider)
        .setHvacMode(entity, mode);
    if (!mounted) return;
    if (!result.isSuccess) {
      _showError((result as ClimateActionFailure).message);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entity = ref.watch(entityProvider(_card.entityId));
    final label = cardEntityLabel(_card.name, entity, _card.entityId);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: entity == null
            ? _ClimatePlaceholder(theme: theme, label: label)
            : _ClimateBody(
                entity: entity,
                label: label,
                pendingTemperature: _pendingTemperature,
                onAdjustTemperature: (delta) =>
                    _adjustTemperature(entity, delta),
                onChangeMode: (mode) => _changeMode(entity, mode),
              ),
      ),
    );
  }
}

/// The live content of a climate card: name, current/target temperature and
/// the `hvac_mode` control. Split out of the state's `build` purely for
/// readability.
class _ClimateBody extends StatelessWidget {
  const _ClimateBody({
    required this.entity,
    required this.label,
    required this.pendingTemperature,
    required this.onAdjustTemperature,
    required this.onChangeMode,
  });

  final EntityState entity;
  final String label;
  final double? pendingTemperature;
  final ValueChanged<double> onAdjustTemperature;
  final ValueChanged<String> onChangeMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = ClimateControl.currentTemperature(entity);
    final target =
        pendingTemperature ?? ClimateControl.targetTemperature(entity);
    final step = ClimateControl.temperatureStep(entity);
    final mode = ClimateControl.hvacMode(entity);
    final modes = ClimateControl.hvacModes(entity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          current == null
              ? 'Current: unavailable'
              : 'Current: ${_formatTemperature(current)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Decrease target temperature',
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: target == null
                  ? null
                  : () => onAdjustTemperature(-step),
            ),
            SizedBox(
              width: 96,
              child: Text(
                target == null ? '--' : _formatTemperature(target),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Increase target temperature',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: target == null
                  ? null
                  : () => onAdjustTemperature(step),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('Mode', style: theme.textTheme.bodyMedium),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButton<String>(
                isExpanded: true,
                value: modes.contains(mode) ? mode : null,
                hint: Text(mode),
                items: [
                  for (final m in modes)
                    DropdownMenuItem(value: m, child: Text(m)),
                ],
                onChanged: (value) {
                  if (value != null) onChangeMode(value);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _formatTemperature(double value) {
    // Whole numbers render without a trailing ".0", matching the gauge card.
    if (value == value.roundToDouble()) return '${value.toStringAsFixed(0)}°';
    return '${value.toStringAsFixed(1)}°';
  }
}

/// Shown when the climate entity isn't in the live store yet (or has gone
/// missing) — a valid `climate` config with no usable live value, the same
/// graceful-degradation spirit as `GaugeCardWidget`'s placeholder.
class _ClimatePlaceholder extends StatelessWidget {
  const _ClimatePlaceholder({required this.theme, required this.label});

  final ThemeData theme;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.thermostat_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              'unavailable',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
