// lib/curriculum/scorers/pronunciation_scorer.dart
//
// Compares the Whisper transcript with the target sentence and gives 0-3
// stars. Pure Dart, unit-tested.
import 'dart:math' as math;

import '../../core/config/app_config.dart';
import 'similarity.dart';
import 'text_normalizer.dart';

class PronunciationScore {
  const PronunciationScore({
    required this.similarity,
    required this.stars,
    required this.wordScores,
    required this.heard,
  });

  /// 0..1
  final double similarity;

  /// 0 means "try again"; 1-3 are passing grades.
  final int stars;

  /// Similarity of each target word to its best match in what was heard.
  final List<double> wordScores;
  final String heard;

  bool get passed => stars > 0;
}

class PronunciationScorer {
  const PronunciationScorer({this.difficulty = AppConfig.defaultSpeechDifficulty});

  final SpeechDifficulty difficulty;

  /// Scores [heard] against [target] and any [alternatives]; the best wins.
  PronunciationScore score(String target, String heard, {List<String> alternatives = const []}) {
    var best = _scoreOne(target, heard);
    for (final alternative in alternatives) {
      final candidate = _scoreOne(alternative, heard);
      if (candidate.similarity > best.similarity) {
        best = candidate;
      }
    }
    return best;
  }

  PronunciationScore _scoreOne(String target, String heard) {
    final t = TextNormalizer.tokens(target);
    final h = TextNormalizer.tokens(heard);
    final perWord = Similarity.perWord(t, h);
    double similarity;
    if (t.isEmpty || h.isEmpty) {
      similarity = 0;
    } else if (t.length <= 2) {
      // Single words and two-word phrases: the child may wrap the word in a
      // short sentence ("a cat", "it's a cat"), so take the best window.
      similarity = _bestWindow(t, h);
    } else {
      final wordScore = Similarity.words(t, h);
      final charScore = Similarity.chars(t.join(' '), h.join(' '));
      similarity = 0.7 * wordScore + 0.3 * charScore;
    }
    return PronunciationScore(
      similarity: similarity,
      stars: starsFor(similarity),
      wordScores: perWord,
      heard: heard,
    );
  }

  double _bestWindow(List<String> target, List<String> heard) {
    final joinedTarget = target.join(' ');
    var best = 0.0;
    for (var size = 1; size <= math.min(heard.length, target.length + 1); size++) {
      for (var start = 0; start + size <= heard.length; start++) {
        final window = heard.sublist(start, start + size).join(' ');
        best = math.max(best, Similarity.chars(joinedTarget, window));
      }
    }
    return best;
  }

  int starsFor(double similarity) {
    final thresholds = AppConfig.speechStarThresholds[difficulty]!;
    var stars = 0;
    for (final threshold in thresholds) {
      if (similarity >= threshold) {
        stars++;
      }
    }
    return stars;
  }
}
