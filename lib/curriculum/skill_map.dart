// lib/curriculum/skill_map.dart
//
// The parent's detailed skill map, computed from Leitner boxes and the
// spoken-answer log. Pure Dart so it can be tested without a device.
import '../core/config/app_config.dart';
import '../core/db/repositories.dart';

/// How many items sit at each memory strength for one skill.
class SkillStrength {
  const SkillStrength({this.strong = 0, this.growing = 0, this.fresh = 0});

  /// Box >= [AppConfig.leitnerMasteredBox]: remembered for a week or more.
  final int strong;

  /// Box 2-3: remembered for a few days.
  final int growing;

  /// Box 1: just learned or recently forgotten.
  final int fresh;

  int get total => strong + growing + fresh;
}

/// A word whose pronunciation needs more practice.
class PractiseWord {
  const PractiseWord(this.itemId, this.average, this.tries);

  final String itemId;
  final double average;
  final int tries;
}

class SkillMap {
  const SkillMap({
    required this.strength,
    required this.pronunciationWeekly,
    required this.reactionWeekly,
    required this.wordsPerTurnWeekly,
    required this.practise,
    required this.latencyMedianMs,
    required this.talkTurnsWeek,
  });

  static const List<String> skills = ['listen', 'speak', 'read', 'write'];
  static const int weeks = 4;

  /// skill -> strength counts.
  final Map<String, SkillStrength> strength;

  /// Average pronunciation score (0..1) per week, oldest first.
  final List<double?> pronunciationWeekly;

  /// Median time (ms) from Bi falling silent to the child's answer, per week.
  final List<int?> reactionWeekly;

  /// Average English words per answer to Bi, per week.
  final List<double?> wordsPerTurnWeekly;

  /// Words to practise saying, weakest first.
  final List<PractiseWord> practise;

  /// Median wait for the stars during the last 7 days, or null.
  final int? latencyMedianMs;

  /// Answers given to Bi during the last 7 days.
  final int talkTurnsWeek;

  bool get hasSpeech => pronunciationWeekly.any((v) => v != null);
  bool get hasTalk => reactionWeekly.any((v) => v != null) || wordsPerTurnWeekly.any((v) => v != null);

  static SkillMap build({
    required Iterable<ItemProgressRow> rows,
    required Iterable<SpeechTurn> turns,
    required DateTime now,
  }) {
    final counts = {for (final s in skills) s: [0, 0, 0]};
    for (final row in rows) {
      final c = counts[row.skill];
      if (c == null) {
        continue;
      }
      if (row.box >= AppConfig.leitnerMasteredBox) {
        c[0]++;
      } else if (row.box >= 2) {
        c[1]++;
      } else {
        c[2]++;
      }
    }

    final list = turns.toList();
    int weekOf(DateTime at) {
      // 0 = oldest of the four weeks, 3 = the last 7 days; -1 = outside.
      final age = now.difference(at);
      if (age.isNegative) {
        return weeks - 1;
      }
      final back = age.inMicroseconds ~/ const Duration(days: 7).inMicroseconds;
      return back >= weeks ? -1 : weeks - 1 - back;
    }

    final scores = List.generate(weeks, (_) => <double>[]);
    final reactions = List.generate(weeks, (_) => <int>[]);
    final words = List.generate(weeks, (_) => <int>[]);
    final latencies = <int>[];
    final perItem = <String, List<double>>{};
    var talkWeek = 0;
    for (final t in list) {
      final w = weekOf(t.at);
      if (w < 0) {
        continue;
      }
      if (w == weeks - 1 && t.latencyMs >= 0) {
        latencies.add(t.latencyMs);
      }
      if (t.source == SpeechTurn.lesson && t.score >= 0) {
        scores[w].add(t.score);
        if (t.itemId.isNotEmpty) {
          perItem.putIfAbsent(t.itemId, () => []).add(t.score);
        }
      } else if (t.source == SpeechTurn.talk) {
        if (w == weeks - 1) {
          talkWeek++;
        }
        if (t.responseMs >= 0) {
          reactions[w].add(t.responseMs);
        }
        if (t.words > 0) {
          words[w].add(t.words);
        }
      }
    }

    final practise = <PractiseWord>[
      for (final e in perItem.entries)
        if (e.value.length >= 2 && _mean(e.value)! < AppConfig.goodSayScore)
          PractiseWord(e.key, _mean(e.value)!, e.value.length),
    ]..sort((a, b) => a.average.compareTo(b.average));

    return SkillMap(
      strength: {
        for (final e in counts.entries) e.key: SkillStrength(strong: e.value[0], growing: e.value[1], fresh: e.value[2]),
      },
      pronunciationWeekly: [for (final s in scores) _mean(s)],
      reactionWeekly: [for (final r in reactions) _median(r)],
      wordsPerTurnWeekly: [for (final w in words) _mean([for (final n in w) n.toDouble()])],
      practise: practise.take(6).toList(),
      latencyMedianMs: _median(latencies),
      talkTurnsWeek: talkWeek,
    );
  }

  static double? _mean(List<double> values) =>
      values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;

  static int? _median(List<int> values) {
    if (values.isEmpty) {
      return null;
    }
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[mid] : ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }
}

final RegExp _englishWord = RegExp(r"^[A-Za-z]+(?:'[A-Za-z]+)?$");
final RegExp _edgePunctuation = RegExp(r'^[^A-Za-z]+|[^A-Za-z]+$');

/// English words in what the child said ("I like apple!" -> 3).
int englishWordCount(String text) => text
    .split(RegExp(r'\s+'))
    .map((w) => w.replaceAll(_edgePunctuation, ''))
    .where(_englishWord.hasMatch)
    .length;
