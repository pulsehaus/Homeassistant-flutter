/// The trailing windows offered by the history screen's range selector.
///
/// Each option maps 1:1 to a [Duration] fed into `EntityHistoryRequest.period`
/// (`entity_history_page.dart`) — switching options re-keys the
/// `entityHistorySeriesProvider` family, so Riverpod fetches (and
/// independently caches) the new window.
///
/// Lives in `domain` (rather than `presentation`, where it originated) so the
/// persistence layer (`ChartSelectionStore`, #61) and the `application`
/// controllers can reference it without violating the
/// `presentation → application → domain`/`data` dependency direction.
enum HistoryRange {
  hour1(Duration(hours: 1), '1h'),
  hours24(Duration(hours: 24), '24h'),
  days7(Duration(days: 7), '7d');

  const HistoryRange(this.period, this.label);

  /// The trailing window this option represents.
  final Duration period;

  /// Short label shown on the selector segment.
  final String label;
}
