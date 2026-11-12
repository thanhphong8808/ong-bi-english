// lib/curriculum/karaoke.dart
//
// Which word Bi is saying right now. The voices give no word timings, so each
// word gets a share of the audio proportional to its syllables, plus a pause
// after commas and full stops. Pure Dart.

/// Rough syllable count of an English word ("apple" -> 2, "cake" -> 1).
int syllableCount(String word) {
  final w = word.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  if (w.isEmpty) {
    return 1;
  }
  if (RegExp(r'^\d+$').hasMatch(w)) {
    return 2 * w.length;
  }
  var n = RegExp(r'[aeiouy]+').allMatches(w).length;
  if (n > 1 && w.endsWith('e') && !w.endsWith('le') && !w.endsWith('ee')) {
    n--; // silent e: "cake", "home"
  }
  return n < 1 ? 1 : n;
}

/// Start of each word as a fraction (0..1) of the spoken sentence.
List<double> wordStarts(List<String> words) {
  if (words.isEmpty) {
    return const [];
  }
  final weights = <double>[];
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    var weight = syllableCount(w) + 0.35;
    if (i < words.length - 1) {
      if (RegExp(r'[.!?]["’]?$').hasMatch(w)) {
        weight += 1.2;
      } else if (RegExp(r'[,;:]$').hasMatch(w)) {
        weight += 0.8;
      }
    }
    weights.add(weight);
  }
  final total = weights.fold<double>(0, (a, b) => a + b);
  final starts = <double>[];
  var acc = 0.0;
  for (final weight in weights) {
    starts.add(acc / total);
    acc += weight;
  }
  return starts;
}

/// The voices start and end with a little silence.
const double karaokeLead = 0.04;
const double karaokeTail = 0.06;

/// How many words have started at [fraction] of the audio (0..words).
int wordsReached(List<double> starts, double fraction) {
  if (starts.isEmpty || fraction <= 0) {
    return 0;
  }
  if (fraction >= 1) {
    return starts.length;
  }
  final f = ((fraction - karaokeLead) / (1 - karaokeLead - karaokeTail)).clamp(0.0, 1.0);
  var n = 0;
  for (final s in starts) {
    if (s <= f) {
      n++;
    }
  }
  return f <= 0 ? 0 : n;
}

/// Same text, ignoring case, spacing and final punctuation.
String karaokeKey(String text) =>
    text.toLowerCase().replaceAll('’', "'").replaceAll(RegExp(r'[^a-z0-9\s]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
