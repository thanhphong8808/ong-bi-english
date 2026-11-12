// test/write_ladder_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ong_bi_english/curriculum/models.dart';
import 'package:ong_bi_english/curriculum/pron_lexicon.dart';
import 'package:ong_bi_english/curriculum/write_ladder.dart';

import 'support/curriculum_fixture.dart';

void main() {
  final c = loadCurriculum();

  test('every level has sets of 3 to 5 picturable words, short words first', () {
    for (var level = 0; level < 6; level++) {
      final sets = WriteLadder.forLevel(c, level);
      expect(sets.length, greaterThanOrEqualTo(5), reason: 'level $level');
      final size = WriteLadder.setSize(level);
      expect(size, inInclusiveRange(3, 5));
      final ids = <String>{};
      String? previousFirst;
      for (final set in sets) {
        expect(ids.add(set.id), isTrue, reason: 'unique id ${set.id}');
        expect(set.items.length, inInclusiveRange(3, size + 2), reason: set.id);
        for (final item in set.items) {
          expect(WriteLadder.writable(item, level), isTrue, reason: item.en);
          expect(item.image.isEmpty, isFalse, reason: item.en);
          expect(item.en.length, lessThanOrEqualTo(WriteLadder.maxLength(level)));
        }
        if (previousFirst != null) {
          expect(
            WriteLadder.difficulty(set.items.first.en),
            greaterThanOrEqualTo(WriteLadder.difficulty(previousFirst)),
            reason: 'easy to hard: ${set.items.first.en} after $previousFirst',
          );
        }
        previousFirst = set.items.first.en;
      }
      // The first set of the first level is really easy.
      if (level == 0) {
        expect(sets.first.items.every((i) => i.en.length <= 3), isTrue, reason: sets.first.items.map((i) => i.en).join(','));
      }
    }
  });

  test('a set opens when the one before was passed with 80 %', () {
    final sets = WriteLadder.forLevel(c, 0);
    expect(WriteLadder.isOpen(sets, 0, const {}), isTrue);
    expect(WriteLadder.isOpen(sets, 1, const {}), isFalse);
    expect(WriteLadder.isOpen(sets, 1, {sets[0].id: 0.79}), isFalse);
    expect(WriteLadder.isOpen(sets, 1, {sets[0].id: 0.8}), isTrue);
    expect(WriteLadder.stars(null), 0);
    expect(WriteLadder.stars(0.5), 1);
    expect(WriteLadder.stars(0.8), 2);
    expect(WriteLadder.stars(1), 3);
  });

  test('parent words form their own sets of four', () {
    Item word(int id, String en) => Item(
          id: 'P-$id',
          unitId: Curriculum.parentUnitId,
          level: 0,
          type: ItemType.word,
          en: en,
          vi: 'x',
          image: ItemImage.fromEmoji('📚'),
          exampleEn: '',
          exampleVi: '',
          skills: const ['write'],
          picturable: true,
        );
    c.setParentItems([
      for (final (i, en) in const [(1, 'ruler'), (2, 'desk'), (3, 'chair'), (4, 'board'), (5, 'eraser'), (6, 'glue')])
        word(i, en),
      word(7, 'pencil case'),
    ]);
    final sets = WriteLadder.forParentWords(c);
    c.setParentItems(const []);
    expect(sets.map((s) => s.items.length).toList(), [4, 3]);
    expect(sets.first.id, 'P:P-1');
    expect(sets.first.group, WriteLadder.parentGroup);
  });

  test('the bundled dictionary gives IPA for sentences and parent words', () {
    final lines = utf8
        .decode(GZipCodec().decode(File('assets/pron/ipa_en_us.txt.gz').readAsBytesSync()))
        .split('\n')
        .where((l) => l.isNotEmpty)
        .toList();
    final lexicon = PronLexicon(lines, extra: const {'bi': '/bi/'});
    expect(lexicon.word('Hello,'), 'həˈloʊ');
    expect(lexicon.word("I'm"), 'aɪm');
    expect(lexicon.word('Bi!'), 'bi');
    expect(lexicon.word('Bé!'), isNull);
    expect(lexicon.word('Mum,'), 'mʌm');
    expect(lexicon.word('"Yes!"'), lexicon.word('yes'));
    expect(lexicon.word('(red)'), lexicon.word('red'));
    expect(lexicon.word('crayons'), isNotNull);
    expect(lexicon.word('zzzq'), isNull);
    expect(lexicon.word('123'), isNull);
    expect(lexicon.phrase('pencil case'), 'ˈpɛnsəl keɪs');
    expect(lexicon.phrase('colour'), lexicon.word('color'));
    final tokens = lexicon.tokens('I like apples!');
    expect(tokens.map((t) => t.text).toList(), ['I', 'like', 'apples!']);
    expect(tokens.every((t) => t.ipa != null), isTrue);
    // Every curriculum word shows a pronunciation.
    var missing = 0;
    for (final unit in c.units) {
      for (final item in unit.items) {
        if (!item.isLetter && item.ipa.isEmpty && lexicon.phrase(item.en) == null) {
          missing++;
        }
      }
    }
    expect(missing, 0);
  });
}
