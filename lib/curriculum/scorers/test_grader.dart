// lib/curriculum/scorers/test_grader.dart
//
// Deterministic grading of unit tests, level tests and the placement test.
// No LLM is involved, so the same answers always give the same result.
import '../../core/config/app_config.dart';

/// Level-test sections, named like Cambridge Young Learners papers.
enum TestSection { listening, readingWriting, speaking, handwriting }

TestSection sectionForSkill(String skill) {
  switch (skill) {
    case 'listen':
      return TestSection.listening;
    case 'read':
      return TestSection.readingWriting;
    case 'speak':
      return TestSection.speaking;
    default:
      return TestSection.handwriting;
  }
}

class QuestionOutcome {
  const QuestionOutcome({
    required this.questionId,
    required this.itemId,
    required this.skill,
    required this.score,
  });

  final String questionId;

  /// Item tested, used to build the remedial lesson. May be empty.
  final String itemId;
  final String skill;

  /// 0..1 (1 = fully correct).
  final double score;

  bool get correct => score >= 0.5;

  Map<String, Object?> toJson() =>
      {'q': questionId, 'item': itemId, 'skill': skill, 'score': score};
}

class GradeReport {
  const GradeReport({
    required this.total,
    required this.sections,
    required this.passed,
    required this.wrongItemIds,
  });

  /// 0..1
  final double total;
  final Map<TestSection, double> sections;
  final bool passed;
  final List<String> wrongItemIds;

  List<TestSection> get weakSections => [
        for (final entry in sections.entries)
          if (entry.value < AppConfig.levelTestSectionFloor) entry.key,
      ];

  Map<String, Object?> toJson() => {
        'total': total,
        'sections': {for (final e in sections.entries) e.key.name: e.value},
        'passed': passed,
        'wrong': wrongItemIds,
      };
}

class TestGrader {
  const TestGrader();

  static double _mean(Iterable<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    var sum = 0.0;
    for (final v in values) {
      sum += v;
    }
    return sum / values.length;
  }

  static List<String> _wrong(List<QuestionOutcome> outcomes) => <String>{
        for (final o in outcomes)
          if (!o.correct && o.itemId.isNotEmpty) o.itemId,
      }.toList();

  /// Unit test: the mean score must reach 80 %.
  GradeReport gradeUnit(List<QuestionOutcome> outcomes) {
    final total = _mean(outcomes.map((o) => o.score));
    final sections = <TestSection, double>{};
    for (final section in TestSection.values) {
      final scores = outcomes.where((o) => sectionForSkill(o.skill) == section).map((o) => o.score);
      if (scores.isNotEmpty) {
        sections[section] = _mean(scores);
      }
    }
    return GradeReport(
      total: total,
      sections: sections,
      passed: outcomes.isNotEmpty && total >= AppConfig.unitTestPassRatio - 1e-9,
      wrongItemIds: _wrong(outcomes),
    );
  }

  /// Level test: the mean of the section scores must reach 75 % and no
  /// section may be below 60 %. Sections without questions are skipped.
  GradeReport gradeLevel(List<QuestionOutcome> outcomes) {
    final sections = <TestSection, double>{};
    for (final section in TestSection.values) {
      final scores = outcomes.where((o) => sectionForSkill(o.skill) == section).map((o) => o.score);
      if (scores.isNotEmpty) {
        sections[section] = _mean(scores);
      }
    }
    final total = _mean(sections.values);
    final floorOk = sections.values.every((s) => s >= AppConfig.levelTestSectionFloor - 1e-9);
    return GradeReport(
      total: total,
      sections: sections,
      passed: sections.isNotEmpty && total >= AppConfig.levelTestPassRatio - 1e-9 && floorOk,
      wrongItemIds: _wrong(outcomes),
    );
  }

  /// Placement: Level 1 when the child already knows most Level 0 words and
  /// a good part of the early Level 1 words.
  int placeLevel({required double level0Score, required double level1Score}) {
    return level0Score >= AppConfig.placementLevel0Pass &&
            level1Score >= AppConfig.placementLevel1Pass
        ? 1
        : 0;
  }
}
