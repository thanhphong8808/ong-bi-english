// test/grammar_test.dart
//
// Checks the grammar pack (assets/grammar/grammar.json): every lesson can be
// taught and practised, every answer is among its options, finished
// sentences have no blanks left, the mixed test is well spread, and the
// verb table has the right forms. Also the test centre's summary.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ong_bi_english/core/db/repositories.dart';
import 'package:ong_bi_english/curriculum/grammar.dart';
import 'package:ong_bi_english/features/tests/test_center_screen.dart';

void main() {
  final book = GrammarBook.parse(File('assets/grammar/grammar.json').readAsStringSync());

  test('lessons, stages, tenses and verbs are all there', () {
    expect(book.lessons.length, greaterThanOrEqualTo(24));
    expect(book.stages.length, 5);
    for (final stage in book.stages) {
      expect(book.ofStage(stage.stage), isNotEmpty, reason: 'stage ${stage.stage}');
    }
    expect(book.tenses.length, greaterThanOrEqualTo(6));
    for (final t in book.tenses) {
      expect(book.lesson(t.lessonId), isNotNull, reason: t.id);
    }
    expect(book.verbs.length, greaterThanOrEqualTo(80));
    final ids = book.lessons.map((l) => l.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('every lesson explains, shows examples and has enough practice', () {
    final english = RegExp(r'''^[A-Za-z0-9 ,.!?'"\-]+$''');
    for (final l in book.lessons) {
      expect(l.explainVi, isNotEmpty, reason: l.id);
      expect(l.examples, isNotEmpty, reason: l.id);
      for (final e in l.examples) {
        expect(english.hasMatch(e.en), isTrue, reason: '${l.id}: ${e.en}');
        expect(e.vi, isNotEmpty);
      }
      for (final row in l.tableRows) {
        expect(row.length, l.tableHead.length, reason: '${l.id}: $row');
      }
      final choose = l.practice.where((t) => t.kind == GrammarTaskKind.choose).toList();
      final order = l.practice.where((t) => t.kind == GrammarTaskKind.order).toList();
      expect(choose.length, greaterThanOrEqualTo(5), reason: l.id);
      expect(order.length, greaterThanOrEqualTo(2), reason: l.id);
      for (final t in choose) {
        expect(t.options, contains(t.answer), reason: '${l.id}: ${t.question}');
        expect(t.options.toSet().length, t.options.length, reason: '${l.id}: ${t.question}');
        expect(t.questionText.contains('___'), isTrue, reason: '${l.id}: ${t.question}');
        expect(t.sentence.contains('___'), isFalse, reason: '${l.id}: ${t.sentence}');
        expect(english.hasMatch(t.sentence), isTrue, reason: '${l.id}: ${t.sentence}');
        expect(t.vi, isNotEmpty);
        expect(t.whyVi, isNotEmpty, reason: '${l.id}: ${t.question}');
      }
      for (final t in order) {
        expect(t.words.length, inInclusiveRange(3, 9), reason: '${l.id}: ${t.words}');
        expect(t.orderIsRight(t.words), isTrue);
        expect(t.orderIsRight(t.words.reversed.toList()), isFalse, reason: '${l.id}: ${t.words}');
        expect(t.sentence, endsWith(t.vi.trim().endsWith('?') ? '?' : '.'));
      }
    }
  });

  test('hints and two blanks make the right sentence', () {
    const hinted = GrammarTask.choose(
      question: '___ is my bag. (gần, một cái)',
      answer: 'This',
      options: ['This', 'These', 'Those'],
      vi: 'Đây là cặp của tớ.',
      whyVi: 'Gần và một cái: this.',
    );
    expect(hinted.questionText, '___ is my bag.');
    expect(hinted.hint, 'gần, một cái');
    expect(hinted.sentence, 'This is my bag.');
    const two = GrammarTask.choose(
      question: 'I ___ apples but my brother ___ bananas.',
      answer: 'like, likes',
      options: ['like, likes', 'likes, like', 'like, like'],
      vi: '',
      whyVi: '',
    );
    expect(two.sentence, 'I like apples but my brother likes bananas.');
  });

  test('the mixed test spreads over lessons and is mostly pick-the-word', () {
    final tasks = book.mixedTest(count: 12, random: Random(7));
    expect(tasks.length, 12);
    expect(tasks.map((t) => t.lessonId).toSet().length, greaterThanOrEqualTo(8));
    expect(tasks.where((t) => t.kind == GrammarTaskKind.order).length, lessThanOrEqualTo(3));
    final early = book.mixedTest(fromLessons: const ['G01', 'G02'], count: 10, random: Random(1));
    expect(early, isNotEmpty);
    expect(early.every((t) => t.lessonId == 'G01' || t.lessonId == 'G02'), isTrue);
    expect(book.mixedTest(fromLessons: const ['nope']), isEmpty);
  });

  test('the verb table has the right forms', () {
    GrammarVerb v(String base) => book.verbs.firstWhere((x) => x.base == base);
    expect([v('go').third, v('go').past, v('go').pastParticiple], ['goes', 'went', 'gone']);
    expect([v('swim').ing, v('swim').past], ['swimming', 'swam']);
    expect([v('watch').third, v('watch').past], ['watches', 'watched']);
    expect([v('study').third, v('study').past], ['studies', 'studied']);
    expect([v('dance').ing, v('dance').past], ['dancing', 'danced']);
    expect([v('stop').ing, v('stop').past], ['stopping', 'stopped']);
    expect(v('play').irregular, isFalse);
    expect(v('eat').irregular, isTrue);
  });

  test('scores and stars', () {
    expect(grammarScore(6, 8), 0.75);
    expect(grammarScore(0, 0), 0);
    expect(grammarStars(1.0), 3);
    expect(grammarStars(0.7), 2);
    expect(grammarStars(0.3), 1);
  });

  test('the test centre sums up results, newest last, skills averaged', () {
    TestResult r(int day, String kind, double score, Map<String, double> sections) => TestResult(
          id: day,
          kind: kind,
          targetId: 'X',
          score: score,
          passed: score >= 0.6,
          detailJson: jsonEncode({'sections': sections}),
          takenAt: DateTime(2026, 11, day),
        );
    final stats = TestStats.of([
      r(1, 'placement', 0.5, const {}),
      r(2, 'checkup', 0.5, const {'listening': 0.5}),
      r(3, 'grammar', 1.0, const {'grammar': 1.0}),
      r(4, 'unit', 0.9, const {'listening': 1.0, 'speaking': 0.8}),
    ]);
    expect(stats.count, 3);
    expect(stats.passed, 2);
    expect(stats.recent, [0.5, 1.0, 0.9]);
    expect(stats.average, closeTo(0.8, 1e-9));
    expect(stats.skills['listening'], closeTo(0.75, 1e-9));
    expect(stats.skills['grammar'], 1.0);
    expect(TestStats.of(const []).count, 0);
  });
}
