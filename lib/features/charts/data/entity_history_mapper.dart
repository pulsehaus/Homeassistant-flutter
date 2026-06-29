import '../domain/chart_series.dart';

/// Pure, widget-free translation of a Home Assistant history payload into the
/// generic [ChartSeries] the chart layer consumes.
///
/// The connection layer's REST client returns the raw JSON from
/// `GET /api/history/period/...`: a list whose single element is the list of
/// recorded state objects for the requested entity (an empty outer list when
/// there is no history). Each state object looks like:
///
/// ```json
/// {
///   "state": "21.4",
///   "last_changed": "2026-06-29T10:00:00+00:00",
///   "attributes": {"unit_of_measurement": "°C", "friendly_name": "Living room"}
/// }
/// ```
///
/// With `minimal_response` requested, only the first entry carries the full
/// `attributes` map; later entries omit it and may abbreviate the timestamp key
/// to `lu`/`lc`. This mapper tolerates all of those shapes.
///
/// Non-numeric states (`unavailable`, `on`, `unknown`…) are skipped rather than
/// mapped to `0`, so a sensor that briefly drops out doesn't draw a spurious
/// dip. The class is `abstract final` (static-only) and has no Flutter/transport
/// dependency, so it is trivially unit-testable.
abstract final class EntityHistoryMapper {
  /// Map the decoded `history/period` [payload] for [entityId] into a
  /// [ChartSeries].
  ///
  /// [fallbackName] is used for the series/legend label when HA does not provide
  /// a `friendly_name`; it defaults to [entityId].
  static ChartSeries toSeries(
    List<dynamic> payload,
    String entityId, {
    String? fallbackName,
  }) {
    final entries = _entriesFor(payload);

    String? unit;
    String? friendlyName;
    final points = <TimeSeriesPoint>[];

    for (final entry in entries) {
      if (entry is! Map) continue;
      final map = entry.cast<String, Object?>();

      // Attributes only appear on the first (full) entry under minimal_response.
      final attributes = map['attributes'];
      if (attributes is Map) {
        unit ??= attributes['unit_of_measurement'] as String?;
        friendlyName ??= attributes['friendly_name'] as String?;
      }

      final value = _parseValue(map['state']);
      final time = _parseTime(map);
      if (value == null || time == null) continue;
      points.add(TimeSeriesPoint(time: time, value: value));
    }

    // Defend against out-of-order entries so the chart draws chronologically.
    points.sort((a, b) => a.time.compareTo(b.time));

    return ChartSeries(
      name: friendlyName ?? fallbackName ?? entityId,
      points: points,
      unit: unit,
    );
  }

  /// The HA payload is `[[ ...states ]]`; unwrap the single inner list, treating
  /// an empty or malformed payload as "no history".
  static List<dynamic> _entriesFor(List<dynamic> payload) {
    if (payload.isEmpty) return const [];
    final first = payload.first;
    return first is List ? first : const [];
  }

  static double? _parseValue(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  /// Read the sample time, accepting the full (`last_changed`/`last_updated`)
  /// and abbreviated (`lc`/`lu`) keys HA uses across response modes.
  static DateTime? _parseTime(Map<String, Object?> map) {
    final raw =
        map['last_changed'] ?? map['last_updated'] ?? map['lc'] ?? map['lu'];
    if (raw is String) return DateTime.tryParse(raw);
    // `lc`/`lu` are epoch seconds (possibly fractional) in some HA versions.
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        (raw * 1000).round(),
        isUtc: true,
      );
    }
    return null;
  }
}
