// test/leitner_scheduler_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ong_bi_english/core/config/app_config.dart';
import 'package:ong_bi_english/core/db/repositories.dart';
import 'package:ong_bi_english/curriculum/leitner_scheduler.dart';

void main() {
  const scheduler = LeitnerScheduler();
  final monday = DateTime(2026, 3, 2, 19, 30);

  ItemProgressRow answer(ItemProgressRow? current, bool correct, DateTime now) => scheduler.answer(
        current: current,
        itemId: 'L1U01-W01',
        unitId: 'L1U01',
        skill: 'listen',
        correct: correct,
        now: now,
      );

  test('uses the seven boxes and intervals from AppConfig', () {
    expect(scheduler.maxBox, 7);
    expect(AppConfig.leitnerIntervalsDays, [0, 1, 2, 4, 7, 14, 30]);
    expect(scheduler.masteredBox, AppConfig.leitnerMasteredBox);
  });

  test('a new item answered correctly enters box 1, due again today', () {
    final row = answer(null, true, monday);
    expect(row.box, 1);
    expect(row.dueAt, DateTime(2026, 3, 2));
    expect(row.correctCount, 1);
    expect(row.wrongCount, 0);
    expect(scheduler.isDue(row, monday), isTrue);
  });

  test('each correct answer moves one box up with the matching interval', () {
    ItemProgressRow? row;
    final expectedDays = [0, 1, 2, 4, 7, 14, 30];
    for (var box = 1; box <= 7; box++) {
      row = answer(row, true, monday);
      expect(row.box, box);
      expect(row.dueAt, DateTime(2026, 3, 2 + expectedDays[box - 1]), reason: 'box $box');
    }
  });

  test('the top box is never exceeded', () {
    ItemProgressRow? row;
    for (var i = 0; i < 12; i++) {
      row = answer(row, true, monday);
    }
    expect(row!.box, 7);
    expect(row.correctCount, 12);
  });

  test('a wrong answer sends the item back to box 1, due today', () {
    ItemProgressRow? row;
    for (var i = 0; i < 5; i++) {
      row = answer(row, true, monday);
    }
    expect(row!.box, 5);
    final later = monday.add(const Duration(days: 9));
    final wrong = answer(row, false, later);
    expect(wrong.box, 1);
    expect(wrong.dueAt, DateTime(2026, 3, 11));
    expect(wrong.wrongCount, 1);
    expect(wrong.correctCount, 5);
    expect(wrong.lastSeenAt, later);
  });

  test('due dates fall at the start of a day, so evening lessons are not skipped', () {
    final row = answer(answer(null, true, monday), true, monday);
    expect(row.box, 2);
    // Due on Tuesday 00:00: a lesson on Tuesday morning already sees it.
    expect(scheduler.isDue(row, DateTime(2026, 3, 3, 7)), isTrue);
    expect(scheduler.isDue(row, DateTime(2026, 3, 2, 23, 59)), isFalse);
  });

  test('due dates cross month and year boundaries', () {
    final row = ItemProgressRow(
      itemId: 'x',
      unitId: 'u',
      skill: 'speak',
      box: 6,
      dueAt: DateTime(2026, 12, 20),
      correctCount: 6,
      wrongCount: 0,
      lastSeenAt: DateTime(2026, 12, 20),
    );
    final next = scheduler.answer(
      current: row,
      itemId: 'x',
      unitId: 'u',
      skill: 'speak',
      correct: true,
      now: DateTime(2026, 12, 20, 18),
    );
    expect(next.box, 7);
    expect(next.dueAt, DateTime(2027, 1, 19));
  });

  test('required skills follow the level and the microphone', () {
    expect(scheduler.requiredSkills(0, speechAvailable: true), ['listen', 'speak']);
    expect(scheduler.requiredSkills(1, speechAvailable: true), ['listen', 'speak']);
    expect(scheduler.requiredSkills(2, speechAvailable: true), ['listen', 'speak', 'write']);
    expect(scheduler.requiredSkills(5, speechAvailable: false), ['listen', 'write']);
  });

  test('an item is mastered only when every required skill reaches the mastered box', () {
    ItemProgressRow row(String skill, int box) => ItemProgressRow(
          itemId: 'i',
          unitId: 'u',
          skill: skill,
          box: box,
          dueAt: monday,
          correctCount: box,
          wrongCount: 0,
          lastSeenAt: monday,
        );
    final m = AppConfig.leitnerMasteredBox;
    expect(scheduler.isMastered({'listen': row('listen', m), 'speak': row('speak', m)}, 1, speechAvailable: true),
        isTrue);
    expect(
        scheduler.isMastered({'listen': row('listen', m), 'speak': row('speak', m - 1)}, 1, speechAvailable: true),
        isFalse);
    expect(scheduler.isMastered({'listen': row('listen', m)}, 1, speechAvailable: false), isTrue);
    expect(scheduler.isMastered({'listen': row('listen', m), 'speak': row('speak', m)}, 2, speechAvailable: true),
        isFalse,
        reason: 'level 2 also needs writing');
  });
}
