import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../connection/application/connection_providers.dart';
import '../../../connection/domain/entity_state.dart';
import '../../../entities/application/entity_toggle_controller.dart';
import '../../../entities/domain/entity_toggle.dart';
import '../../domain/lovelace_card.dart';
import 'entity_card_widget.dart' show cardEntityLabel;

/// Renders a `button` card: a compact, tappable tile showing an icon, an
/// optional name and (optionally) the entity's state.
///
/// v1 scope (see #57): tapping toggles the entity when it resolves to a
/// toggleable domain ([EntityToggle.isToggleable] — `light`/`switch`), reusing
/// the same controller and optimistic-then-reconcile pattern as
/// `EntitiesOverviewPage`'s `_EntityTile` (#27) rather than duplicating the
/// toggle mapping. Tapping a non-toggleable or entity-less button does
/// nothing — other `tap_action` types (navigate, more-info, custom
/// call-service) are out of scope for this card until a follow-up models
/// `tap_action` itself.
class ButtonCardWidget extends ConsumerStatefulWidget {
  const ButtonCardWidget({required this.card, super.key});

  final ButtonCard card;

  @override
  ConsumerState<ButtonCardWidget> createState() => _ButtonCardWidgetState();
}

class _ButtonCardWidgetState extends ConsumerState<ButtonCardWidget> {
  /// Optimistic on/off shown while a toggle is in flight, mirroring
  /// `_EntityTile`. Cleared once the live state matches what was requested, or
  /// on failure (rollback).
  bool? _pending;

  ButtonCard get _card => widget.card;

  @override
  void didUpdateWidget(ButtonCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final entity = _card.entityId == null
        ? null
        : ref.read(entityProvider(_card.entityId!));
    if (_pending != null &&
        entity != null &&
        EntityToggle.isOn(entity) == _pending) {
      _pending = null;
    }
  }

  Future<void> _onTap(EntityState? entity) async {
    if (entity == null || !EntityToggle.isToggleable(entity)) {
      // Entity-less or non-toggleable button: inert in v1 scope.
      return;
    }
    final on = !(_pending ?? EntityToggle.isOn(entity));
    setState(() => _pending = on);
    final result = await ref
        .read(entityToggleControllerProvider)
        .toggle(entity, on: on);
    if (!mounted) return;
    if (!result.isSuccess) {
      setState(() => _pending = null);
      final message = (result as ToggleFailure).message;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entity = _card.entityId == null
        ? null
        : ref.watch(entityProvider(_card.entityId!));
    final isOn = entity != null && (_pending ?? EntityToggle.isOn(entity));

    final label = _card.entityId == null
        ? (_card.name ?? 'Button')
        : cardEntityLabel(_card.name, entity, _card.entityId!);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () => _onTap(entity),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(
                _resolveIcon(_card.icon, entity),
                color: isOn ? theme.colorScheme.primary : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_card.showName)
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    if (_card.showState)
                      Text(
                        entity?.state ?? 'unavailable',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resolves the icon to show for a button card.
///
/// HA's `icon` config field is an MDI icon *name* (e.g. `mdi:lightbulb`), and
/// this app has no MDI-name-to-[IconData] mapping (would need an extra
/// package such as `material_design_icons_flutter` — left for a follow-up).
/// Rather than silently drop an explicit `icon` or crash, an icon name present
/// in the config is treated as a signal that *some* icon was requested and
/// falls back to a domain-based default, same idea as other cards inferring
/// defaults from the entity's domain. Absent both, a generic button icon is
/// used.
IconData _resolveIcon(String? icon, EntityState? entity) {
  final domain = entity?.domain;
  if (domain != null) {
    final byDomain = _domainIcons[domain];
    if (byDomain != null) return byDomain;
  }
  return icon != null ? Icons.touch_app_outlined : Icons.smart_button_outlined;
}

/// Small set of domain -> default-icon fallbacks, mirroring the common
/// domains this app already treats specially (see [EntityToggle]).
const Map<String, IconData> _domainIcons = {
  'light': Icons.lightbulb_outline,
  'switch': Icons.toggle_on_outlined,
};
