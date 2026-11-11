// lib/curriculum/progress_service.dart
//
// Records answers and lesson results in the database and moves the child
// through units and levels.
import 'dart:convert';

import '../core/config/app_config.dart';
import '../core/db/app_database.dart';
import '../core/db/repositories.dart';
import 'leitner_scheduler.dart';
import 'lesson_plan.dart';
import 'models.dart';
import 'progress_snapshot.dart';
import 'scorers/test_grader.dart';

/// Per-profile setting keys used by the learning flow.
class ProgressKeys {
  const ProgressKeys._();

  static const String levelReviewUntil = 'level_review_until';
  static const String lastUnitTestWrong = 'last_unit_test_wrong';
  static const String lastLevelTestWeak = 'last_level_test_weak';
}

class ProgressService {
  ProgressService({
    required this.db,
    required this.curriculum,
    this.scheduler = const LeitnerScheduler(),
  });

  final AppDatabase db;
  final Curriculum curriculum;
  final LeitnerScheduler scheduler;

  Future<ProgressSnapshot> snapshot(int profileId, {DateTime? now}) async {
    final time = now ?? DateTime.now();
    final rows = await db.progressRepo.all(profileId);
    final units = await db.progressRepo.units(profileId);
    final stages = await db.progressRepo.dialogueStages(profileId);
    final attempts = await db.progressRepo.attemptsSince(
      profileId,
      time.subtract(const Duration(days: 7)),
    );
    final until = await db.settingsRepo.read(ProgressKeys.levelReviewUntil, profileId: profileId);
    final wrongRaw = await db.settingsRepo.read(ProgressKeys.lastUnitTestWrong, profileId: profileId);
    final untilMs = int.tryParse(until ?? '');
    return ProgressSnapshot(
      rows: rows,
      units: units,
      dialogueStages: stages,
      recentAttempts: attempts,
      levelReviewUntil: untilMs == null ? null : DateTime.fromMillisecondsSinceEpoch(untilMs),
      lastUnitTestWrong: wrongRaw == null || wrongRaw.isEmpty ? const [] : wrongRaw.split(','),
    );
  }

  /// One answer: Leitner box update plus an attempt row for statistics.
  Future<void> recordAnswer({
    required int profileId,
    required String itemId,
    required String skill,
    required bool correct,
    required double score,
    DateTime? now,
  }) async {
    if (itemId.isEmpty || skill.isEmpty) {
      return;
    }
    final item = curriculum.item(itemId);
    if (item == null) {
      return;
    }
    final time = now ?? DateTime.now();
    final rows = await db.progressRepo.all(profileId);
    ItemProgressRow? current;
    for (final row in rows) {
      if (row.itemId == itemId && row.skill == skill) {
        current = row;
        break;
      }
    }
    final next = scheduler.answer(
      current: current,
      itemId: itemId,
      unitId: item.unitId,
      skill: skill,
      correct: correct,
      now: time,
    );
    await db.progressRepo.upsert(profileId, next);
    await db.progressRepo.addAttempt(
      profileId,
      itemId: itemId,
      skill: skill,
      correct: correct,
      score: score,
      at: time,
    );
  }

  /// Marks new items as introduced (box 1, due today) so the composer moves on
  /// even when the child skipped the follow-up game.
  Future<void> markIntroduced(int profileId, List<String> itemIds, {DateTime? now}) async {
    final time = now ?? DateTime.now();
    final existing = {
      for (final row in await db.progressRepo.all(profileId)) '${row.itemId}/${row.skill}',
    };
    for (final id in itemIds) {
      final item = curriculum.item(id);
      if (item == null || existing.contains('$id/listen')) {
        continue;
      }
      await db.progressRepo.upsert(
        profileId,
        ItemProgressRow(
          itemId: id,
          unitId: item.unitId,
          skill: 'listen',
          box: 1,
          dueAt: scheduler.dueFor(1, time),
          correctCount: 0,
          wrongCount: 0,
          lastSeenAt: time,
        ),
      );
    }
  }

  Future<void> setDialogueStage(int profileId, String dialogueId, int stage) async {
    final stages = await db.progressRepo.dialogueStages(profileId);
    if ((stages[dialogueId] ?? 0) < stage) {
      await db.progressRepo.setDialogueStage(profileId, dialogueId, stage);
    }
  }

  /// Called when a non-test lesson ends. [introducedIds] are the new items
  /// actually presented (a lesson cut short by the time limit skips some).
  Future<void> completeLesson(
    int profileId,
    LessonPlan plan, {
    List<String>? introducedIds,
    DateTime? now,
  }) async {
    final time = now ?? DateTime.now();
    await markIntroduced(profileId, introducedIds ?? plan.newItemIds, now: time);
    if (plan.unitId.startsWith('L') && plan.unitId.contains('U')) {
      final unit = await db.progressRepo.unit(profileId, plan.unitId);
      switch (plan.kind) {
        case LessonKind.newContent:
          await db.progressRepo.saveUnit(profileId, unit.copyWith(lessonsDone: unit.lessonsDone + 1));
        case LessonKind.unitReview:
          await db.progressRepo.saveUnit(profileId, unit.copyWith(reviewDone: true));
        case LessonKind.remedial:
          await db.progressRepo.saveUnit(profileId, unit.copyWith(remedialPending: false));
        case LessonKind.practice:
        case LessonKind.levelReview:
        case LessonKind.unitTest:
        case LessonKind.levelTest:
        case LessonKind.placement:
          break;
      }
    }
    await db.studyRepo.addLesson(profileId, time);
  }

  /// Saves a unit test. Passing opens the next unit; failing schedules a
  /// remedial lesson built from the wrong items and a retake the next day.
  Future<void> recordUnitTest(int profileId, Unit unit, GradeReport report, {DateTime? now}) async {
    final time = now ?? DateTime.now();
    await db.testRepo.add(
      profileId,
      kind: 'unit',
      targetId: unit.id,
      score: report.total,
      passed: report.passed,
      detailJson: jsonEncode(report.toJson()),
    );
    final current = await db.progressRepo.unit(profileId, unit.id);
    await db.progressRepo.saveUnit(
      profileId,
      current.copyWith(
        passed: current.passed || report.passed,
        bestScore: report.total > current.bestScore ? report.total : current.bestScore,
        lastTestAt: time,
        remedialPending: !report.passed,
      ),
    );
    await db.settingsRepo.write(
      ProgressKeys.lastUnitTestWrong,
      report.passed ? '' : report.wrongItemIds.join(','),
      profileId: profileId,
    );
    if (report.passed) {
      await _syncUnitIndex(profileId, unit.level);
    }
  }

  /// Saves a level test. Passing moves to the next level; failing records the
  /// weak sections for parents and starts a review period.
  Future<bool> recordLevelTest(int profileId, int level, GradeReport report, {DateTime? now}) async {
    final time = now ?? DateTime.now();
    await db.testRepo.add(
      profileId,
      kind: 'level',
      targetId: 'L$level',
      score: report.total,
      passed: report.passed,
      detailJson: jsonEncode(report.toJson()),
    );
    if (report.passed) {
      final nextLevel = (level + 1).clamp(0, AppConfig.levelCount - 1).toInt();
      await db.settingsRepo.write(ProgressKeys.levelReviewUntil, '', profileId: profileId);
      if (nextLevel != level) {
        await db.profileRepo.setPosition(profileId, level: nextLevel, unitIndex: 0);
      }
      return true;
    }
    final until = DateTime(time.year, time.month, time.day + AppConfig.levelReviewDays);
    await db.settingsRepo.write(
      ProgressKeys.levelReviewUntil,
      '${until.millisecondsSinceEpoch}',
      profileId: profileId,
    );
    await db.settingsRepo.write(
      ProgressKeys.lastLevelTestWeak,
      report.weakSections.map((s) => s.name).join(','),
      profileId: profileId,
    );
    return false;
  }

  Future<void> recordPlacement(int profileId, int level, double score) async {
    await db.testRepo.add(
      profileId,
      kind: 'placement',
      targetId: 'PLACEMENT',
      score: score,
      passed: true,
      detailJson: jsonEncode({'level': level}),
    );
    await db.profileRepo.setPosition(profileId, level: level, unitIndex: 0);
    await db.profileRepo.setPlacementDone(profileId, true);
  }

  Future<void> _syncUnitIndex(int profileId, int level) async {
    final units = curriculum.unitsOf(level);
    final progress = {for (final u in await db.progressRepo.units(profileId)) u.unitId: u};
    var index = units.length;
    for (var i = 0; i < units.length; i++) {
      if (!(progress[units[i].id]?.passed ?? false)) {
        index = i;
        break;
      }
    }
    await db.profileRepo.setPosition(profileId, level: level, unitIndex: index);
  }

  /// Items whose required skills all reached the mastered box.
  int masteredCount(ProgressSnapshot snapshot, {required bool speechAvailable}) {
    var count = 0;
    for (final entry in snapshot.byItem.entries) {
      final item = curriculum.item(entry.key);
      if (item == null) {
        continue;
      }
      if (scheduler.isMastered(entry.value, item.level, speechAvailable: speechAvailable)) {
        count++;
      }
    }
    return count;
  }
}
