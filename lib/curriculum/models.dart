// lib/curriculum/models.dart
//
// In-memory model of the curriculum JSON files (see docs/ARCHITECTURE.md).
// Pure Dart: no Flutter imports, so it is unit-testable.

List<String> _strings(Object? value) =>
    value is List ? value.map((e) => '$e').toList() : const <String>[];

String _string(Map<String, dynamic> map, String key) => (map[key] as String?) ?? '';

/// Picture for an item: an emoji (hex code points) or an SVG asset.
class ItemImage {
  const ItemImage({this.emojiHex, this.svg});

  factory ItemImage.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return const ItemImage();
    }
    return ItemImage(emojiHex: json['emoji'] as String?, svg: json['svg'] as String?);
  }

  final String? emojiHex;
  final String? svg;

  /// The emoji as a displayable string, e.g. "1F469" -> 👩.
  String? get emoji {
    final hex = emojiHex;
    if (hex == null || hex.isEmpty) {
      return null;
    }
    final codes = hex.split('-').map((part) => int.tryParse(part, radix: 16)).whereType<int>();
    return String.fromCharCodes(codes);
  }

  bool get isEmpty => emojiHex == null && svg == null;
}

enum ItemType { word, phrase, letter, sound }

class Item {
  const Item({
    required this.id,
    required this.unitId,
    required this.level,
    required this.type,
    required this.en,
    required this.vi,
    required this.image,
    required this.exampleEn,
    required this.exampleVi,
    required this.skills,
    this.ipa = '',
    this.syllables = const [],
    this.phonics = '',
    this.pronFocus = const [],
    this.picturable = true,
    this.category = '',
    this.letter = '',
    this.sound = '',
    this.soundWords = const [],
    this.tipVi = '',
  });

  factory Item.fromJson(Map<String, dynamic> json, {required String unitId, required int level}) {
    final typeName = _string(json, 'type');
    return Item(
      id: _string(json, 'id'),
      unitId: unitId,
      level: level,
      type: ItemType.values.firstWhere((t) => t.name == typeName, orElse: () => ItemType.word),
      en: _string(json, 'en'),
      vi: _string(json, 'vi'),
      image: ItemImage.fromJson(json['image']),
      exampleEn: _string(json, 'example_en'),
      exampleVi: _string(json, 'example_vi'),
      skills: _strings(json['skills']),
      ipa: _string(json, 'ipa'),
      syllables: _strings(json['syllables']),
      phonics: _string(json, 'phonics'),
      pronFocus: _strings(json['pron_focus']),
      picturable: (json['picturable'] as bool?) ?? true,
      category: _string(json, 'cat'),
      letter: _string(json, 'letter'),
      sound: _string(json, 'sound'),
      soundWords: _strings(json['sound_words']),
      tipVi: _string(json, 'tip_vi'),
    );
  }

  final String id;
  final String unitId;
  final int level;
  final ItemType type;
  final String en;
  final String vi;
  final ItemImage image;
  final String exampleEn;
  final String exampleVi;

  /// Subset of listen, speak, read, write.
  final List<String> skills;
  final String ipa;
  final List<String> syllables;
  final String phonics;

  /// Typical Vietnamese-learner pronunciation issues this item practises.
  final List<String> pronFocus;

  /// False for abstract words whose emoji is only a hint: they never appear
  /// in "pick the picture" questions.
  final bool picturable;
  final String category;

  // Letter-sound (phonics) items only.
  final String letter;
  final String sound;
  final List<String> soundWords;
  final String tipVi;

  bool get isLetter => type == ItemType.letter;

  bool hasSkill(String skill) => skills.contains(skill);
}

class Pattern {
  const Pattern({
    required this.id,
    required this.en,
    required this.vi,
    required this.slots,
    this.slotsVi = const {},
  });

  factory Pattern.fromJson(Map<String, dynamic> json) {
    Map<String, List<String>> readSlots(Object? raw) {
      if (raw is! Map<String, dynamic>) {
        return const {};
      }
      return {for (final e in raw.entries) e.key: _strings(e.value)};
    }

    return Pattern(
      id: _string(json, 'id'),
      en: _string(json, 'en'),
      vi: _string(json, 'vi'),
      slots: readSlots(json['slots']),
      slotsVi: readSlots(json['slots_vi']),
    );
  }

  final String id;
  final String en;
  final String vi;
  final Map<String, List<String>> slots;
  final Map<String, List<String>> slotsVi;

  /// Every concrete English sentence the pattern can produce (first slot only
  /// varies when there are several slots, to keep the list short).
  List<String> expansions() {
    if (slots.isEmpty) {
      return [en];
    }
    final out = <String>[];
    final names = slots.keys.toList();
    final first = names.first;
    for (final value in slots[first]!) {
      var sentence = en.replaceAll('{$first}', value);
      for (final other in names.skip(1)) {
        final values = slots[other]!;
        if (values.isNotEmpty) {
          sentence = sentence.replaceAll('{$other}', values.first);
        }
      }
      out.add(sentence);
    }
    return out;
  }

  /// Vietnamese for the expansion at [index] of the first slot.
  String viFor(int index) {
    if (slots.isEmpty) {
      return vi;
    }
    var text = vi;
    for (final name in slots.keys) {
      final viValues = slotsVi[name];
      final enValues = slots[name]!;
      final i = name == slots.keys.first ? index : 0;
      final value = (viValues != null && i < viValues.length)
          ? viValues[i]
          : (i < enValues.length ? enValues[i] : '');
      text = text.replaceAll('{$name}', value);
    }
    return text;
  }
}

class DialogueLine {
  const DialogueLine({required this.role, required this.en, required this.vi});

  factory DialogueLine.fromJson(Map<String, dynamic> json) =>
      DialogueLine(role: _string(json, 'role'), en: _string(json, 'en'), vi: _string(json, 'vi'));

  final String role;
  final String en;
  final String vi;
}

/// Step 4 of dialogue learning: swap a key word for other learned words.
class DialogueVariation {
  const DialogueVariation({required this.line, required this.key, required this.options});

  static DialogueVariation? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    return DialogueVariation(
      line: (json['line'] as int?) ?? 0,
      key: _string(json, 'key'),
      options: _strings(json['options']),
    );
  }

  final int line;
  final String key;
  final List<String> options;
}

class Dialogue {
  const Dialogue({
    required this.id,
    required this.titleVi,
    required this.roles,
    required this.lines,
    this.variation,
  });

  factory Dialogue.fromJson(Map<String, dynamic> json) => Dialogue(
        id: _string(json, 'id'),
        titleVi: _string(json, 'title_vi'),
        roles: _strings(json['roles']),
        lines: [
          for (final line in (json['lines'] as List? ?? const []))
            if (line is Map<String, dynamic>) DialogueLine.fromJson(line),
        ],
        variation: DialogueVariation.fromJson(json['variation']),
      );

  final String id;
  final String titleVi;
  final List<String> roles;
  final List<DialogueLine> lines;
  final DialogueVariation? variation;

  /// The role the child usually plays: "Kid" when present, else the role
  /// that is not Bi, else the second one.
  String get kidRole => roles.contains('Kid')
      ? 'Kid'
      : roles.firstWhere((r) => r != 'Bi', orElse: () => roles.last);
}

class WritingTask {
  const WritingTask({required this.type, required this.target});

  factory WritingTask.fromJson(Map<String, dynamic> json) =>
      WritingTask(type: _string(json, 'type'), target: _string(json, 'target'));

  /// trace_letter | write_letter | copy_word | dictate_word | dictate_sentence | write_sentences
  final String type;
  final String target;
}

enum QuizKind {
  pickImage,
  pickWord,
  sayWord,
  repeatSentence,
  answerQuestion,
  trueFalse,
  fillBlank,
  colorItem,
  traceLetter,
  writeLetter,
  copyWord,
  dictateWord,
  dictateSentence,
  letterSound,
  readQuestion,
  pickMeaning,
}

const Map<String, QuizKind> quizKindNames = {
  'pick_image': QuizKind.pickImage,
  'pick_word': QuizKind.pickWord,
  'say_word': QuizKind.sayWord,
  'repeat_sentence': QuizKind.repeatSentence,
  'answer_question': QuizKind.answerQuestion,
  'true_false': QuizKind.trueFalse,
  'fill_blank': QuizKind.fillBlank,
  'color_item': QuizKind.colorItem,
  'trace_letter': QuizKind.traceLetter,
  'write_letter': QuizKind.writeLetter,
  'copy_word': QuizKind.copyWord,
  'dictate_word': QuizKind.dictateWord,
  'dictate_sentence': QuizKind.dictateSentence,
  'letter_sound': QuizKind.letterSound,
  'read_question': QuizKind.readQuestion,
  'pick_meaning': QuizKind.pickMeaning,
};

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.unitId,
    required this.skill,
    required this.kind,
    required this.answer,
    this.audioEn = '',
    this.textEn = '',
    this.item = '',
    this.options = const [],
    this.accept = const [],
    this.color = '',
    this.reading = '',
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json, {required String unitId}) {
    return QuizQuestion(
      id: _string(json, 'id'),
      unitId: unitId,
      skill: _string(json, 'skill'),
      kind: quizKindNames[_string(json, 'kind')] ?? QuizKind.pickImage,
      answer: '${json['answer'] ?? ''}',
      audioEn: _string(json, 'audio_en'),
      textEn: _string(json, 'text_en'),
      item: _string(json, 'item'),
      options: _strings(json['options']),
      accept: _strings(json['accept']),
      color: _string(json, 'color'),
      reading: _string(json, 'reading'),
    );
  }

  final String id;
  final String unitId;

  /// listen | speak | read | write
  final String skill;
  final QuizKind kind;
  final String answer;
  final String audioEn;
  final String textEn;

  /// English word of the item whose picture is shown.
  final String item;
  final List<String> options;

  /// Extra acceptable spoken answers.
  final List<String> accept;
  final String color;

  /// Reading-text id for reading-comprehension questions.
  final String reading;

  bool get needsReading =>
      skill == 'read' ||
      kind == QuizKind.pickWord ||
      kind == QuizKind.trueFalse ||
      kind == QuizKind.fillBlank ||
      kind == QuizKind.copyWord ||
      kind == QuizKind.letterSound ||
      kind == QuizKind.readQuestion;
}

class ReadingQuestion {
  const ReadingQuestion({required this.question, required this.options, required this.answer});

  factory ReadingQuestion.fromJson(Map<String, dynamic> json) => ReadingQuestion(
        question: _string(json, 'q'),
        options: _strings(json['options']),
        answer: _string(json, 'answer'),
      );

  final String question;
  final List<String> options;
  final String answer;
}

/// A short reading text (level 2 up) with comprehension questions.
class Reading {
  const Reading({required this.id, required this.titleEn, required this.sentences, required this.questions});

  factory Reading.fromJson(Map<String, dynamic> json) => Reading(
        id: _string(json, 'id'),
        titleEn: _string(json, 'title_en'),
        sentences: _strings(json['text_en']),
        questions: [
          for (final q in (json['questions'] as List? ?? const []))
            if (q is Map<String, dynamic>) ReadingQuestion.fromJson(q),
        ],
      );

  final String id;
  final String titleEn;
  final List<String> sentences;
  final List<ReadingQuestion> questions;

  String get text => sentences.join(' ');
}

class Unit {
  const Unit({
    required this.id,
    required this.level,
    required this.number,
    required this.topicEn,
    required this.topicVi,
    required this.canDoVi,
    required this.items,
    required this.patterns,
    required this.dialogues,
    required this.writing,
    required this.quizBank,
    this.readings = const [],
    this.grammarNoteVi = '',
  });

  factory Unit.fromJson(Map<String, dynamic> json) {
    final id = _string(json, 'id');
    final level = (json['level'] as int?) ?? 0;
    List<Map<String, dynamic>> maps(String key) => [
          for (final e in (json[key] as List? ?? const []))
            if (e is Map<String, dynamic>) e,
        ];
    return Unit(
      id: id,
      level: level,
      number: (json['unit'] as int?) ?? 0,
      topicEn: _string(json, 'topic_en'),
      topicVi: _string(json, 'topic_vi'),
      canDoVi: _strings(json['can_do_vi']),
      items: [for (final m in maps('items')) Item.fromJson(m, unitId: id, level: level)],
      patterns: [for (final m in maps('patterns')) Pattern.fromJson(m)],
      dialogues: [for (final m in maps('dialogues')) Dialogue.fromJson(m)],
      writing: [for (final m in maps('writing')) WritingTask.fromJson(m)],
      quizBank: [for (final m in maps('quiz_bank')) QuizQuestion.fromJson(m, unitId: id)],
      readings: [for (final m in maps('readings')) Reading.fromJson(m)],
      grammarNoteVi: _string(json, 'grammar_note_vi'),
    );
  }

  final String id;
  final int level;
  final int number;
  final String topicEn;
  final String topicVi;
  final List<String> canDoVi;
  final List<Item> items;
  final List<Pattern> patterns;
  final List<Dialogue> dialogues;
  final List<WritingTask> writing;
  final List<QuizQuestion> quizBank;
  final List<Reading> readings;

  /// Short Vietnamese grammar explanation (level 3 up).
  final String grammarNoteVi;
}

/// The whole curriculum with lookup indexes.
class Curriculum {
  Curriculum(List<Unit> units)
      : units = List.unmodifiable(units..sort((a, b) => a.id.compareTo(b.id))) {
    for (final unit in this.units) {
      for (final item in unit.items) {
        _itemsById[item.id] = item;
        _itemsByWord.putIfAbsent(item.en.toLowerCase(), () => item);
      }
      for (final dialogue in unit.dialogues) {
        _dialogues[dialogue.id] = dialogue;
      }
      for (final reading in unit.readings) {
        _readings[reading.id] = reading;
      }
    }
  }

  final List<Unit> units;
  final Map<String, Item> _itemsById = {};
  final Map<String, Item> _itemsByWord = {};
  final Map<String, Dialogue> _dialogues = {};
  final Map<String, Reading> _readings = {};

  Reading? reading(String id) => _readings[id];

  static const int levelCount = 6;

  List<Unit> unitsOf(int level) => units.where((u) => u.level == level).toList();

  Unit? unitById(String id) {
    for (final unit in units) {
      if (unit.id == id) {
        return unit;
      }
    }
    return null;
  }

  Item? item(String id) => _itemsById[id];

  /// First item whose English text equals [word] (case-insensitive).
  Item? itemByWord(String word) => _itemsByWord[word.toLowerCase()];

  Dialogue? dialogue(String id) => _dialogues[id];

  /// All items taught up to and including [level] / [unitIndex] of that level.
  List<Item> itemsUpTo(int level, int unitIndex) {
    final out = <Item>[];
    for (var l = 0; l <= level; l++) {
      final levelUnits = unitsOf(l);
      for (var i = 0; i < levelUnits.length; i++) {
        if (l == level && i > unitIndex) {
          break;
        }
        out.addAll(levelUnits[i].items);
      }
    }
    return out;
  }

  bool get isEmpty => units.isEmpty;
}
