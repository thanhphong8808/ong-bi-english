// lib/curriculum/lesson_stages.dart
//
// Splits a daily lesson into short stages ("chặng") of about four minutes.
// After each stage the child gets a small reward and may stop without
// losing anything. Pure Dart.
import '../core/config/app_config.dart';
import 'lesson_plan.dart';

/// Exclusive end index of every stage of [plan], in order; the last one is
/// always `plan.steps.length`. Tests and short lessons are one stage.
///
/// Stages have about the same number of steps. A boundary moves by up to
/// [AppConfig.lessonStageSnap] steps to fall where the activity type
/// changes (for example from new words to speaking), so a stage never cuts
/// a block in half when it can be avoided.
List<int> stageEnds(LessonPlan plan, {int stages = AppConfig.lessonStages}) {
  final steps = plan.steps;
  final n = steps.length;
  if (plan.isTest || stages < 2 || n < AppConfig.minStepsForStages) {
    return [n];
  }
  final count = n < stages * AppConfig.minStepsPerStage ? n ~/ AppConfig.minStepsPerStage : stages;
  if (count < 2) {
    return [n];
  }
  final ends = <int>[];
  var previous = 0;
  for (var k = 1; k < count; k++) {
    final target = (n * k / count).round();
    var best = target;
    var bestDistance = 1 << 30;
    for (var i = target - AppConfig.lessonStageSnap; i <= target + AppConfig.lessonStageSnap; i++) {
      if (i - previous < AppConfig.minStepsPerStage || n - i < AppConfig.minStepsPerStage * (count - k)) {
        continue;
      }
      final natural = steps[i].stage != steps[i - 1].stage;
      // Any natural boundary within reach beats an exact cut mid-block.
      final distance = (i - target).abs() * 2 + (natural ? 0 : 4 * AppConfig.lessonStageSnap + 1);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    if (best - previous < AppConfig.minStepsPerStage) {
      continue;
    }
    ends.add(best);
    previous = best;
  }
  ends.add(n);
  return ends;
}

/// Which stage (0-based) step [index] belongs to.
int stageOf(List<int> ends, int index) {
  for (var s = 0; s < ends.length; s++) {
    if (index < ends[s]) {
      return s;
    }
  }
  return ends.length - 1;
}
