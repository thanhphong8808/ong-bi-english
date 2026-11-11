// lib/curriculum/leitner_scheduler.dart
//
// Leitner system with 7 boxes. Intervals come from AppConfig
// (0, 1, 2, 4, 7, 14, 30 days). Pure Dart, unit-tested.
import '../core/config/app_config.dart';
import '../core/db/repositories.dart';

class LeitnerScheduler {
  const LeitnerScheduler({
    this.intervalsDays = AppConfig.leitnerIntervalsDays,
    this.masteredBox = AppConfig.leitnerMasteredBox,
  });

  final List<int> intervalsDays;
  final int masteredBox;

  int get maxBox => intervalsDays.length;

  static DateTime startOfDay(DateTime time) => DateTime(time.year, time.month, time.day);

  /// Due date for an item that has just moved into [box] (1-based).
  DateTime dueFor(int box, DateTime now) {
    final index = (box - 1).clamp(0, intervalsDays.length - 1).toInt();
    final base = startOfDay(now);
    return DateTime(base.year, base.month, base.day + intervalsDays[index]);
  }

  /// Applies one answer. A correct answer moves the item up one box; a wrong
  /// answer sends it back to box 1, due again today.
  ItemProgressRow answer({
    required ItemProgressRow? current,
    required String itemId,
    required String unitId,
    required String skill,
    required bool correct,
    required DateTime now,
  }) {
    final box = current?.box ?? 0;
    final nextBox = correct ? (box + 1).clamp(1, maxBox).toInt() : 1;
    return ItemProgressRow(
      itemId: itemId,
      unitId: unitId,
      skill: skill,
      box: nextBox,
      dueAt: dueFor(nextBox, now),
      correctCount: (current?.correctCount ?? 0) + (correct ? 1 : 0),
      wrongCount: (current?.wrongCount ?? 0) + (correct ? 0 : 1),
      lastSeenAt: now,
    );
  }

  /// Due today or earlier.
  bool isDue(ItemProgressRow row, DateTime now) => !row.dueAt.isAfter(now);

  /// Skills an item must pass before it counts as learned.
  /// Levels 0-1: listen and speak. Level 2 up: listen, speak and write.
  List<String> requiredSkills(int level, {required bool speechAvailable}) {
    final skills = <String>['listen'];
    if (speechAvailable) {
      skills.add('speak');
    }
    if (level >= AppConfig.firstLevelRequiringWriting) {
      skills.add('write');
    }
    return skills;
  }

  /// True when every required skill has reached [masteredBox].
  bool isMastered(
    Map<String, ItemProgressRow> bySkill,
    int level, {
    required bool speechAvailable,
  }) {
    for (final skill in requiredSkills(level, speechAvailable: speechAvailable)) {
      final row = bySkill[skill];
      if (row == null || row.box < masteredBox) {
        return false;
      }
    }
    return true;
  }
}
