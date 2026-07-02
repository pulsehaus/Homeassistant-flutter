import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/presentation/app_page.dart';
import '../../connection/presentation/connection_status_indicator.dart';
import '../application/dashboard_providers.dart';
import '../domain/lovelace_card.dart';
import '../domain/lovelace_config.dart';
import 'cards/button_card_widget.dart';
import 'cards/entities_card_widget.dart';
import 'cards/entity_card_widget.dart';
import 'cards/gauge_card_widget.dart';
import 'cards/glance_card_widget.dart';
import 'cards/history_graph_card_widget.dart';
import 'cards/unsupported_card_widget.dart';

/// Renders the default Lovelace dashboard fetched from Home Assistant.
///
/// [ConsumerStatefulWidget] on [AppPage.async]: [dashboardConfigProvider] feeds
/// the loading / error / empty surfaces, and the selected view's cards are
/// rendered through [_cardWidget]. When [LovelaceConfig.views] holds more than
/// one view, a [TabBar] (built from each view's `title`) lets the user switch
/// between them; a single-view config renders that view directly with no
/// tab/switcher chrome, matching the pre-#58 behaviour (see the issue).
///
/// The state is a [ConsumerStatefulWidget] (rather than the previous
/// [ConsumerWidget]) purely to own the [TabController] — a [TabController]
/// needs a [TickerProvider], hence [SingleTickerProviderStateMixin] — and to
/// rebuild it if the fetched config's view count ever changes across a config
/// reload (rare, but cheap to handle correctly).
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  int _viewCount = 0;

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  /// (Re)creates [_tabController] when the number of views changes, so a
  /// config reload that adds/removes views doesn't crash a stale controller
  /// (a [TabController]'s `length` is immutable once constructed).
  TabController _controllerFor(int viewCount) {
    if (_tabController == null || _viewCount != viewCount) {
      _tabController?.dispose();
      _tabController = TabController(length: viewCount, vsync: this);
      _viewCount = viewCount;
    }
    return _tabController!;
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(dashboardConfigProvider);

    return AppPage.async<LovelaceConfig>(
      title: 'Dashboard',
      value: config,
      isEmpty: (c) => c.firstView == null || c.firstView!.cards.isEmpty,
      emptyBuilder: (context) => const _NoDashboardCardsEmptyState(),
      onRetry: () => ref.invalidate(dashboardConfigStreamProvider),
      connectionIndicator: const ConnectionStatusIndicator(),
      builder: (context, c) {
        final views = c.views;

        // Common case: a single view. Render it directly with no tab chrome.
        if (views.length <= 1) {
          return _ViewCards(view: c.firstView!);
        }

        final tabController = _controllerFor(views.length);
        return Column(
          children: [
            TabBar(
              controller: tabController,
              isScrollable: true,
              tabs: [
                for (var i = 0; i < views.length; i++)
                  Tab(text: views[i].title ?? 'View ${i + 1}'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: tabController,
                children: [for (final view in views) _ViewCards(view: view)],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Renders one [LovelaceView]'s cards, in order, through [_cardWidget].
class _ViewCards extends StatelessWidget {
  const _ViewCards({required this.view});

  final LovelaceView view;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [for (final card in view.cards) _cardWidget(card)],
    );
  }

  /// Render dispatcher — the only place a card's runtime type is matched.
  ///
  /// To support a new card type: add a sealed [LovelaceCard] subclass, a `case`
  /// in `cardFromJson`, a new `*_card_widget.dart`, and one arm here. The
  /// analyzer reports this `switch` as non-exhaustive until the arm exists, so
  /// the open/closed contract is compiler-enforced.
  Widget _cardWidget(LovelaceCard card) => switch (card) {
    final EntityCard c => EntityCardWidget(card: c),
    final EntitiesCard c => EntitiesCardWidget(card: c),
    final HistoryGraphCard c => HistoryGraphCardWidget(card: c),
    final ButtonCard c => ButtonCardWidget(card: c),
    final GaugeCard c => GaugeCardWidget(card: c),
    final GlanceCard c => GlanceCardWidget(card: c),
    final UnsupportedCard c => UnsupportedCardWidget(card: c),
  };
}

/// Empty surface shown when the fetched Lovelace config's current view has no
/// cards configured (#62). Mirrors [AppPage]'s shared `_EmptyState` (themed
/// icon + message, centred) but swaps the generic inbox icon for a
/// dashboard/layout-related one and spells out *why* nothing is showing —
/// the view was fetched successfully, it just has no cards yet — so a blank
/// screen reads as an expected state rather than a broken fetch.
class _NoDashboardCardsEmptyState extends StatelessWidget {
  const _NoDashboardCardsEmptyState();

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
              Icons.dashboard_customize_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No dashboard cards yet',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This view was fetched from Home Assistant, but it has no '
              'cards configured. Add some to your Lovelace dashboard and '
              'they will show up here.',
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
