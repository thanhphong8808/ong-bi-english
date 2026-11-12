// lib/curriculum/pron_lexicon.dart
//
// American IPA for any English word the child sees: curriculum words first
// (hand-checked), then the CMU Pronouncing Dictionary bundled as
// assets/pron/ipa_en_us.txt.gz (see tool/pron/build_ipa_dict.py). Pure Dart.

/// One word of a sentence, with its pronunciation when known.
class PronToken {
  const PronToken(this.text, this.ipa);

  /// The word as written, punctuation included ("apples!").
  final String text;

  /// IPA without slashes, or null (names, numbers, unknown words).
  final String? ipa;
}

class PronLexicon {
  /// [sortedLines] are "word\tipa" lines sorted by word; [extra] maps lower
  /// case curriculum words to their IPA (slashes allowed).
  PronLexicon(this.sortedLines, {Map<String, String> extra = const {}})
      : _extra = {for (final e in extra.entries) e.key.toLowerCase(): _strip(e.value)};

  static final PronLexicon empty = PronLexicon(const []);

  final List<String> sortedLines;
  final Map<String, String> _extra;

  static const Map<String, String> _ukUs = {
    'colour': 'color', 'colours': 'colors', 'colourful': 'colorful', 'favourite': 'favorite',
    'grey': 'gray', 'centre': 'center', 'theatre': 'theater', 'neighbour': 'neighbor',
    'practise': 'practice', 'jewellery': 'jewelry', 'aeroplane': 'airplane',
    'pyjamas': 'pajamas', 'organise': 'organize', 'flavour': 'flavor', 'honour': 'honor',
  };

  /// Names in the app the dictionary reads another way ("Bi" is not "by").
  static const Map<String, String> _names = {'bi': 'bi', 'mum': 'mʌm'};

  static String _strip(String ipa) => ipa.replaceAll('/', '').trim();

  static final RegExp _edgePunctuation = RegExp(r'''^[\s.,!?;:"“”()\[\]…\-–—']+|[\s.,!?;:"“”()\[\]…\-–—']+$''');

  /// Lower case word without surrounding punctuation ("Apples!" -> "apples").
  /// Letters with accents stay, so Vietnamese names ("Bé") get no IPA.
  static String clean(String word) => word.toLowerCase().replaceAll('’', "'").replaceAll(_edgePunctuation, '');

  bool get isEmpty => sortedLines.isEmpty && _extra.isEmpty;

  /// IPA of one word, or null.
  String? word(String raw) {
    final w = clean(raw);
    if (w.isEmpty || !RegExp(r"^[a-z]+(?:'[a-z]+)?$").hasMatch(w)) {
      return null;
    }
    return _names[w] ?? _extra[w] ?? _find(w) ?? _find(_ukUs[w] ?? '') ?? _plural(w);
  }

  /// Words the dictionary misses but whose singular it knows ("crayons").
  String? _plural(String w) {
    if (w.length > 3 && w.endsWith('s') && !w.endsWith('ss')) {
      final base = _extra[w.substring(0, w.length - 1)] ?? _find(w.substring(0, w.length - 1));
      if (base != null) {
        final last = base.isEmpty ? '' : base[base.length - 1];
        return base + ('ptkfθ'.contains(last) ? 's' : 'z');
      }
    }
    return null;
  }

  String? _find(String w) {
    if (w.isEmpty) {
      return null;
    }
    final key = '$w\t';
    var lo = 0;
    var hi = sortedLines.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final line = sortedLines[mid];
      final tab = line.indexOf('\t');
      final cmp = (tab < 0 ? line : line.substring(0, tab)).compareTo(w);
      if (cmp == 0) {
        return line.startsWith(key) ? line.substring(key.length) : null;
      }
      if (cmp < 0) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return null;
  }

  /// IPA of a word or short phrase ("pencil case" -> "ˈpɛnsəl keɪs"), or
  /// null when any word is unknown.
  String? phrase(String text) {
    final parts = text.split(RegExp(r'[\s\-]+')).where((p) => clean(p).isNotEmpty).toList();
    if (parts.isEmpty) {
      return null;
    }
    final ipas = [for (final p in parts) word(p)];
    return ipas.any((i) => i == null) ? null : ipas.join(' ');
  }

  /// A sentence split into words (punctuation kept on the word) with IPA.
  List<PronToken> tokens(String sentence) => [
        for (final w in sentence.split(RegExp(r'\s+')))
          if (w.isNotEmpty) PronToken(w, word(w)),
      ];
}
