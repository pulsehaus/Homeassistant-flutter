import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/presentation/app_page.dart';
import '../application/dashboard_providers.dart';
import '../domain/lovelace_card.dart';
import '../domain/lovelace_config.dart';
import 'cards/entities_card_widget.dart';
import 'cards/entity_card_widget.dart';
import 'cards/unsupported_card_widget.dart';

/// Renders the default Lovelace dashboard fetched from Home Assistant.
///
/// Thin [ConsumerWidget] on [AppPage.async]: [dashboardConfigProvider] feeds the
/// loading / error / empty surfaces, and the first view's cards are rendered
/// through [_cardWidget]. Only the first view is shown for now (see the issue's
/// minimal scope).
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(dashboardConfigProvider);

    return AppPage.async<LovelaceConfig>(
      title: 'Dashboard',
      value: config,
      isEmpty: (c) => c.firstView == null || c.firstView!.cards.isEmpty,
      emptyMessage: 'No dashboard cards yet.',
      onRetry: () => ref.invalidate(dashboardConfigStreamProvider),
      builder: (context, c) => ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [for (final card in c.firstView!.cards) _cardWidget(card)],
      ),
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
    final UnsupportedCard c => UnsupportedCardWidget(card: c),
  };
}
