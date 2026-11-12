// lib/curriculum/lesson_plan.dart
//
// A lesson is an ordered list of steps. Every step maps to one activity
// screen. Pure Dart.

enum LessonKind {
  newContent,
  unitReview,
  unitTest,
  remedial,
  practice,
  levelTest,
  levelReview,
  placement,
}

enum LessonStage { warmUp, review, learnNew, speak, write, read, dialogue, test }

/// Base class of all steps.
sealed class LessonStep {
  const LessonStep({required this.stage, this.itemId = '', this.skill = '', this.questionId = ''});

  final LessonStage stage;

  /// Item whose progress this step updates; empty for steps without one.
  final String itemId;

  /// listen | speak | read | write | '' (no progress update)
  final String skill;

  /// Quiz-bank id when the step comes from a test.
  final String questionId;
}

/// Hear a word, tap its picture.
class PickImageStep extends LessonStep {
  const PickImageStep({
    required super.stage,
    required super.itemId,
    required this.optionIds,
    super.questionId,
  }) : super(skill: 'listen');

  final List<String> optionIds;
}

/// Hear a word, tap its Vietnamese meaning (abstract words, level 3 up).
class PickMeaningStep extends LessonStep {
  const PickMeaningStep({
    required super.stage,
    required super.itemId,
    required this.optionIds,
    super.questionId,
  }) : super(skill: 'listen');

  final List<String> optionIds;
}

/// See, hear and repeat a new item, with its Vietnamese meaning.
class PresentItemStep extends LessonStep {
  const PresentItemStep({required super.itemId}) : super(stage: LessonStage.learnNew, skill: 'speak');
}

/// Letter-sound lesson (level 0 phonics).
class PhonicsStep extends LessonStep {
  const PhonicsStep({required super.itemId}) : super(stage: LessonStage.learnNew, skill: 'listen');
}

/// Say a word from its picture, or repeat a sentence (shadowing).
class SayStep extends LessonStep {
  const SayStep({
    required super.stage,
    required this.text,
    super.itemId,
    this.alternatives = const [],
    this.showPicture = true,
    this.modelFirst = true,
    super.questionId,
  }) : super(skill: 'speak');

  final String text;
  final List<String> alternatives;

  /// Show the item's picture as the prompt.
  final bool showPicture;

  /// Play the model sentence before the child speaks (shadowing). When false
  /// the child answers from the picture alone (review and tests).
  final bool modelFirst;
}

/// Bi asks a question; any of the accepted answers counts (speaking test).
class AnswerStep extends LessonStep {
  const AnswerStep({
    required super.stage,
    required this.questionEn,
    required this.accept,
    this.pictureItemId = '',
    this.anyAnswer = false,
    super.questionId,
  }) : super(skill: 'speak');

  final String questionEn;
  final List<String> accept;
  final String pictureItemId;

  /// Open questions such as "What's your name?": any clear answer passes.
  final bool anyAnswer;
}

/// See a picture, tap the matching written word.
class PickWordStep extends LessonStep {
  const PickWordStep({
    required super.stage,
    required super.itemId,
    required this.optionIds,
    super.questionId,
  }) : super(skill: 'read');

  final List<String> optionIds;
}

/// Match pictures with sounds.
class MatchPairsStep extends LessonStep {
  const MatchPairsStep({required super.stage, required this.itemIds}) : super(skill: 'listen');

  final List<String> itemIds;
}

/// Pop the bubble with the word you hear.
class BubbleStep extends LessonStep {
  const BubbleStep({required super.stage, required super.itemId, required this.optionIds})
      : super(skill: 'listen');

  final List<String> optionIds;
}

/// "Color the cat red."
class ColorStep extends LessonStep {
  const ColorStep({
    required super.stage,
    required super.itemId,
    required this.color,
    required this.optionIds,
    super.questionId,
  }) : super(skill: 'listen');

  final String color;
  final List<String> optionIds;
}

/// Build the word of the picture from letter tiles.
class WordBuilderStep extends LessonStep {
  const WordBuilderStep({
    required super.stage,
    required super.itemId,
    required this.word,
    this.speakWord = true,
    super.questionId,
  }) : super(skill: 'write');

  final String word;

  /// Dictation mode plays the word; picture mode only shows it.
  final bool speakWord;
}

/// Read a sentence, decide true or false for the picture.
class TrueFalseStep extends LessonStep {
  const TrueFalseStep({
    required super.stage,
    required this.text,
    required this.pictureItemId,
    required this.isTrue,
    super.itemId,
    super.questionId,
  }) : super(skill: 'read');

  final String text;
  final String pictureItemId;
  final bool isTrue;
}

/// Choose the missing word.
class FillBlankStep extends LessonStep {
  const FillBlankStep({
    required super.stage,
    required this.text,
    required this.answer,
    required this.options,
    this.pictureItemId = '',
    super.itemId,
    super.questionId,
  }) : super(skill: 'read');

  /// Contains "___" where the word goes.
  final String text;
  final String answer;
  final List<String> options;
  final String pictureItemId;
}

/// Hear a letter sound, tap the letter (phonics reading).
class LetterSoundStep extends LessonStep {
  const LetterSoundStep({
    required super.stage,
    required super.itemId,
    required this.optionLetters,
    super.questionId,
  }) : super(skill: 'read');

  final List<String> optionLetters;
}

/// Trace a letter on dotted lines (geometric scoring).
class TraceStep extends LessonStep {
  const TraceStep({required super.stage, required this.letter, super.itemId, super.questionId})
      : super(skill: 'write');

  final String letter;
}

/// Write a letter freely (ML Kit).
class WriteLetterStep extends LessonStep {
  const WriteLetterStep({required super.stage, required this.letter, super.itemId, super.questionId})
      : super(skill: 'write');

  final String letter;
}

/// Copy a word shown on screen (ML Kit).
class CopyWordStep extends LessonStep {
  const CopyWordStep({required super.stage, required this.word, super.itemId, super.questionId})
      : super(skill: 'write');

  final String word;
}

/// Writing test: write a word from its picture and Bi's voice.
class WriteRecallStep extends LessonStep {
  const WriteRecallStep({required super.stage, required super.itemId, required this.word, super.questionId})
      : super(skill: 'write');

  final String word;
}

/// Listen and write a word or sentence.
class DictationStep extends LessonStep {
  const DictationStep({
    required super.stage,
    required this.text,
    required this.sentence,
    required this.allowKeyboard,
    super.itemId,
    super.questionId,
  }) : super(skill: 'write');

  final String text;
  final bool sentence;
  final bool allowKeyboard;
}

/// Guided writing: a few sentences about yourself (level 3 up).
class WriteSentencesStep extends LessonStep {
  const WriteSentencesStep({
    required super.stage,
    required this.promptVi,
    required this.starters,
    required this.minSentences,
    required this.minWords,
    required this.allowKeyboard,
  }) : super(skill: 'write');

  final String promptVi;
  final List<String> starters;
  final int minSentences;
  final int minWords;
  final bool allowKeyboard;
}

/// Read a short text and answer a question about it (level 2 up).
class ReadingStep extends LessonStep {
  const ReadingStep({
    required super.stage,
    required this.readingId,
    required this.question,
    required this.options,
    required this.answer,
    super.questionId,
  }) : super(skill: 'read');

  final String readingId;
  final String question;
  final List<String> options;
  final String answer;
}

/// Pronunciation drill for a typical Vietnamese-learner difficulty.
class PronDrillStep extends LessonStep {
  const PronDrillStep({required this.focus}) : super(stage: LessonStage.speak, skill: '');

  final String focus;
}

/// Dialogue learning: 1 listen, 2 shadow, 3 role-play, 4 variation.
class DialogueStep extends LessonStep {
  const DialogueStep({required this.dialogueId, required this.dialogueStage})
      : super(stage: LessonStage.dialogue, skill: '');

  final String dialogueId;
  final int dialogueStage;
}

class LessonPlan {
  const LessonPlan({
    required this.kind,
    required this.unitId,
    required this.level,
    required this.steps,
    this.newItemIds = const [],
  });

  final LessonKind kind;

  /// Unit the lesson belongs to; for level tests, "L{n}".
  final String unitId;
  final int level;
  final List<LessonStep> steps;
  final List<String> newItemIds;

  bool get isTest =>
      kind == LessonKind.unitTest || kind == LessonKind.levelTest || kind == LessonKind.placement;

  bool get isEmpty => steps.isEmpty;
}
