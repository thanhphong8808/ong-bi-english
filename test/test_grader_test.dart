// test/test_grader_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ong_bi_english/core/config/app_config.dart';
import 'package:ong_bi_english/curriculum/scorers/test_grader.dart';

QuestionOutcome q(String skill, double score, [String item = '']) =>
    QuestionOutcome(questionId: 'q$skill$score$item', itemId: item, skill: skill, score: score);

void main() {
  const grader = TestGrader();

  test('thresholds come from AppConfig', () {
    expect(AppConfig.unitTestPassRatio, 0.80);
    expect(AppConfig.levelTestPassRatio, 0.75);
    expect(AppConfig.levelTestSectionFloor, 0.60);
  });

  group('unit test', () {
    test('exactly 80 % passes', () {
      final r = grader.gradeUnit([q('listen', 1), q('listen', 1), q('speak', 1), q('read', 1), q('write', 0, 'a')]);
      expect(r.total, closeTo(0.8, 1e-9));
      expect(r.passed, isTrue);
    });

    test('75 % fails and lists the wrong items once', () {
      final r = grader.gradeUnit([q('listen', 1), q('speak', 1), q('read', 0, 'cat'), q('write', 1)]);
      expect(r.passed, isFalse);
      expect(r.wrongItemIds, ['cat']);
    });

    test('partial credit is averaged', () {
      final r = grader.gradeUnit([q('speak', 0.5), q('speak', 1)]);
      expect(r.total, closeTo(0.75, 1e-9));
    });

    test('wrong answers without an item are not listed, duplicates are merged', () {
      final r = grader.gradeUnit([q('listen', 0, 'dog'), q('read', 0, 'dog'), q('write', 0)]);
      expect(r.wrongItemIds, ['dog']);
    });

    test('an empty test never passes', () {
      expect(grader.gradeUnit(const []).passed, isFalse);
    });
  });

  group('level test', () {
    test('passes with a good total and every section above the floor', () {
      final r = grader.gradeLevel([
        q('listen', 1), q('listen', 0.5),
        q('read', 1), q('read', 1),
        q('speak', 0.75), q('speak', 0.75),
        q('write', 1), q('write', 0.5),
      ]);
      expect(r.total, closeTo(0.8125, 1e-9));
      expect(r.passed, isTrue);
      expect(r.weakSections, isEmpty);
    });

    test('a weak section fails the test even when the total is high', () {
      final r = grader.gradeLevel([q('listen', 1), q('read', 1), q('write', 1), q('speak', 0.5)]);
      expect(r.total, greaterThan(0.75));
      expect(r.passed, isFalse);
      expect(r.weakSections, [TestSection.speaking]);
    });

    test('a low total fails', () {
      final r = grader.gradeLevel([q('listen', 0.7), q('read', 0.7), q('speak', 0.7)]);
      expect(r.passed, isFalse);
    });

    test('sections without questions are skipped (no microphone)', () {
      final r = grader.gradeLevel([q('listen', 1), q('read', 0.8), q('write', 0.8)]);
      expect(r.sections.containsKey(TestSection.speaking), isFalse);
      expect(r.passed, isTrue);
    });

    test('skills map to Cambridge-style sections', () {
      expect(sectionForSkill('listen'), TestSection.listening);
      expect(sectionForSkill('read'), TestSection.readingWriting);
      expect(sectionForSkill('speak'), TestSection.speaking);
      expect(sectionForSkill('write'), TestSection.handwriting);
    });

    test('the report converts to JSON for the parent area', () {
      final json = grader.gradeLevel([q('listen', 1, 'x')]).toJson();
      expect(json['passed'], isTrue);
      expect((json['sections'] as Map)['listening'], 1.0);
    });
  });

  test('placement puts strong children in level 1', () {
    expect(grader.placeLevel(level0Score: 0.95, level1Score: 0.8), 1);
    expect(grader.placeLevel(level0Score: 0.95, level1Score: 0.2), 0);
    expect(grader.placeLevel(level0Score: 0.3, level1Score: 0.9), 0);
  });
}
