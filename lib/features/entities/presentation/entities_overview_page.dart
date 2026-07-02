import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/presentation/app_page.dart';
import '../../connection/domain/entity_state.dart';
import '../../connection/presentation/connection_status_indicator.dart';
import '../application/entities_providers.dart';
import '../application/entity_toggle_controller.dart';
import '../domain/entity_group.dart';
import '../domain/entity_toggle.dart';
import '../domain/relative_time.dart';

/// Overview screen listing every known entity from the live store, grouped into
/// per-domain sections (`light`, `sensor`, `switch`, …).
///
/// Built on [AppPage.async]: the connection layer's [entityGroupsProvider] feeds
/// an [AsyncValue], so loading / error / empty all use the shared template
/// surfaces (#3). Because the underlying store is a stream, the list rebuilds
/// live as `state_changed` events arrive. The grouping/sorting itself is the
/// pure [groupEntitiesByDomain]; this widget stays a thin renderer.
///
/// A search field above the list lets the user narrow entities by name or
/// entity id (#77). The query is local UI state — it doesn't affect what the
/// live store holds, only what this screen renders — so it's a
/// [ConsumerStatefulWidget] rather than a Riverpod provider. Filtering itself
/// is the pure [filterEntityGroups], applied to the already-grouped data.
class EntitiesOverviewPage extends ConsumerStatefulWidget {
  const EntitiesOverviewPage({super.key});

  @override
  ConsumerState<EntitiesOverviewPage> createState() =>
      _EntitiesOverviewPageState();
}

class _EntitiesOverviewPageState extends ConsumerState<EntitiesOverviewPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(entityGroupsProvider);

    return AppPage.async<List<EntityGroup>>(
      title: 'Entities',
      value: groups,
      isEmpty: (data) => data.isEmpty,
      emptyBuilder: (context) => const _NoEntitiesEmptyState(),
      connectionIndicator: const ConnectionStatusIndicator(),
      builder: (context, data) {
        final filtered = filterEntityGroups(data, _query);
        return Column(
          children: [
            _EntitySearchField(
              controller: _searchController,
              onChanged: _onSearchChanged,
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const _NoSearchResultsEmptyState()
                  : _EntitiesList(groups: filtered),
            ),
          ],
        );
      },
    );
  }
}

/// Search field shown above the entities list, filtering by name or entity id
/// as the user types (#77).
class _EntitySearchField extends StatelessWidget {
  const _EntitySearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search entities',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          isDense: true,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
    );
  }
}

/// Empty surface shown when a search query matches no entities, distinct from
/// [_NoEntitiesEmptyState] (which covers the store being genuinely empty) so
/// the message reflects a filter the user can clear rather than a connection
/// issue.
class _NoSearchResultsEmptyState extends StatelessWidget {
  const _NoSearchResultsEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No matching entities',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different name or entity id.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty surface shown when the live entity store hasn't produced any
/// entities yet (#62). Mirrors [AppPage]'s shared `_EmptyState` (themed icon +
/// message, centred) but swaps the generic inbox icon for one that reads as
/// "devices/entities" and spells out the two reasons the list can be empty —
/// still connecting, or the instance genuinely has none — since entities
/// stream in live and a blank list otherwise reads as broken rather than
/// empty.
class _NoEntitiesEmptyState extends StatelessWidget {
  const _NoEntitiesEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sensors_off,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No entities yet',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Entities appear here as soon as they stream in from Home '
              'Assistant. If you just connected, give it a moment — '
              'otherwise this instance may not expose any yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
/// subtitle, and a trailing control.
///
/// For controllable entities ([EntityToggle.isToggleable] — `light`, `switch`)
/// the trailing edge is a [Switch] that issues a `call_service`; for everything
/// else it's the read-only state text. Dimmable lights ([EntityToggle.isDimmable]
/// — a `light` reporting a `brightness` attribute) additionally show a
/// brightness [Slider] beneath the title row, alongside the on/off switch
/// rather than replacing it, so the switch keeps its familiar quick on/off
/// behavior and the slider is purely an extra level of control (#75). Below the
/// control, a small relative-time label (e.g. "2 minutes ago", via
/// [RelativeTime]) shows how long ago the entity last changed/updated (#78), so
/// it's easy to tell whether a sensor is actually still reporting. A
/// [ConsumerWidget] so both controls can read the [entityToggleControllerProvider].
class _EntityTile extends ConsumerStatefulWidget {
  const _EntityTile({required this.entity});

  final EntityState entity;

  @override
  ConsumerState<_EntityTile> createState() => _EntityTileState();
}

class _EntityTileState extends ConsumerState<_EntityTile> {
  /// Optimistic position shown while a toggle is in flight. Cleared once the
  /// real `state_changed` arrives (or on failure), so the switch always
  /// reconciles with the entity's true state.
  bool? _pending;

  /// Optimistic brightness (0-255) shown while a slider drag is in flight.
  /// Cleared once the real `state_changed` arrives (or on failure), mirroring
  /// [_pending] for the on/off switch.
  int? _pendingBrightness;

  EntityState get _entity => widget.entity;

  @override
  void didUpdateWidget(_EntityTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A fresh state from the live store has landed: drop the optimistic value
    // once it matches what we asked for (or whenever a new state supersedes it).
    if (_pending != null && EntityToggle.isOn(_entity) == _pending) {
      _pending = null;
    }
    if (_pendingBrightness != null &&
        EntityToggle.brightness(_entity) == _pendingBrightness) {
      _pendingBrightness = null;
    }
  }

  Future<void> _onToggle(bool on) async {
    setState(() => _pending = on);
    final result = await ref
        .read(entityToggleControllerProvider)
        .toggle(_entity, on: on);
    if (!mounted) return;
    if (!result.isSuccess) {
      // Roll the optimistic position back and surface the reason.
      setState(() => _pending = null);
      _showFailure(result);
    }
  }

  Future<void> _onBrightnessChanged(double value) async {
    final brightness = value.round();
    setState(() => _pendingBrightness = brightness);
    final result = await ref
        .read(entityToggleControllerProvider)
        .setBrightness(_entity, brightness);
    if (!mounted) return;
    if (!result.isSuccess) {
      setState(() => _pendingBrightness = null);
      _showFailure(result);
    }
  }

  void _showFailure(ToggleResult result) {
    final message = (result as ToggleFailure).message;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = _entity.friendlyName;
    final hasName = name != null && name.trim().isNotEmpty;
    final toggleable = EntityToggle.isToggleable(_entity);
    final dimmable = EntityToggle.isDimmable(_entity);

    return ListTile(
      dense: true,
      title: Text(
        hasName ? name : _entity.entityId,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      // Only show the id as a subtitle when it isn't already the title.
      subtitle: dimmable
          ? _BrightnessSlider(
              value: _pendingBrightness ?? EntityToggle.brightness(_entity)!,
              onChanged: _onBrightnessChanged,
              entityIdLabel: hasName ? _entity.entityId : null,
            )
          : hasName
          ? Text(
              _entity.entityId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: _EntityTrailing(
        control: toggleable
            ? Switch(
                value: _pending ?? EntityToggle.isOn(_entity),
                onChanged: _onToggle,
              )
            : Text(
                _entity.state,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
        lastChanged: _entity.lastUpdated ?? _entity.lastChanged,
      ),
    );
  }
}

/// The tile's trailing edge: the entity's [control] (a [Switch] or its state
/// as text) plus, beneath it, a small relative-time label derived from
/// [lastChanged] via [RelativeTime] (e.g. "2 minutes ago") (#78). The label is
/// omitted when HA hasn't reported a timestamp for this entity.
///
/// Kept as its own widget so [_EntityTileState] stays focused on state
/// management rather than layout, mirroring [_BrightnessSlider] below.
class _EntityTrailing extends StatelessWidget {
  const _EntityTrailing({required this.control, required this.lastChanged});

  /// The entity's primary control: a [Switch] for toggleable entities, or its
  /// current state as read-only text.
  final Widget control;

  /// The timestamp to render as a relative age, or null when the entity
  /// hasn't reported one.
  final DateTime? lastChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastChanged = this.lastChanged;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        control,
        if (lastChanged != null)
          Text(
            RelativeTime.format(lastChanged),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// The brightness row shown under a dimmable light's title: the entity id
/// (when it isn't already the title, matching the plain-toggle layout) and a
/// [Slider] spanning the 0-255 HA brightness range.
///
/// Kept as its own widget so [_EntityTileState] stays focused on state
/// management rather than layout.
class _BrightnessSlider extends StatelessWidget {
  const _BrightnessSlider({
    required this.value,
    required this.onChanged,
    required this.entityIdLabel,
  });

  /// Current (or optimistic) brightness, 0-255.
  final int value;

  /// Called with the new 0-255 brightness whenever the slider moves.
  final ValueChanged<double> onChanged;

  /// The entity id to show above the slider, or null when the title already
  /// shows it (mirrors the plain-toggle subtitle rule).
  final String? entityIdLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (entityIdLabel != null)
          Text(
            entityIdLabel!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        SliderTheme(
          data: SliderTheme.of(
            context,
          ).copyWith(trackHeight: 2, padding: EdgeInsets.zero),
          child: Slider(
            value: value.clamp(0, 255).toDouble(),
            min: 0,
            max: 255,
            label: '$value',
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
