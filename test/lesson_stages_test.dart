// test/lesson_stages_test.dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ong_bi_english/core/config/app_config.dart';
import 'package:ong_bi_english/curriculum/lesson_composer.dart';
import 'package:ong_bi_english/curriculum/lesson_plan.dart';
import 'package:ong_bi_english/curriculum/lesson_stages.dart';
import 'package:ong_bi_english/curriculum/progress_snapshot.dart';

import 'support/curriculum_fixture.dart';

LessonStep step(LessonStage stage) => SayStep(stage: stage, text: 'cat');

LessonPlan plan(List<LessonStage> stages, {LessonKind kind = LessonKind.newContent}) =>
    LessonPlan(kind: kind, unitId: 'L1U01', level: 1, steps: [for (final s in stages) step(s)]);

void main() {
  test('a test or a short lesson is one stage', () {
    expect(stageEnds(plan(List.filled(20, LessonStage.test), kind: LessonKind.unitTest)), [20]);
    expect(stageEnds(plan(List.filled(5, LessonStage.speak))), [5]);
  });

  test('stages are about equal and end where the activity changes', () {
    final p = plan([
      ...List.filled(4, LessonStage.review),
      ...List.filled(5, LessonStage.learnNew),
      ...List.filled(4, LessonStage.speak),
      ...List.filled(5, LessonStage.write),
    ]);
    final ends = stageEnds(p);
    expect(ends.length, 3);
    expect(ends.last, 18);
    // Targets are 6 and 12; the nearest activity changes are 4 / 9 and 13.
    for (final end in ends.take(2)) {
      expect(p.steps[end].stage != p.steps[end - 1].stage, isTrue, reason: 'end $end cuts a block');
    }
  });

  test('every stage has at least the minimum number of steps', () {
    for (var n = AppConfig.minStepsForStages; n < 40; n++) {
      final ends = stageEnds(plan(List.filled(n, LessonStage.speak)));
      var previous = 0;
      for (final end in ends) {
        expect(end - previous >= AppConfig.minStepsPerStage, isTrue, reason: 'n=$n ends=$ends');
        previous = end;
      }
      expect(ends.last, n);
      expect(ends.length <= AppConfig.lessonStages, isTrue);
    }
  });

  test('stageOf maps step indexes to stages', () {
    expect(stageOf([4, 9, 14], 0), 0);
    expect(stageOf([4, 9, 14], 4), 1);
    expect(stageOf([4, 9, 14], 13), 2);
  });

  test('real daily lessons of every level split into stages', () {
    final curriculum = loadCurriculum();
    final composer = LessonComposer(curriculum: curriculum);
    for (var level = 0; level <= 5; level++) {
      final lesson = composer.compose(
        level: level,
        snapshot: ProgressSnapshot.empty(),
        options: ComposerOptions(now: DateTime(2026, 11, 12, 10)),
        random: Random(level),
      );
      final ends = stageEnds(lesson);
      expect(ends.length, greaterThanOrEqualTo(2), reason: 'level $level: ${lesson.steps.length} steps');
      expect(ends.last, lesson.steps.length);
    }
  });
}
