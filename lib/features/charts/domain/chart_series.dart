import 'package:flutter/foundation.dart';

/// A single point in a time series: a value sampled at a moment in time.
///
/// This is the *generic* input the chart layer understands. It is deliberately
/// decoupled from Home Assistant: any source (a sensor's recorded history, an
/// energy meter, a static sample) can be expressed as a list of these points.
/// When the communication layer (#2) lands, its entity-history models map into
/// `TimeSeriesPoint`s with no change to the chart code.
@immutable
class TimeSeriesPoint {
  const TimeSeriesPoint({required this.time, required this.value});

  /// When the sample was taken.
  final DateTime time;

  /// The numeric value at [time].
  final double value;

  @override
  bool operator ==(Object other) =>
      other is TimeSeriesPoint && other.time == time && other.value == value;

  @override
  int get hashCode => Object.hash(time, value);

  @override
  String toString() => 'TimeSeriesPoint(time: $time, value: $value)';
}

/// The chart shapes the wrapper can render. Kept small on purpose — line and
/// bar cover sensor curves and bucketed/energy data, which are the first HA
/// use cases. New shapes (area, candlestick…) extend this enum later.
enum ChartType { line, bar }

/// A named series of [TimeSeriesPoint]s — e.g. one sensor's history.
///
/// Grouping the points with a [name] lets a single chart show several series
/// (temperature + humidity…) and gives ECharts a legend label.
@immutable
class ChartSeries {
  const ChartSeries({required this.name, required this.points, this.unit});

  /// Human-readable series name, shown in the legend and tooltip.
  final String name;

  /// The data points, expected in chronological order.
  final List<TimeSeriesPoint> points;

  /// Optional unit of measurement (e.g. `°C`, `kWh`) for axis/tooltip labels.
  final String? unit;

  @override
  bool operator ==(Object other) =>
      other is ChartSeries &&
      other.name == name &&
      other.unit == unit &&
      listEquals(other.points, points);

  @override
  int get hashCode => Object.hash(name, unit, Object.hashAll(points));
}
