// test/talk_scripts_test.dart
//
// Checks every guided conversation, role-play and story that ships in
// assets/talk: the format, that every branch leads somewhere and ends, that
// the child always gets turns, and that the English stays simple.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ong_bi_english/curriculum/talk_scripts.dart';

TalkLibrary _load() => const TalkParser().parse([
      for (final f in Directory('assets/talk').listSync().whereType<File>().where((f) => f.path.endsWith('.txt')))
        f.readAsStringSync(),
    ]);

/// Every path through a script as the list of turns of [kidRole].
List<int> _turnsPerPath(TalkScript s, String kidRole) {
  final out = <int>[];
  void walk(String id, int turns, Set<String> seen) {
    if (id == TalkScript.end) {
      out.add(turns);
      return;
    }
    final block = s.blocks[id]!;
    if (seen.contains(id)) {
      throw StateError('${s.id}: loop at [$id]');
    }
    final here = {...seen, id};
    var t = turns + block.items.whereType<TalkLine>().where((l) => l.role == kidRole).length;
    final choice = block.choice;
    if (choice == null) {
      walk(block.after, t, here);
      return;
    }
    if (choice.role == kidRole) {
      t++;
    }
    for (final option in choice.options) {
      walk(optionTarget(block, option), t, here);
    }
  }

  walk(s.startId, 0, {});
  return out;
}

void main() {
  final library = _load();

  test('topics, chats, role-plays and stories are all there', () {
    expect(library.topics.length, greaterThanOrEqualTo(12));
    for (final topic in library.topics) {
      expect(library.of(TalkKind.chat, topic: topic.id).length, greaterThanOrEqualTo(2), reason: topic.id);
      expect(topic.words, isNotEmpty, reason: topic.id);
    }
    expect(library.of(TalkKind.role).length, greaterThanOrEqualTo(15));
    expect(library.of(TalkKind.story).length, greaterThanOrEqualTo(20));
    final ids = library.scripts.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'unique ids');
  });

  test('every script is well formed and every branch ends', () {
    final english = RegExp(r'''^[A-Za-z0-9 ,.!?'"\-]+$''');
    for (final s in library.scripts) {
      final where = s.id;
      expect(s.titleEn, isNotEmpty, reason: where);
      expect(s.titleVi, isNotEmpty, reason: where);
      expect(s.emoji, isNotEmpty, reason: where);
      expect(s.level, inInclusiveRange(0, 5), reason: where);
      if (s.kind != TalkKind.story) {
        expect(library.topic(s.topic), isNotNull, reason: '$where: topic "${s.topic}"');
      } else {
        expect(s.moralEn, isNotEmpty, reason: where);
        expect(s.moralVi, isNotEmpty, reason: where);
      }
      final roleIds = s.roles.map((r) => r.id).toSet();
      if (s.kind != TalkKind.role) {
        expect(roleIds, containsAll([TalkScript.biRole, TalkScript.kidRole]), reason: where);
      } else {
        expect(s.playableRoles.length, 2, reason: where);
      }
      final reached = <String>{};
      void visit(String id) {
        if (id == TalkScript.end || !reached.add(id)) {
          return;
        }
        final block = s.blocks[id];
        expect(block, isNotNull, reason: '$where: no block [$id]');
        if (block == null) {
          return;
        }
        for (final item in block.items) {
          if (item is TalkLine) {
            expect(roleIds, contains(item.role), reason: '$where [$id]: role ${item.role}');
            expect(english.hasMatch(item.en), isTrue, reason: '$where [$id]: "${item.en}"');
            expect(item.en.split(' ').length, lessThanOrEqualTo(18), reason: '$where [$id]: "${item.en}"');
            expect(item.vi, isNotEmpty, reason: '$where [$id]');
          }
        }
        final choice = block.choice;
        if (choice != null) {
          expect(roleIds, contains(choice.role), reason: '$where [$id]: chooser ${choice.role}');
          expect(choice.options.length, inInclusiveRange(2, 4), reason: '$where [$id]');
          expect(choice.options.map((o) => o.en).toSet().length, choice.options.length, reason: '$where [$id]');
          for (final o in choice.options) {
            expect(english.hasMatch(o.en), isTrue, reason: '$where [$id]: "${o.en}"');
            expect(o.en.split(' ').length, lessThanOrEqualTo(10), reason: '$where [$id]: "${o.en}"');
            expect(o.vi, isNotEmpty, reason: '$where [$id]');
            // A picture, not a word (keycaps such as 5️⃣ start with a digit).
            expect(o.emoji.runes.any((r) => r > 0x2000), isTrue, reason: '$where [$id]: emoji "${o.emoji}"');
            visit(optionTarget(block, o));
          }
        } else {
          visit(block.after);
        }
      }

      visit(s.startId);
      expect(reached, containsAll(s.blocks.keys), reason: '$where: unreachable ${s.blocks.keys.toSet().difference(reached)}');
    }
  });

  test('the child always gets turns, whichever way the talk goes', () {
    for (final s in library.scripts) {
      for (final role in s.playableRoles) {
        final turns = _turnsPerPath(s, role.id);
        expect(turns, isNotEmpty, reason: s.id);
        expect(turns.reduce((a, b) => a < b ? a : b), greaterThanOrEqualTo(2), reason: '${s.id} as ${role.id}');
      }
    }
  });

  test('stories ask the child at least twice and end with a lesson', () {
    for (final s in library.of(TalkKind.story)) {
      final kidChoices = s.blocks.values.where((b) => b.choice?.role == TalkScript.kidRole).length;
      expect(kidChoices, greaterThanOrEqualTo(2), reason: s.id);
    }
  });

  test('the parser reports mistakes with the line number', () {
    String? error(String text) {
      try {
        const TalkParser().parse([text]);
        return null;
      } on TalkFormatException catch (e) {
        return e.message;
      }
    }

    expect(error('=== chat x\ntitle: A | B\n[start]\nbi: no Vietnamese here\n'), contains('line 4'));
    expect(error('bi: Hello | Chào'), isNotNull);
    expect(error('=== chat x\n[a]\n? kid\n- 🙂 Yes | Có\nbi: late line | muộn\n'), contains('line 5'));
  });
}
