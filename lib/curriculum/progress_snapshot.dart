// lib/curriculum/progress_snapshot.dart
import '../core/db/repositories.dart';

/// Read-only view of a child's progress, used by the composer. Pure Dart.
class ProgressSnapshot {
  ProgressSnapshot({
    required List<ItemProgressRow> rows,
    required List<UnitProgress> units,
    required this.dialogueStages,
    required this.recentAttempts,
    this.levelReviewUntil,
    this.lastUnitTestWrong = const [],
  }) {
    for (final row in rows) {
      byItem.putIfAbsent(row.itemId, () => <String, ItemProgressRow>{})[row.skill] = row;
    }
    for (final unit in units) {
      this.units[unit.unitId] = unit;
    }
  }

  factory ProgressSnapshot.empty() => ProgressSnapshot(
        rows: const [],
        units: const [],
        dialogueStages: const {},
        recentAttempts: const [],
      );

  /// itemId -> skill -> row
  final Map<String, Map<String, ItemProgressRow>> byItem = {};
  final Map<String, UnitProgress> units = {};
  final Map<String, int> dialogueStages;

  /// Attempts of the last 7 days (weekly review, parent charts).
  final List<AttemptRow> recentAttempts;

  /// After a failed level test: review-only lessons until this date.
  final DateTime? levelReviewUntil;

  /// Items answered wrongly in the latest failed unit test (remedial lesson).
  final List<String> lastUnitTestWrong;

  bool introduced(String itemId) => byItem.containsKey(itemId);

  UnitProgress unit(String unitId) => units[unitId] ?? UnitProgress(unitId: unitId);

  int dialogueStage(String dialogueId) => dialogueStages[dialogueId] ?? 0;

  Iterable<ItemProgressRow> get allRows => byItem.values.expand((m) => m.values);
}
