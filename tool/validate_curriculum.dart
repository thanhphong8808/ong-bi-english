// tool/validate_curriculum.dart
//
// Validates every unit file listed in assets/curriculum/index.json. Run in CI:
//   dart run tool/validate_curriculum.dart
//
// Checks: JSON schema, duplicate ids, quiz answers present in their options,
// referenced pictures exist, at least 30 questions per unit, 2+ patterns and
// 2+ dialogues (4-8 lines, two roles) per unit, and that example sentences,
// patterns, dialogues and reading texts only use words taught so far
// (at most one new word per sentence). Vocabulary accumulates in index order.
import 'dart:convert';
import 'dart:io';

const String curriculumRoot = 'assets/curriculum';
const String svgRoot = 'assets/svg';
const int maxNewWordsPerSentence = 1;

/// Keep in sync with lib/curriculum/basic_words.dart.
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

/// Character names used in dialogues and stories.
const Set<String> names = {
  'tom', 'lan', 'nam', 'mai', 'ben', 'anna', 'mimi', 'max', 'lily', 'sam', 'minh', 'hoa', 'an',
  'linh', 'kim', 'leo', 'mia', 'nick', 'emma', 'hanoi', 'london', 'paris', 'tokyo', 'hue', 'dong', 'ha', 'sa', 'pa', 'mekong', 'hung', 'tiem',
};

/// Same spelling, different meaning: may be taught twice (keep in sync with
/// POLYSEMOUS in tool/build_curriculum.py).
const Set<String> polysemous = {'orange', 'chicken', 'fit', 'patient', 'sink', 'wave', 'iron'};

const Set<String> skills = {'listen', 'speak', 'read', 'write'};
const Set<String> itemTypes = {'word', 'phrase', 'letter', 'sound'};
const Set<String> writingTypes = {
  'trace_letter', 'write_letter', 'copy_word', 'dictate_word', 'dictate_sentence', 'write_sentences',
};
const Set<String> quizKinds = {
  'pick_image', 'pick_word', 'say_word', 'repeat_sentence', 'answer_question', 'true_false', 'fill_blank',
  'color_item', 'trace_letter', 'write_letter', 'copy_word', 'dictate_word', 'dictate_sentence',
  'letter_sound', 'read_question', 'pick_meaning',
};
const Set<String> kindsWithOptions = {
  'pick_image', 'pick_word', 'true_false', 'fill_blank', 'color_item', 'letter_sound', 'read_question',
  'pick_meaning',
};

class Report {
  final List<String> errors = <String>[];
  final List<String> warnings = <String>[];

  void error(String file, String message) => errors.add('$file: $message');
  void warn(String file, String message) => warnings.add('$file: $message');
}

List<String> tokenize(String sentence) {
  return sentence
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9'\s-]"), ' ')
      .split(RegExp(r"[\s'-]+"))
      .where((w) => w.isNotEmpty && int.tryParse(w) == null)
      .toList();
}

/// Crude stemmer so "apples" matches "apple" and "playing" matches "play".
Set<String> variants(String word) {
  final out = <String>{word};
  for (final suffix in ['s', 'es', 'ed', 'd', 'ing']) {
    if (word.endsWith(suffix) && word.length > suffix.length + 1) {
      out.add(word.substring(0, word.length - suffix.length));
    }
  }
  if (word.endsWith('ies') && word.length > 4) {
    out.add('${word.substring(0, word.length - 3)}y');
  }
  if (word.endsWith('ied') && word.length > 4) {
    out.add('${word.substring(0, word.length - 3)}y');
  }
  if (word.endsWith('ing') && word.length > 5) {
    out.add('${word.substring(0, word.length - 3)}e');
    // running -> run, swimming -> swim
    final stem = word.substring(0, word.length - 3);
    if (stem.length >= 3 && stem[stem.length - 1] == stem[stem.length - 2]) {
      out.add(stem.substring(0, stem.length - 1));
    }
  }
  if (word.endsWith('ed') && word.length > 4) {
    final stem = word.substring(0, word.length - 2);
    if (stem.length >= 3 && stem[stem.length - 1] == stem[stem.length - 2]) {
      out.add(stem.substring(0, stem.length - 1));
    }
  }
  for (final suffix in ['er', 'est']) {
    if (word.endsWith(suffix) && word.length > suffix.length + 2) {
      final stem = word.substring(0, word.length - suffix.length);
      out.add(stem);
      out.add('${stem}e');
      if (stem.length >= 3 && stem[stem.length - 1] == stem[stem.length - 2]) {
        out.add(stem.substring(0, stem.length - 1));
      }
      if (stem.endsWith('i')) {
        out.add('${stem.substring(0, stem.length - 1)}y');
      }
    }
  }
  if (word.endsWith('ly') && word.length > 4) {
    out.add(word.substring(0, word.length - 2));
  }
  return out;
}

bool isKnown(String word, Set<String> known) {
  if (basicWords.contains(word) || names.contains(word)) {
    return true;
  }
  for (final v in variants(word)) {
    if (known.contains(v) || basicWords.contains(v)) {
      return true;
    }
  }
  return false;
}

void checkSentence(String file, String where, String sentence, Set<String> known, Report report) {
  final unknown = <String>{
    for (final word in tokenize(sentence))
      if (!isKnown(word, known)) word,
  };
  if (unknown.length > maxNewWordsPerSentence) {
    report.error(file, '$where uses ${unknown.length} untaught words (${unknown.join(', ')}): "$sentence"');
  }
}

String? requireString(Map<String, dynamic> map, String key, String file, String where, Report r) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    r.error(file, '$where is missing string "$key"');
    return null;
  }
  return value;
}

List<dynamic> listOf(Map<String, dynamic> map, String key) {
  final value = map[key];
  return value is List ? value : const <dynamic>[];
}

void validateUnit(
  String file,
  Map<String, dynamic> unit,
  Set<String> allIds,
  Set<String> known,
  Map<String, bool> pictureWords,
  Report r,
) {
  final unitId = requireString(unit, 'id', file, 'unit', r) ?? '?';
  if (unit['level'] is! int || unit['unit'] is! int) {
    r.error(file, 'unit "level" and "unit" must be integers');
  }
  requireString(unit, 'topic_en', file, 'unit', r);
  requireString(unit, 'topic_vi', file, 'unit', r);
  if (listOf(unit, 'can_do_vi').isEmpty) {
    r.error(file, 'unit needs at least one can_do_vi entry');
  }

  void registerId(String? id, String where) {
    if (id == null) {
      return;
    }
    if (id != unitId && !id.startsWith('$unitId-')) {
      r.error(file, '$where id "$id" must start with "$unitId-"');
    }
    if (!allIds.add(id)) {
      r.error(file, 'duplicate id "$id"');
    }
  }

  registerId(unitId == '?' ? null : unitId, 'unit');

  // Items: the unit's own words become known before its sentences are checked.
  final items = listOf(unit, 'items');
  for (final raw in items) {
    if (raw is! Map<String, dynamic>) {
      r.error(file, 'items must be objects');
      continue;
    }
    final id = requireString(raw, 'id', file, 'item', r);
    registerId(id, 'item');
    final where = 'item ${id ?? '?'}';
    final type = requireString(raw, 'type', file, where, r);
    if (type != null && !itemTypes.contains(type)) {
      r.error(file, '$where has unknown type "$type"');
    }
    final en = requireString(raw, 'en', file, where, r);
    requireString(raw, 'vi', file, where, r);
    if (en != null && type != 'letter') {
      if (pictureWords.containsKey(en.toLowerCase()) && !polysemous.contains(en.toLowerCase())) {
        r.warn(file, '$where repeats "$en", which an earlier unit already teaches');
      }
      known.addAll(tokenize(en));
      pictureWords[en.toLowerCase()] = raw['picturable'] != false;
    }
    if (type == 'letter') {
      requireString(raw, 'letter', file, where, r);
      final soundWords = listOf(raw, 'sound_words');
      if (soundWords.isEmpty) {
        r.error(file, '$where needs sound_words');
      }
      for (final w in soundWords) {
        known.addAll(tokenize('$w'));
      }
    }
    final image = raw['image'];
    if (image is! Map<String, dynamic>) {
      r.error(file, '$where needs an "image" object');
    } else {
      final emoji = image['emoji'];
      final svg = image['svg'];
      if (emoji is String) {
        final ok = emoji.split('-').every((part) => RegExp(r"^[0-9A-Fa-f]{2,6}$").hasMatch(part));
        if (!ok) {
          r.error(file, '$where emoji "$emoji" must be hex code points such as 1F469');
        }
      } else if (svg is String) {
        if (!File('$svgRoot/$svg').existsSync()) {
          r.error(file, '$where references missing SVG $svgRoot/$svg');
        }
      } else {
        r.error(file, '$where image needs "emoji" or "svg"');
      }
    }
    for (final skill in listOf(raw, 'skills')) {
      if (!skills.contains(skill)) {
        r.error(file, '$where has unknown skill "$skill"');
      }
    }
  }

  for (final raw in items) {
    if (raw is! Map<String, dynamic>) {
      continue;
    }
    final example = raw['example_en'];
    if (example is String && example.isNotEmpty) {
      checkSentence(file, 'example of ${raw['id']}', example, known, r);
      if ((raw['example_vi'] as String?)?.isEmpty ?? true) {
        r.error(file, 'item ${raw['id']} has example_en but no example_vi');
      }
    }
  }

  final patterns = listOf(unit, 'patterns');
  if (patterns.length < 2) {
    r.error(file, 'unit needs at least 2 patterns (has ${patterns.length})');
  }
  for (final raw in patterns) {
    if (raw is! Map<String, dynamic>) {
      r.error(file, 'patterns must be objects');
      continue;
    }
    final id = requireString(raw, 'id', file, 'pattern', r);
    registerId(id, 'pattern');
    final en = requireString(raw, 'en', file, 'pattern ${id ?? '?'}', r);
    requireString(raw, 'vi', file, 'pattern ${id ?? '?'}', r);
    final slots = raw['slots'];
    if (en == null) {
      continue;
    }
    final slotNames = RegExp(r'\{(\w+)\}').allMatches(en).map((m) => m.group(1)!).toList();
    if (slotNames.isEmpty) {
      checkSentence(file, 'pattern $id', en, known, r);
    }
    for (final slot in slotNames) {
      final values = slots is Map<String, dynamic> ? slots[slot] : null;
      if (values is! List || values.isEmpty) {
        r.error(file, 'pattern $id has no values for slot {$slot}');
        continue;
      }
      for (final value in values) {
        checkSentence(file, 'pattern $id', en.replaceAll('{$slot}', '$value'), known, r);
      }
    }
  }

  final dialogues = listOf(unit, 'dialogues');
  if (dialogues.length < 2) {
    r.error(file, 'unit needs at least 2 dialogues (has ${dialogues.length})');
  }
  for (final raw in dialogues) {
    if (raw is! Map<String, dynamic>) {
      r.error(file, 'dialogues must be objects');
      continue;
    }
    final id = requireString(raw, 'id', file, 'dialogue', r);
    registerId(id, 'dialogue');
    final roles = listOf(raw, 'roles');
    final lines = listOf(raw, 'lines');
    if (roles.length != 2) {
      r.error(file, 'dialogue $id needs exactly 2 roles');
    }
    if (lines.length < 4 || lines.length > 8) {
      r.error(file, 'dialogue $id must have 4 to 8 lines (has ${lines.length})');
    }
    for (final line in lines) {
      if (line is! Map<String, dynamic>) {
        r.error(file, 'dialogue $id lines must be objects');
        continue;
      }
      if (!roles.contains(line['role'])) {
        r.error(file, 'dialogue $id uses unknown role "${line['role']}"');
      }
      final en = requireString(line, 'en', file, 'dialogue $id line', r);
      requireString(line, 'vi', file, 'dialogue $id line', r);
      if (en != null) {
        checkSentence(file, 'dialogue $id', en, known, r);
      }
    }
    final variation = raw['variation'];
    if (variation is Map<String, dynamic>) {
      final index = variation['line'];
      if (index is! int || index < 0 || index >= lines.length) {
        r.error(file, 'dialogue $id variation points to a missing line');
      }
      for (final option in listOf(variation, 'options')) {
        final words = tokenize('$option');
        if (words.isEmpty || !isKnown(words.last, known)) {
          r.warn(file, 'dialogue $id variation option "$option" is not a taught word');
        }
      }
    }
  }

  final readingIds = <String>{};
  for (final raw in listOf(unit, 'readings')) {
    if (raw is! Map<String, dynamic>) {
      r.error(file, 'readings must be objects');
      continue;
    }
    final id = requireString(raw, 'id', file, 'reading', r);
    registerId(id, 'reading');
    if (id != null) {
      readingIds.add(id);
    }
    requireString(raw, 'title_en', file, 'reading ${id ?? '?'}', r);
    final text = listOf(raw, 'text_en');
    if (text.isEmpty) {
      r.error(file, 'reading $id has no text');
    }
    for (final sentence in text) {
      checkSentence(file, 'reading $id', '$sentence', known, r);
    }
    for (final q in listOf(raw, 'questions')) {
      if (q is! Map<String, dynamic> || !listOf(q, 'options').contains(q['answer'])) {
        r.error(file, 'reading $id has a question whose answer is not among its options');
      }
    }
  }

  for (final raw in listOf(unit, 'writing')) {
    if (raw is! Map<String, dynamic>) {
      r.error(file, 'writing entries must be objects');
      continue;
    }
    if (!writingTypes.contains(raw['type'])) {
      r.error(file, 'writing entry has unknown type "${raw['type']}"');
    }
    requireString(raw, 'target', file, 'writing entry', r);
  }

  final quiz = listOf(unit, 'quiz_bank');
  if (quiz.length < 30) {
    r.error(file, 'quiz_bank needs at least 30 questions (has ${quiz.length})');
  }
  final perSkill = <String, int>{};
  for (final raw in quiz) {
    if (raw is! Map<String, dynamic>) {
      r.error(file, 'quiz questions must be objects');
      continue;
    }
    final id = requireString(raw, 'id', file, 'question', r);
    registerId(id, 'question');
    final skill = requireString(raw, 'skill', file, 'question ${id ?? '?'}', r);
    if (skill != null) {
      if (!skills.contains(skill)) {
        r.error(file, 'question $id has unknown skill "$skill"');
      }
      perSkill[skill] = (perSkill[skill] ?? 0) + 1;
    }
    final kind = requireString(raw, 'kind', file, 'question ${id ?? '?'}', r);
    if (kind != null && !quizKinds.contains(kind)) {
      r.error(file, 'question $id has unknown kind "$kind"');
    }
    final answer = raw['answer'];
    if (answer == null || '$answer'.isEmpty) {
      r.error(file, 'question $id has no answer');
    }
    final options = raw['options'];
    if (kindsWithOptions.contains(kind)) {
      if (options is! List || options.length < 2) {
        r.error(file, 'question $id needs at least 2 options');
      } else {
        if (!options.contains(answer)) {
          r.error(file, 'question $id answer "$answer" is not among its options');
        }
        if (options.toSet().length != options.length) {
          r.error(file, 'question $id has duplicate options');
        }
        if (kind == 'pick_image' || kind == 'color_item') {
          for (final option in options) {
            if (pictureWords['$option'.toLowerCase()] != true) {
              r.error(file, 'question $id option "$option" has no picture');
            }
          }
        }
      }
    }
    if (kind == 'read_question' && !readingIds.contains(raw['reading'])) {
      r.error(file, 'question $id refers to unknown reading "${raw['reading']}"');
    }
    if (kind == 'color_item' && (raw['color'] as String? ?? '').isEmpty) {
      r.error(file, 'question $id needs a colour');
    }
  }
  for (final skill in ['listen', 'speak', 'write']) {
    if ((perSkill[skill] ?? 0) == 0 && quiz.isNotEmpty) {
      r.error(file, 'quiz_bank has no "$skill" questions');
    }
  }
}

void main() {
  final report = Report();
  final indexFile = File('$curriculumRoot/index.json');
  if (!indexFile.existsSync()) {
    stderr.writeln('Missing $curriculumRoot/index.json (run python3 tool/build_curriculum.py)');
    exit(1);
  }
  final index = jsonDecode(indexFile.readAsStringSync());
  final listed = <String>[
    for (final f in (index is Map<String, dynamic> ? index['units'] as List? ?? const [] : const []))
      '$curriculumRoot/$f',
  ];
  final onDisk = Directory(curriculumRoot)
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path.replaceAll('\\', '/'))
      .where((p) => p.endsWith('.json') && !p.endsWith('index.json'))
      .toSet();
  for (final path in onDisk.difference(listed.toSet())) {
    report.error(path, 'not listed in index.json');
  }

  final allIds = <String>{};
  final known = <String>{};
  final pictureWords = <String, bool>{};
  final perLevel = <int, int>{};
  for (final path in listed) {
    final file = File(path);
    if (!file.existsSync()) {
      report.error(path, 'listed in index.json but missing');
      continue;
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync());
    } on FormatException catch (e) {
      report.error(path, 'invalid JSON: ${e.message}');
      continue;
    }
    if (decoded is! Map<String, dynamic>) {
      report.error(path, 'top level must be an object');
      continue;
    }
    final level = decoded['level'];
    if (level is int) {
      perLevel[level] = (perLevel[level] ?? 0) + 1;
    }
    validateUnit(path, decoded, allIds, known, pictureWords, report);
  }
  for (final entry in perLevel.entries) {
    if (entry.value < 10 || entry.value > 16) {
      report.warn('level ${entry.key}', 'has ${entry.value} units (10-16 expected)');
    }
  }

  for (final warning in report.warnings) {
    stdout.writeln('WARN  $warning');
  }
  for (final error in report.errors) {
    stdout.writeln('ERROR $error');
  }
  stdout.writeln(
    'validate_curriculum: ${listed.length} unit file(s), ${known.length} known words, '
    '${report.errors.length} error(s), ${report.warnings.length} warning(s).',
  );
  if (report.errors.isNotEmpty) {
    exit(1);
  }
}
