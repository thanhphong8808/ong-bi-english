// lib/curriculum/basic_words.dart

/// Function words a child meets through sentence patterns before they are
/// listed as vocabulary. They never count as "new" words, both for Bi's
/// vocabulary check and for tool/validate_curriculum.dart (keep in sync).
const Set<String> basicWords = {
  'a', 'an', 'the', 'is', 'am', 'are', 'i', 'you', 'he', 'she', 'it', 'we', 'they',
  'my', 'your', 'his', 'her', 'its', 'our', 'their', 'this', 'that', 'these', 'those',
  'and', 'or', 'but', 'to', 'of', 'in', 'on', 'at', 'for', 'with', 'do', 'does', 'did',
  'not', 'no', 'yes', 'oh', 'ok', 'okay', 'hi', 'hello', 'bye', 'yay', 'wow', 'please',
  'thanks', 'thank', 'sure', 'so', 'too', 'very', 'me', 'him', 'them', 'us', 'what',
  'who', 'where', 'when', 'how', 'why', 'can', 'have', 'has', 'had', 'like', 'likes',
  'let', 'lets', 'here', 'there', 'be', 'was', 'were', 'will', 'bi', 'kid', 'into', 'as',
  's', 't', 'm', 're', 've', 'll', 'd', 'o',
  // Pieces of negative contractions (don't, isn't, won't ...).
  'don', 'doesn', 'didn', 'isn', 'aren', 'wasn', 'weren', 'haven', 'hasn', 'won', 'couldn',
  'shouldn', 'wouldn', 'mustn',
};

/// Stem variants so "apples" matches "apple" and "playing" matches "play".
Set<String> wordVariants(String word) {
  final out = <String>{word};
  for (final suffix in const ['s', 'es', 'ed', 'd', 'ing']) {
    if (word.endsWith(suffix) && word.length > suffix.length + 1) {
      out.add(word.substring(0, word.length - suffix.length));
    }
  }
  if (word.endsWith('ies') && word.length > 4) {
    out.add('${word.substring(0, word.length - 3)}y');
  }
  if (word.endsWith('ing') && word.length > 5) {
    out.add('${word.substring(0, word.length - 3)}e');
  }
  for (final suffix in const ['er', 'est', 'ing', 'ed']) {
    if (word.endsWith(suffix) && word.length > suffix.length + 2) {
      final stem = word.substring(0, word.length - suffix.length);
      if (stem.length >= 3 && stem[stem.length - 1] == stem[stem.length - 2]) {
        out.add(stem.substring(0, stem.length - 1));
      }
      if (stem.endsWith('i')) {
        out.add('${stem.substring(0, stem.length - 1)}y');
      }
      out.add(stem);
    }
  }
  return out;
}

final RegExp _nonAscii = RegExp(r'[^\x00-\x7F]');
final RegExp _curlyApostrophe = RegExp('[\u2018\u2019]');

/// Lower-case English word list of [sentence] without punctuation or digits.
/// A word written with Vietnamese letters is skipped whole, so "biết" never
/// leaves an English-looking fragment such as "bi" behind.
List<String> wordTokens(String sentence) {
  final out = <String>[];
  for (final raw in sentence.toLowerCase().replaceAll(_curlyApostrophe, "'").split(RegExp(r'\s+'))) {
    if (_nonAscii.hasMatch(raw)) {
      continue;
    }
    for (final w in raw.replaceAll(RegExp(r"[^a-z0-9'-]"), ' ').split(RegExp(r"[\s'-]+"))) {
      if (w.isNotEmpty && int.tryParse(w) == null) {
        out.add(w);
      }
    }
  }
  return out;
}

bool isKnownWord(String word, Set<String> known) {
  for (final v in wordVariants(word)) {
    if (known.contains(v) || basicWords.contains(v)) {
      return true;
    }
  }
  return false;
}
