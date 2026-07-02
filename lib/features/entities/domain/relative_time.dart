/// Pure, transport-free formatting of a timestamp as a short relative-time
/// label (e.g. "2 minutes ago").
///
/// Used to surface an entity's `last_changed`/`last_updated` on its tile (#78)
/// — e.g. "is this sensor actually reporting?" — without burying date math in
/// the widget. Mirrors [EntityToggle]/[ClimateControl]'s shape: no Flutter or
/// Riverpod dependency, so it is trivially unit-testable in isolation.
class RelativeTime {
  const RelativeTime._();

  /// Formats the age of [timestamp] relative to [now] (defaults to
  /// [DateTime.now]) as a short relative label.
  ///
  /// Buckets:
  /// * under a minute -> `just now`
  /// * under an hour -> `N minute(s) ago`
  /// * under a day -> `N hour(s) ago`
  /// * a day or more -> `N day(s) ago`
  ///
  /// A [timestamp] at or after [now] (clock skew, or a payload timestamped
  /// fractionally ahead of local time) is also reported as `just now` rather
  /// than a negative duration.
  static String format(DateTime timestamp, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final age = reference.difference(timestamp);
    if (age.isNegative || age.inSeconds < 60) {
      return 'just now';
    }
    if (age.inMinutes < 60) {
      return _pluralize(age.inMinutes, 'minute');
    }
    if (age.inHours < 24) {
      return _pluralize(age.inHours, 'hour');
    }
    return _pluralize(age.inDays, 'day');
  }

  static String _pluralize(int value, String unit) =>
      '$value $unit${value == 1 ? '' : 's'} ago';
}
