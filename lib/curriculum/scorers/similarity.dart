// lib/curriculum/scorers/similarity.dart
import 'dart:math' as math;

/// Edit-distance helpers shared by the scorers. Pure Dart.
class Similarity {
  const Similarity._();

  static int levenshtein(String a, String b) {
    if (a == b) {
      return 0;
    }
    if (a.isEmpty) {
      return b.length;
    }
    if (b.isEmpty) {
      return a.length;
    }
    var previous = List<int>.generate(b.length + 1, (i) => i);
    var current = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      current[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        current[j] = math.min(
          math.min(current[j - 1] + 1, previous[j] + 1),
          previous[j - 1] + cost,
        );
      }
      final swap = previous;
      previous = current;
      current = swap;
    }
    return previous[b.length];
  }

  /// 1.0 for identical strings, 0.0 for completely different ones.
  static double chars(String a, String b) {
    if (a.isEmpty && b.isEmpty) {
      return 1;
    }
    final longest = math.max(a.length, b.length);
    return 1 - levenshtein(a, b) / longest;
  }

  /// Word-level alignment where substituting two similar words costs less
  /// than substituting two different ones. Returns 0..1 relative to [target].
  static double words(List<String> target, List<String> heard) {
    if (target.isEmpty) {
      return heard.isEmpty ? 1 : 0;
    }
    if (heard.isEmpty) {
      return 0;
    }
    final n = target.length;
    final m = heard.length;
    final dp = List.generate(n + 1, (_) => List<double>.filled(m + 1, 0));
    for (var i = 0; i <= n; i++) {
      dp[i][0] = i.toDouble();
    }
    for (var j = 0; j <= m; j++) {
      // Extra words cost half: children often add "yes" or a name.
      dp[0][j] = j * 0.5;
    }
    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        final sub = dp[i - 1][j - 1] + (1 - chars(target[i - 1], heard[j - 1]));
        final del = dp[i - 1][j] + 1;
        final ins = dp[i][j - 1] + 0.5;
        dp[i][j] = math.min(sub, math.min(del, ins));
      }
    }
    return (1 - dp[n][m] / n).clamp(0.0, 1.0).toDouble();
  }

  /// Per-target-word best similarity against any heard word.
  static List<double> perWord(List<String> target, List<String> heard) {
    return [
      for (final word in target)
        heard.isEmpty ? 0.0 : heard.map((h) => chars(word, h)).reduce(math.max),
    ];
  }
}
