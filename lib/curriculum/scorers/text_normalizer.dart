// lib/curriculum/scorers/text_normalizer.dart
//
// Normalises English text before comparing what the child said or wrote with
// the target: lower case, no punctuation, contractions expanded, numbers as
// words, homophones and spelling variants mapped to one form.

class TextNormalizer {
  const TextNormalizer._();

  static const Map<String, String> _contractions = {
    "i'm": 'i am',
    "you're": 'you are',
    "he's": 'he is',
    "she's": 'she is',
    "it's": 'it is',
    "we're": 'we are',
    "they're": 'they are',
    "that's": 'that is',
    "what's": 'what is',
    "where's": 'where is',
    "who's": 'who is',
    "how's": 'how is',
    "there's": 'there is',
    "here's": 'here is',
    "let's": 'let us',
    "i've": 'i have',
    "you've": 'you have',
    "we've": 'we have',
    "they've": 'they have',
    "i'll": 'i will',
    "you'll": 'you will',
    "we'll": 'we will',
    "it'll": 'it will',
    "i'd": 'i would',
    "don't": 'do not',
    "doesn't": 'does not',
    "didn't": 'did not',
    "isn't": 'is not',
    "aren't": 'are not',
    "wasn't": 'was not',
    "weren't": 'were not',
    "can't": 'can not',
    "cannot": 'can not',
    "couldn't": 'could not',
    "won't": 'will not',
    "wouldn't": 'would not',
    "shouldn't": 'should not',
    "haven't": 'have not',
    "hasn't": 'has not',
  };

  /// Each set maps to its first member.
  static const List<List<String>> _equivalents = [
    ['two', 'to', 'too'],
    ['four', 'for'],
    ['eight', 'ate'],
    ['one', 'won'],
    ['there', 'their'],
    ['see', 'sea'],
    ['bee', 'be'],
    ['by', 'buy', 'bye'],
    ['know', 'no'],
    ['hear', 'here'],
    ['right', 'write'],
    ['sun', 'son'],
    ['pear', 'pair'],
    ['blue', 'blew'],
    ['i', 'eye'],
    ['meet', 'meat'],
    ['week', 'weak'],
    ['flower', 'flour'],
    ['tail', 'tale'],
    ['road', 'rode'],
    ['night', 'knight'],
    ['mum', 'mom', 'mam', 'mama', 'mommy', 'mummy'],
    ['dad', 'daddy'],
    ['colour', 'color'],
    ['colours', 'colors'],
    ['favourite', 'favorite'],
    ['grey', 'gray'],
    ['okay', 'ok'],
    ['yes', 'yeah', 'yep'],
    ['hi', 'hey'],
    ['goodbye', 'good bye'],
    ['ice cream', 'icecream'],
  ];

  static const Set<String> fillers = {'uh', 'um', 'er', 'erm', 'ah', 'hmm', 'mm', 'oh', 'huh'};

  static const List<String> _ones = [
    'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten',
    'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen',
    'eighteen', 'nineteen',
  ];

  static const List<String> _tens = [
    '', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety',
  ];

  static final Map<String, String> _equivalentMap = () {
    final map = <String, String>{};
    for (final group in _equivalents) {
      for (final word in group) {
        map[word] = group.first;
      }
    }
    return map;
  }();

  /// 0..9999 as English words; larger numbers are left as digits.
  static String numberToWords(int n) {
    if (n < 0 || n > 9999) {
      return '$n';
    }
    if (n < 20) {
      return _ones[n];
    }
    if (n < 100) {
      final rest = n % 10;
      return rest == 0 ? _tens[n ~/ 10] : '${_tens[n ~/ 10]} ${_ones[rest]}';
    }
    if (n < 1000) {
      final rest = n % 100;
      final head = '${_ones[n ~/ 100]} hundred';
      return rest == 0 ? head : '$head ${numberToWords(rest)}';
    }
    final rest = n % 1000;
    final head = '${_ones[n ~/ 1000]} thousand';
    return rest == 0 ? head : '$head ${numberToWords(rest)}';
  }

  /// Normalised text as a single string.
  static String normalize(String text) => tokens(text).join(' ');

  /// Normalised word list.
  static List<String> tokens(String text, {bool dropFillers = true}) {
    var t = text.toLowerCase();
    t = t.replaceAll(RegExp('[‘’ʼ`]'), "'");
    t = t.replaceAll(RegExp('[“”]'), '"');
    t = t.replaceAllMapped(RegExp(r'\d+'), (m) => ' ${numberToWords(int.parse(m.group(0)!))} ');
    t = t.replaceAll('-', ' ');
    t = t.replaceAll(RegExp(r"[^a-z' ]"), ' ');
    final words = <String>[];
    for (var raw in t.split(RegExp(r'\s+'))) {
      raw = raw.trim();
      if (raw.isEmpty) {
        continue;
      }
      final expanded = _contractions[raw];
      final parts = expanded != null ? expanded.split(' ') : [raw.replaceAll("'", '')];
      for (final part in parts) {
        if (part.isEmpty || (dropFillers && fillers.contains(part))) {
          continue;
        }
        words.add(_equivalentMap[part] ?? part);
      }
    }
    // Two-word equivalents such as "good bye".
    final joined = words.join(' ');
    var out = joined;
    for (final entry in _equivalentMap.entries) {
      if (entry.key.contains(' ') && out.contains(entry.key)) {
        out = out.replaceAll(entry.key, entry.value);
      }
    }
    return out.isEmpty ? <String>[] : out.split(' ');
  }
}
