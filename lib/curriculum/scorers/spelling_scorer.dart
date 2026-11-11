// lib/curriculum/scorers/spelling_scorer.dart
import 'similarity.dart';

class SpellingResult {
  const SpellingResult({
    required this.target,
    required this.written,
    required this.correct,
    required this.score,
    required this.letterOk,
  });

  final String target;
  final String written;
  final bool correct;

  /// 0..1 character similarity.
  final double score;

  /// For each character of [target]: whether the child wrote it correctly.
  final List<bool> letterOk;
}

/// Checks a handwritten or typed answer letter by letter. Case, extra spaces
/// and final punctuation are ignored, because 6-9 year olds are graded on
/// spelling, not typography.
class SpellingScorer {
  const SpellingScorer();

  static String clean(String text) => text
      .toLowerCase()
      .replaceAll(RegExp('[‘’]'), "'")
      .replaceAll(RegExp(r'[.!?,;:"]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Picks the best of several recognition candidates.
  SpellingResult bestOf(String target, List<String> candidates) {
    if (candidates.isEmpty) {
      return score(target, '');
    }
    SpellingResult? best;
    for (final candidate in candidates) {
      final result = score(target, candidate);
      if (best == null || result.score > best.score) {
        best = result;
      }
    }
    return best!;
  }

  SpellingResult score(String target, String written) {
    final t = clean(target);
    final w = clean(written);
    final letterOk = <bool>[];
    for (var i = 0; i < t.length; i++) {
      letterOk.add(i < w.length && w[i] == t[i]);
    }
    return SpellingResult(
      target: target,
      written: written,
      correct: t == w,
      score: Similarity.chars(t, w),
      letterOk: letterOk,
    );
  }
}
