// test/daily_hello_test.dart
//
// The morning hello is built in code every day; these tests build it for
// many days and levels and check it is always a valid talk that ends, that
// the child answers several times, and that what Bi notes is allowed. They
// also check the pocket phrases and their review schedule.
import 'package:flutter_test/flutter_test.dart';
import 'package:ong_bi_english/curriculum/bi_notes.dart';
import 'package:ong_bi_english/curriculum/bi_world.dart';
import 'package:ong_bi_english/curriculum/daily_hello.dart';
import 'package:ong_bi_english/curriculum/pocket_phrases.dart';
import 'package:ong_bi_english/curriculum/talk_scripts.dart';

final RegExp english = RegExp(r'''^[A-Za-z0-9 ,.!?:'"\-]+$''');

/// Kid turns on the shortest path, or throws on a loop / missing block.
int shortestTurns(TalkScript s) {
  var best = 1 << 30;
  void walk(String id, int turns, Set<String> seen) {
    if (id == TalkScript.end) {
      best = turns < best ? turns : best;
      return;
    }
    final block = s.blocks[id];
    if (block == null) {
      throw StateError('${s.id}: no block [$id]');
    }
    if (seen.contains(id)) {
      throw StateError('${s.id}: loop at [$id]');
    }
    var t = turns + block.items.whereType<TalkLine>().where((l) => l.role == TalkScript.kidRole).length;
    final choice = block.choice;
    if (choice == null) {
      walk(block.after, t, {...seen, id});
      return;
    }
    t++;
    for (final o in choice.options) {
      walk(optionTarget(block, o), t, {...seen, id});
    }
  }

  walk(s.startId, 0, {});
  return best;
}

void checkScript(TalkScript s) {
  for (final block in s.blocks.values) {
    for (final item in block.items) {
      if (item is TalkLine) {
        expect(english.hasMatch(item.en), isTrue, reason: '[${block.id}] "${item.en}"');
        expect(item.en.split(' ').length, lessThanOrEqualTo(18), reason: item.en);
        expect(item.vi, isNotEmpty);
      }
    }
    final choice = block.choice;
    if (choice != null) {
      expect(choice.options.length, inInclusiveRange(2, 4), reason: block.id);
      for (final o in choice.options) {
        expect(english.hasMatch(o.en), isTrue, reason: o.en);
        expect(o.en.split(' ').length, lessThanOrEqualTo(10), reason: o.en);
        expect(o.emoji.runes.any((r) => r > 0x2000), isTrue, reason: o.emoji);
      }
    }
  }
}

void main() {
  group('Chào Bi mỗi ngày', () {
    test('is a valid talk on every day, at every level, with or without a mission to check', () {
      final start = DateTime(2026, 11, 1, 7, 30);
      for (var d = 0; d < 45; d++) {
        for (var level = 0; level <= 3; level++) {
          for (final check in [false, true]) {
            final plan = DailyHello.build(
              childName: 'Mai',
              level: level,
              now: start.add(Duration(days: d, hours: d % 3 * 6)),
              pocket: PocketProgress.decode(null),
              missionToCheck: check ? DailyHello.missions[d % DailyHello.missions.length] : null,
            );
            final lib = const TalkParser().parse([plan.text]);
            expect(lib.scripts.length, 1);
            final s = lib.scripts.single;
            expect(s.id, plan.scriptId);
            expect(s.blocks.containsKey('mission_check'), check);
            expect(plan.checksMission, check);
            checkScript(s);
            expect(shortestTurns(s), greaterThanOrEqualTo(check ? 5 : 4), reason: 'day $d level $level');
            for (final note in plan.notes.values) {
              expect(BiNotes.validate(note.$1, note.$2), isNotNull, reason: '$note');
            }
          }
        }
      }
    });

    test('questions whose answers Bi knows wait for another day', () {
      final plan = DailyHello.build(
        childName: 'Mai',
        level: 1,
        now: DateTime(2026, 11, 13, 8),
        pocket: PocketProgress.decode(null),
        knownNotes: const {'animal', 'colour', 'fruit', 'toy'},
      );
      final text = plan.text;
      expect(text.contains("What's your favourite animal?"), isFalse);
      expect(text.contains("What's your favourite colour?"), isFalse);
    });

    test('a name cannot break the script', () {
      final plan = DailyHello.build(
        childName: 'Bé | -> end',
        level: 0,
        now: DateTime(2026, 11, 13, 8),
        pocket: PocketProgress.decode(null),
      );
      final s = const TalkParser().parse([plan.text]).scripts.single;
      expect(shortestTurns(s), greaterThanOrEqualTo(4));
    });

    test('Bi has news every day and answers questions without its brain', () {
      for (var d = 0; d < 40; d++) {
        final n = BiWorld.newsFor(DateTime(2026, 1, 1).add(Duration(days: d)));
        expect(english.hasMatch(n.en), isTrue, reason: n.en);
        expect(n.vi, isNotEmpty);
      }
      for (final q in BiWorld.questions) {
        expect(BiWorld.answer(q, DateTime(2026, 11, 13)).en, isNotEmpty, reason: q.en);
      }
    });
  });

  group('Câu bỏ túi', () {
    test('about 80 phrases, unique, in known groups, with a situation question', () {
      final all = PocketPhrases.all;
      expect(all.length, greaterThanOrEqualTo(75));
      expect(all.map((p) => p.id).toSet().length, all.length);
      final groups = PocketPhrases.groups.map((g) => g.id).toSet();
      for (final p in all) {
        expect(groups, contains(p.group), reason: p.id);
        expect(english.hasMatch(p.en), isTrue, reason: p.en);
        expect(english.hasMatch(p.situationEn), isTrue, reason: p.situationEn);
        expect(p.en.split(' ').length, lessThanOrEqualTo(8), reason: p.en);
        expect(p.situationEn.endsWith('?'), isTrue, reason: p.id);
        expect(p.vi, isNotEmpty);
        expect(p.situationVi, isNotEmpty);
      }
      expect(PocketPhrases.forLevel(0).where((p) => p.rescue).length, greaterThanOrEqualTo(5));
    });

    test('review boxes go up when said well, back to 1 when not, and survive storage', () {
      final pr = PocketProgress.decode(null);
      pr.answer('h_hello', good: true, today: 10);
      expect(pr.boxes['h_hello'], 1);
      expect(pr.dueDay['h_hello'], 11);
      pr.answer('h_hello', good: true, today: 11);
      pr.answer('h_hello', good: true, today: 13);
      expect(pr.boxes['h_hello'], 3);
      expect(pr.mastered, 1);
      pr.answer('h_hello', good: false, today: 20);
      expect(pr.boxes['h_hello'], 1);
      final again = PocketProgress.decode(pr.encode());
      expect(again.boxes, pr.boxes);
      expect(again.dueDay, pr.dueDay);
    });

    test('a round puts due reviews first, then new phrases', () {
      final pr = PocketProgress.decode(null)..answer('h_bye', good: true, today: 1);
      final round = pr.round(0, 5);
      expect(round.first.id, 'h_bye');
      expect(round.length, 5);
      expect(round.skip(1).every((p) => !pr.boxes.containsKey(p.id)), isTrue);
      expect(PocketPhrases.phraseOfDay(0, pr, 5).id, isNot('h_bye'));
    });

    test('three family phrases a week', () {
      final week = PocketPhrases.familyWeek(0, 7);
      expect(week.length, 3);
      expect(week.map((p) => p.id).toSet().length, 3);
    });
  });
}
