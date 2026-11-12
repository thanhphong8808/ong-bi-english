// lib/curriculum/write_ladder.dart
//
// "Tập viết" step by step: for each curriculum level, the picturable words of
// that level from short to long, in sets of 3-5. A set is learned (look,
// listen, copy) and then tested (write from the picture and the voice); the
// next set opens at 80 %. Writing levels follow the child's level. Pure Dart.
import 'models.dart';

class WriteSet {
  const WriteSet({required this.id, required this.group, required this.index, required this.items});

  /// Stable id for saved scores: `L<level>:<first item id>` or `P:<id>`.
  final String id;

  /// 0-5 for curriculum levels, [WriteLadder.parentGroup] for parent words.
  final int group;

  /// Position inside the group (0 = first set).
  final int index;
  final List<Item> items;
}

class WriteLadder {
  const WriteLadder._();

  static const int parentGroup = -1;

  /// Share of the test to pass a set and open the next one.
  static const double passScore = 0.8;

  static int setSize(int group) => switch (group) {
        parentGroup => 4,
        0 => 3,
        1 => 4,
        _ => 5,
      };

  /// Longest word (letters, spaces included) written at each level.
  static int maxLength(int level) => const [5, 6, 7, 8, 10, 12][level.clamp(0, 5)];

  static final RegExp _word = RegExp(r'^[a-z]+$');
  static final RegExp _phrase = RegExp(r'^[a-z]+ [a-z]+$');

  /// Words a child can be asked to write at [level].
  static bool writable(Item item, int level) {
    if (!item.picturable || item.isLetter || item.image.isEmpty) {
      return false;
    }
    if (item.en != item.en.toLowerCase()) {
      return false; // names and abbreviations: "Thailand", "TV"
    }
    final en = item.en.trim();
    if (en.length < 2 || en.length > maxLength(level)) {
      return false;
    }
    return _word.hasMatch(en) || (level >= 4 && _phrase.hasMatch(en));
  }

  /// Rough difficulty: length first, then letter patterns children find hard.
  static int difficulty(String word) {
    final w = word.toLowerCase();
    var d = w.length * 10;
    for (final hard in const ['th', 'sh', 'ch', 'ph', 'wh', 'ck', 'ee', 'oo', 'ea', 'ou', 'igh', 'tion']) {
      if (w.contains(hard)) {
        d += 3;
      }
    }
    if (RegExp(r'(.)\1').hasMatch(w)) {
      d += 2; // double letters: "apple", "ball"
    }
    return d;
  }

  /// The sets of one curriculum level, easiest first.
  static List<WriteSet> forLevel(Curriculum curriculum, int level) {
    final seen = <String>{};
    final words = <Item>[];
    for (final unit in curriculum.unitsOf(level)) {
      for (final item in unit.items) {
        final key = item.en.trim().toLowerCase();
        if (writable(item, level) && seen.add(key)) {
          words.add(item);
        }
      }
    }
    final order = {for (var i = 0; i < words.length; i++) words[i].id: i};
    words.sort((a, b) {
      final byDifficulty = difficulty(a.en).compareTo(difficulty(b.en));
      return byDifficulty != 0 ? byDifficulty : order[a.id]!.compareTo(order[b.id]!);
    });
    return _chunk(words, level, 'L$level');
  }

  /// The parents' own words, in the order they were added.
  static List<WriteSet> forParentWords(Curriculum curriculum) {
    final words = [
      for (final item in curriculum.parentItems)
        if (RegExp(r'^[a-z]+( [a-z]+)?$').hasMatch(item.en.trim().toLowerCase())) item,
    ];
    return _chunk(words, parentGroup, 'P');
  }

  static List<WriteSet> _chunk(List<Item> words, int group, String prefix) {
    final size = setSize(group);
    final sets = <WriteSet>[];
    for (var start = 0; start < words.length; start += size) {
      var chunk = words.sublist(start, (start + size).clamp(0, words.length));
      // A last set of one or two words joins the previous one.
      if (chunk.length < size && chunk.length < 3 && sets.isNotEmpty) {
        final last = sets.removeLast();
        chunk = [...last.items, ...chunk];
        sets.add(WriteSet(id: last.id, group: group, index: last.index, items: chunk));
        break;
      }
      sets.add(WriteSet(id: '$prefix:${chunk.first.id}', group: group, index: sets.length, items: chunk));
    }
    return sets;
  }

  /// A set is open when it is the first one or the previous one was passed.
  static bool isOpen(List<WriteSet> sets, int index, Map<String, double> best) =>
      index == 0 || (best[sets[index - 1].id] ?? 0) >= passScore;

  /// Stars shown for a score (0 = not tried yet).
  static int stars(double? score) {
    if (score == null) {
      return 0;
    }
    if (score >= 0.95) {
      return 3;
    }
    return score >= passScore ? 2 : 1;
  }
}
