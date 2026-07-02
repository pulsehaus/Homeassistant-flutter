import 'package:homeassistant_flutter/features/charts/data/chart_selection_store.dart';
import 'package:homeassistant_flutter/features/charts/domain/history_range.dart';

/// In-memory [ChartSelectionStore] for tests. Records writes so a test can
/// assert what was persisted, and can be seeded with [initialEntityId] /
/// [initialRange] to simulate a returning user who already made a selection.
class FakeChartSelectionStore implements ChartSelectionStore {
  FakeChartSelectionStore({String? initialEntityId, HistoryRange? initialRange})
    : _entityId = initialEntityId,
      _range = initialRange;

  String? _entityId;
  HistoryRange? _range;

  /// The entity ids handed to [writeEntityId], in order.
  final List<String?> entityIdWrites = [];

  /// The ranges handed to [writeRange], in order.
  final List<HistoryRange> rangeWrites = [];

  @override
  Future<String?> readEntityId() async => _entityId;

  @override
  Future<void> writeEntityId(String? entityId) async {
    entityIdWrites.add(entityId);
    _entityId = entityId;
  }

  @override
  Future<HistoryRange?> readRange() async => _range;

  @override
  Future<void> writeRange(HistoryRange range) async {
    rangeWrites.add(range);
    _range = range;
  }
}
