// lib/core/services/content_filter.dart
//
// Deterministic safety layer around the LLM. It never depends on the model
// behaving well: every child utterance and every model reply passes through
// here before anything is spoken. Pure Dart, unit-tested.
import '../config/app_config.dart';

enum FilterVerdict { ok, blocked }

/// Why a text was blocked. Logged for parents.
enum FilterReason {
  none,
  bannedWord,
  url,
  phoneNumber,
  address,
  personalQuestion,
  secrecy,
  tooLong,
  empty,
}

class FilterResult {
  const FilterResult(this.verdict, this.reason, this.safeText);

  final FilterVerdict verdict;
  final FilterReason reason;

  /// The text to speak: the original when ok, otherwise a fixed safe line.
  final String safeText;

  bool get blocked => verdict == FilterVerdict.blocked;
}

class InputCheck {
  const InputCheck({required this.inappropriate, required this.distress});

  /// The child said something unsuitable: Bi changes the subject and never
  /// repeats the word.
  final bool inappropriate;

  /// The child may be sad, scared, hurt or bullied: Bi answers kindly,
  /// suggests telling a parent or teacher, and the session is flagged.
  final bool distress;
}

class ContentFilter {
  const ContentFilter();

  /// Fixed line used whenever a model reply is rejected.
  static const String safeReplyEn = "Let's talk about something fun! Do you like animals?";

  /// Fixed line used when the child says something unsuitable.
  static const String redirectReplyEn = "Let's talk about something else! What's your favourite colour?";

  /// Fixed reply to a distress signal (English, then Vietnamese support line).
  static const String distressReplyEn = "I'm so sorry. Please tell Mum, Dad or your teacher.";
  static const String distressReplyVi = 'Tớ thương cậu lắm. Cậu hãy kể với bố mẹ hoặc cô giáo nhé.';

  static const List<String> _bannedEn = [
    'kill', 'killing', 'murder', 'suicide', 'bloody', 'gun', 'guns', 'shoot', 'shooting',
    'bomb', 'weapon', 'war', 'punch', 'stab', 'stupid', 'idiot', 'dumb', 'ugly', 'loser',
    'shut up', 'damn', 'hell', 'crap', 'shit', 'fuck', 'bitch', 'ass', 'bastard', 'sex',
    'sexy', 'naked', 'nude', 'boyfriend', 'girlfriend', 'drug', 'drugs', 'beer',
    'wine', 'alcohol', 'drunk', 'cigarette', 'smoking', 'vape', 'gamble',
    'devil', 'demon', 'zombie', 'password', 'credit card',
  ];

  /// Words Bi itself must never say, although a child may (they are
  /// handled as distress or ordinary talk on the input side).
  static const List<String> _outputOnlyEn = [
    'hate', 'dead', 'death', 'die', 'died', 'dying', 'blood', 'knife', 'kiss', 'scary', 'ghost',
  ];

  static const List<String> _bannedVi = [
    'giết', 'chết', 'tự tử', 'máu', 'súng', 'bắn', 'bom', 'vũ khí', 'đánh nhau',
    'đâm', 'ghét', 'ngu', 'đần', 'xấu xí', 'béo ú', 'câm mồm', 'im mồm', 'đồ điên',
    'mẹ mày', 'đm', 'đmm', 'dm', 'vcl', 'vl', 'cặc', 'lồn', 'đéo', 'địt', 'đĩ', 'khỏa thân',
    'tình dục', 'hôn nhau', 'người yêu', 'ma túy', 'rượu', 'bia', 'thuốc lá', 'cờ bạc',
    'con ma', 'quỷ', 'mật khẩu',
  ];

  static const List<String> _personalQuestions = [
    'where do you live', 'your address', 'home address', 'what is your address',
    "what's your address", 'phone number', 'your number', 'what school', 'which school',
    'name of your school', "your school's name", 'your full name', 'last name',
    'your surname', 'your password', 'send me a photo', 'send a picture',
    'are you home alone', 'where are your parents', 'địa chỉ', 'số điện thoại',
    'trường nào', 'tên trường', 'nhà cậu ở đâu', 'ở nhà một mình',
  ];

  static const List<String> _secrecy = [
    "don't tell", 'do not tell', 'our secret', 'keep it secret', 'keep a secret',
    'keep this secret', 'secret from', 'just between us', 'đừng nói với', 'đừng kể với',
    'giữ bí mật', 'bí mật của chúng mình',
  ];

  static const List<String> _distress = [
    'sad', 'scared', 'afraid', 'hurt', 'hurts', 'pain', 'crying', 'cry', 'lonely', 'bully',
    'bullied', 'bullies', 'hit me', 'hits me', 'kicked me', 'nobody likes me', 'buồn',
    'sợ', 'đau', 'khóc', 'bắt nạt', 'đánh con', 'đánh tớ', 'đánh em', 'trêu', 'cô đơn',
    'không ai chơi', 'died', 'dead', 'die', 'my pet died',
  ];

  static final RegExp _url = RegExp(
    r'(https?://|www\.|\b[a-z0-9-]+\.(com|net|org|vn|io|app|tv|me|info|xyz)\b)',
    caseSensitive: false,
  );

  /// Seven or more digits, allowing spaces, dots and dashes between them.
  static final RegExp _phone = RegExp(r'(\+?\d[\s.\-]?){7,}');

  static final RegExp _address = RegExp(
    r'\b\d{1,4}\s+[a-z]+\s+(street|st|road|rd|avenue|ave|lane|ln)\b|số nhà\s*\d+|\bngõ\s*\d+|\bphường\b|\bquận\b',
    caseSensitive: false,
  );

  static final RegExp _sentenceEnd = RegExp(r'[.!?…]+');

  static String normalise(String text) {
    return text.toLowerCase().replaceAll(RegExp(r"[^\p{L}\p{N}'\s]", unicode: true), ' ').replaceAll(
          RegExp(r'\s+'),
          ' ',
        ).trim();
  }

  static bool _containsPhrase(String normalised, String phrase) {
    final pattern = RegExp(
      '(?<![\\p{L}\\p{N}])${RegExp.escape(phrase)}(?![\\p{L}\\p{N}])',
      unicode: true,
    );
    return pattern.hasMatch(normalised);
  }

  static bool _containsAny(String normalised, List<String> phrases) {
    for (final phrase in phrases) {
      if (_containsPhrase(normalised, phrase)) {
        return true;
      }
    }
    return false;
  }

  /// Splits into sentences and drops empty fragments.
  static List<String> sentences(String text) {
    return text
        .split(_sentenceEnd)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static int wordCount(String sentence) {
    return sentence.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  /// Checks what the child said (the Whisper transcript).
  InputCheck checkInput(String text) {
    final n = normalise(text);
    final inappropriate = _containsAny(n, _bannedEn) || _containsAny(n, _bannedVi);
    final distress = _containsAny(n, _distress);
    return InputCheck(inappropriate: inappropriate && !distress, distress: distress);
  }

  /// Removes what should never be read aloud: emoji, markdown, stage
  /// directions such as *waves* or (laughs), and stray symbols.
  static String cleanModelText(String text) {
    // Bold and underline markers keep their words; *actions* are dropped.
    var t = text.replaceAllMapped(RegExp(r'(\*\*|__)([^*_]{1,60})\1'), (m) => m[2]!);
    t = t.replaceAll(RegExp(r'\*[^*]{0,40}\*'), ' ');
    t = t.replaceAll(RegExp(r'\([^)]{0,40}\)'), ' ');
    t = t.replaceAll(RegExp(r'\[[^\]]{0,40}\]'), ' ');
    t = t.replaceAll(RegExp("[^A-Za-z0-9\u00C0-\u1EF9'.,!?\\- ]"), ' ');
    return t.replaceAll(RegExp(r'\s+'), ' ').replaceAllMapped(RegExp(r' ([.,!?])'), (m) => m[1]!).trim();
  }

  /// Safety check for one sentence of a streamed reply (no length rules).
  FilterResult checkSentence(String sentence, {required int level}) {
    final trimmed = sentence.trim();
    if (trimmed.isEmpty) {
      return const FilterResult(FilterVerdict.blocked, FilterReason.empty, safeReplyEn);
    }
    if (_url.hasMatch(trimmed)) {
      return const FilterResult(FilterVerdict.blocked, FilterReason.url, safeReplyEn);
    }
    if (_phone.hasMatch(trimmed)) {
      return const FilterResult(FilterVerdict.blocked, FilterReason.phoneNumber, safeReplyEn);
    }
    if (_address.hasMatch(trimmed)) {
      return const FilterResult(FilterVerdict.blocked, FilterReason.address, safeReplyEn);
    }
    final n = normalise(trimmed);
    if (_containsAny(n, _secrecy)) {
      return const FilterResult(FilterVerdict.blocked, FilterReason.secrecy, safeReplyEn);
    }
    if (_containsAny(n, _personalQuestions)) {
      return const FilterResult(FilterVerdict.blocked, FilterReason.personalQuestion, safeReplyEn);
    }
    if (_containsAny(n, _bannedEn) || _containsAny(n, _outputOnlyEn) || _containsAny(n, _bannedVi)) {
      return const FilterResult(FilterVerdict.blocked, FilterReason.bannedWord, safeReplyEn);
    }
    final maxWords = level <= 1
        ? AppConfig.biMaxWordsPerSentenceLow
        : AppConfig.biMaxWordsPerSentenceHigh;
    if (wordCount(trimmed) > maxWords || trimmed.length > AppConfig.biMaxReplyChars) {
      return const FilterResult(FilterVerdict.blocked, FilterReason.tooLong, safeReplyEn);
    }
    return FilterResult(FilterVerdict.ok, FilterReason.none, trimmed);
  }

  /// Checks a model reply before it is spoken. [level] is the child's level.
  FilterResult checkOutput(String text, {required int level}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const FilterResult(FilterVerdict.blocked, FilterReason.empty, safeReplyEn);
    }
    if (_url.hasMatch(trimmed)) {
      return const FilterResult(FilterVerdict.blocked, FilterReason.url, safeReplyEn);
    }
    if (_phone.hasMatch(trimmed)) {
      return const FilterResult(FilterVerdict.blocked, FilterReason.phoneNumber, safeReplyEn);
    }
    if (_address.hasMatch(trimmed)) {
      return const FilterResult(FilterVerdict.blocked, FilterReason.address, safeReplyEn);
    }
    final n = normalise(trimmed);
    if (_containsAny(n, _secrecy)) {
      return const FilterResult(FilterVerdict.blocked, FilterReason.secrecy, safeReplyEn);
    }
    if (_containsAny(n, _personalQuestions)) {
      return const FilterResult(FilterVerdict.blocked, FilterReason.personalQuestion, safeReplyEn);
    }
    if (_containsAny(n, _bannedEn) || _containsAny(n, _outputOnlyEn) || _containsAny(n, _bannedVi)) {
      return const FilterResult(FilterVerdict.blocked, FilterReason.bannedWord, safeReplyEn);
    }

    final maxWords = level <= 1
        ? AppConfig.biMaxWordsPerSentenceLow
        : AppConfig.biMaxWordsPerSentenceHigh;
    final parts = sentences(trimmed);
    final tooManySentences = parts.length > AppConfig.biMaxSentencesPerTurn;
    final tooManyWords = parts.any((s) => wordCount(s) > maxWords);
    if (tooManySentences || tooManyWords || trimmed.length > AppConfig.biMaxReplyChars) {
      return const FilterResult(FilterVerdict.blocked, FilterReason.tooLong, safeReplyEn);
    }
    return FilterResult(FilterVerdict.ok, FilterReason.none, trimmed);
  }
}
