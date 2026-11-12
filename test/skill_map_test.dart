// test/skill_map_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ong_bi_english/core/db/repositories.dart';
import 'package:ong_bi_english/curriculum/skill_map.dart';

ItemProgressRow _row(String id, String skill, int box) => ItemProgressRow(
      itemId: id,
      unitId: 'U',
      skill: skill,
      box: box,
      dueAt: DateTime(2026),
      correctCount: 0,
      wrongCount: 0,
      lastSeenAt: DateTime(2026),
    );

void main() {
  final now = DateTime(2026, 11, 12, 10);

  test('strength buckets per skill', () {
    final map = SkillMap.build(
      rows: [
        _row('a', 'listen', 5),
        _row('b', 'listen', 4),
        _row('c', 'listen', 2),
        _row('d', 'listen', 1),
        _row('a', 'speak', 3),
        _row('x', 'other', 6),
      ],
      turns: const [],
      now: now,
    );
    expect(map.strength['listen']!.strong, 2);
    expect(map.strength['listen']!.growing, 1);
    expect(map.strength['listen']!.fresh, 1);
    expect(map.strength['speak']!.growing, 1);
    expect(map.strength['write']!.total, 0);
    expect(map.hasSpeech, isFalse);
    expect(map.hasTalk, isFalse);
    expect(map.latencyMedianMs, isNull);
  });

  test('pronunciation by week, oldest first, and words to practise', () {
    final turns = [
      SpeechTurn(source: SpeechTurn.lesson, at: now.subtract(const Duration(days: 20)), itemId: 'cat', score: 0.4),
      SpeechTurn(source: SpeechTurn.lesson, at: now.subtract(const Duration(days: 2)), itemId: 'cat', score: 0.6),
      SpeechTurn(source: SpeechTurn.lesson, at: now.subtract(const Duration(days: 1)), itemId: 'dog', score: 1.0),
      SpeechTurn(source: SpeechTurn.lesson, at: now.subtract(const Duration(days: 1)), itemId: 'dog', score: 0.95),
      // Open answers carry no score and are ignored.
      SpeechTurn(source: SpeechTurn.lesson, at: now.subtract(const Duration(days: 1)), itemId: 'name'),
      // Older than four weeks.
      SpeechTurn(source: SpeechTurn.lesson, at: now.subtract(const Duration(days: 40)), itemId: 'cat', score: 0),
    ];
    final map = SkillMap.build(rows: const [], turns: turns, now: now);
    expect(map.pronunciationWeekly[0], isNull);
    expect(map.pronunciationWeekly[1], closeTo(0.4, 1e-9));
    expect(map.pronunciationWeekly[2], isNull);
    expect(map.pronunciationWeekly[3], closeTo((0.6 + 1.0 + 0.95) / 3, 1e-9));
    expect(map.practise.map((w) => w.itemId), ['cat']);
    expect(map.practise.single.average, closeTo(0.5, 1e-9));
    expect(map.practise.single.tries, 2);
  });

  test('talk: median reaction, words per answer, answers this week, latency', () {
    final turns = [
      SpeechTurn(source: SpeechTurn.talk, at: now.subtract(const Duration(days: 9)), responseMs: 8000, words: 1),
      SpeechTurn(source: SpeechTurn.talk, at: now.subtract(const Duration(days: 3)), responseMs: 3000, words: 2, latencyMs: 1100),
      SpeechTurn(source: SpeechTurn.talk, at: now.subtract(const Duration(days: 2)), responseMs: 5000, words: 4, latencyMs: 1300),
      SpeechTurn(source: SpeechTurn.talk, at: now.subtract(const Duration(days: 1)), words: 3, latencyMs: 900),
      SpeechTurn(source: SpeechTurn.lesson, at: now.subtract(const Duration(hours: 1)), itemId: 'cat', score: 1, latencyMs: 1000),
    ];
    final map = SkillMap.build(rows: const [], turns: turns, now: now);
    expect(map.reactionWeekly, [null, null, 8000, 4000]);
    expect(map.wordsPerTurnWeekly[2], 1);
    expect(map.wordsPerTurnWeekly[3], closeTo(3, 1e-9));
    expect(map.talkTurnsWeek, 3);
    expect(map.latencyMedianMs, 1050);
    expect(map.hasTalk, isTrue);
  });

  test('English word count', () {
    expect(englishWordCount("I like apple!"), 3);
    expect(englishWordCount("It's a cat."), 3);
    expect(englishWordCount(''), 0);
    expect(englishWordCount('con mèo'), 1);
    expect(englishWordCount('  Hello ,  Bi  '), 2);
  });
}
