// lib/curriculum/test_builder.dart
//
// Builds unit tests, level tests and the placement test from the question
// banks. Pure Dart; grading lives in scorers/test_grader.dart.
import 'dart:math';

import '../core/config/app_config.dart';
import 'lesson_composer.dart';
import 'lesson_plan.dart';
import 'models.dart';

class BlankedSentence {
  const BlankedSentence(this.text, this.answer);

  final String text;
  final String answer;
}

class TestBuilder {
  TestBuilder(this.curriculum);

  final Curriculum curriculum;

  /// Replaces [word] (or its plural / -ing / -ed form) in [sentence] with ___.
  static BlankedSentence? blankOut(String sentence, String word) {
    if (word.isEmpty || word.contains(' ')) {
      return null;
    }
    final pattern = RegExp(
      '\\b(${RegExp.escape(word)}(?:s|es|ed|d|ing)?)\\b',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(sentence);
    if (match == null) {
      return null;
    }
    final answer = match.group(1)!;
    return BlankedSentence(sentence.replaceRange(match.start, match.end, '___'), answer);
  }

  Item? _itemFor(String word, Unit unit) {
    for (final item in unit.items) {
      if (item.en.toLowerCase() == word.toLowerCase()) {
        return item;
      }
    }
    return curriculum.itemByWord(word);
  }

  List<String> _ids(List<String> words, Unit unit) => [
        for (final w in words)
          if (_itemFor(w, unit) case final item?) item.id,
      ];

  /// Converts one bank question into a lesson step, adapting to what the
  /// device and settings allow. Returns null when the question cannot be
  /// asked in this situation.
  LessonStep? stepFor(QuizQuestion q, Unit unit, ComposerOptions o) {
    final item = _itemFor(q.item.isNotEmpty ? q.item : q.answer, unit);
    final itemId = item?.id ?? '';
    final readingOk = !o.delayReading;
    final freeWriting = o.inkAvailable || unit.level >= AppConfig.typingAllowedFromLevel;
    switch (q.kind) {
      case QuizKind.pickImage:
        final ids = _ids(q.options, unit);
        if (item == null || ids.length < 2 || !ids.contains(item.id)) {
          return null;
        }
        return PickImageStep(stage: LessonStage.test, itemId: item.id, optionIds: ids, questionId: q.id);
      case QuizKind.pickWord:
        final ids = _ids(q.options, unit);
        if (!readingOk || item == null || ids.length < 2 || !ids.contains(item.id)) {
          return null;
        }
        return PickWordStep(stage: LessonStage.test, itemId: item.id, optionIds: ids, questionId: q.id);
      case QuizKind.pickMeaning:
        final ids = _ids(q.options, unit);
        if (item == null || ids.length < 2 || !ids.contains(item.id)) {
          return null;
        }
        return PickMeaningStep(stage: LessonStage.test, itemId: item.id, optionIds: ids, questionId: q.id);
      case QuizKind.sayWord:
        if (!o.speechAvailable || item == null) {
          return null;
        }
        return SayStep(
          stage: LessonStage.test,
          itemId: item.id,
          text: q.answer,
          alternatives: q.accept,
          modelFirst: false,
          questionId: q.id,
        );
      case QuizKind.repeatSentence:
        if (!o.speechAvailable) {
          return null;
        }
        return SayStep(
          stage: LessonStage.test,
          text: q.audioEn.isNotEmpty ? q.audioEn : q.answer,
          showPicture: false,
          questionId: q.id,
        );
      case QuizKind.answerQuestion:
        if (!o.speechAvailable) {
          return null;
        }
        return AnswerStep(
          stage: LessonStage.test,
          questionEn: q.audioEn,
          accept: [q.answer, ...q.accept],
          pictureItemId: itemId,
          questionId: q.id,
        );
      case QuizKind.trueFalse:
        if (!readingOk || q.textEn.isEmpty) {
          return null;
        }
        return TrueFalseStep(
          stage: LessonStage.test,
          text: q.textEn,
          pictureItemId: itemId,
          isTrue: q.answer == 'true',
          questionId: q.id,
        );
      case QuizKind.fillBlank:
        if (!readingOk || q.options.length < 2) {
          return null;
        }
        return FillBlankStep(
          stage: LessonStage.test,
          text: q.textEn,
          answer: q.answer,
          options: q.options,
          pictureItemId: item != null && item.picturable ? item.id : '',
          itemId: itemId,
          questionId: q.id,
        );
      case QuizKind.colorItem:
        final ids = _ids(q.options, unit);
        if (item == null || ids.length < 2 || q.color.isEmpty) {
          return null;
        }
        return ColorStep(
          stage: LessonStage.test,
          itemId: item.id,
          color: q.color,
          optionIds: ids,
          questionId: q.id,
        );
      case QuizKind.traceLetter:
        return TraceStep(stage: LessonStage.test, letter: q.answer, questionId: q.id);
      case QuizKind.writeLetter:
        return o.inkAvailable
            ? WriteLetterStep(stage: LessonStage.test, letter: q.answer, questionId: q.id)
            : TraceStep(stage: LessonStage.test, letter: q.answer, questionId: q.id);
      case QuizKind.copyWord:
        if (!readingOk) {
          return null;
        }
        if (o.inkAvailable) {
          return CopyWordStep(stage: LessonStage.test, word: q.answer, itemId: itemId, questionId: q.id);
        }
        return item != null && item.picturable
            ? WordBuilderStep(
                stage: LessonStage.test,
                itemId: item.id,
                word: q.answer,
                speakWord: false,
                questionId: q.id,
              )
            : null;
      case QuizKind.dictateWord:
        if (freeWriting) {
          return DictationStep(
            stage: LessonStage.test,
            text: q.answer,
            sentence: false,
            allowKeyboard: unit.level >= AppConfig.typingAllowedFromLevel,
            itemId: itemId,
            questionId: q.id,
          );
        }
        return q.answer.contains(' ')
            ? null
            : WordBuilderStep(stage: LessonStage.test, itemId: itemId, word: q.answer, questionId: q.id);
      case QuizKind.dictateSentence:
        if (!freeWriting) {
          return null;
        }
        return DictationStep(
          stage: LessonStage.test,
          text: q.answer,
          sentence: true,
          allowKeyboard: unit.level >= AppConfig.typingAllowedFromLevel,
          questionId: q.id,
        );
      case QuizKind.readQuestion:
        if (!readingOk || q.reading.isEmpty || curriculum.reading(q.reading) == null || q.options.length < 2) {
          return null;
        }
        return ReadingStep(
          stage: LessonStage.test,
          readingId: q.reading,
          question: q.textEn,
          options: q.options,
          answer: q.answer,
          questionId: q.id,
        );
      case QuizKind.letterSound:
        if (!readingOk || item == null || q.options.length < 2) {
          return null;
        }
        return LetterSoundStep(
          stage: LessonStage.test,
          itemId: item.id,
          optionLetters: q.options,
          questionId: q.id,
        );
    }
  }

  /// Picks up to [count] steps for [skill] from [bank], in random order.
  List<LessonStep> _pick(
    List<QuizQuestion> bank,
    String skill,
    int count,
    Unit Function(QuizQuestion q) unitOf,
    ComposerOptions o,
    Random random,
    Set<String> usedItems,
  ) {
    final candidates = bank.where((q) => q.skill == skill).toList()..shuffle(random);
    final out = <LessonStep>[];
    for (final q in candidates) {
      if (out.length >= count) {
        break;
      }
      final step = stepFor(q, unitOf(q), o);
      if (step == null) {
        continue;
      }
      // Avoid testing the same item twice in one test when possible.
      if (step.itemId.isNotEmpty && !usedItems.add('${step.itemId}/$skill')) {
        continue;
      }
      out.add(step);
    }
    return out;
  }

  /// 8-12 mixed questions: listening, speaking, writing (+ reading).
  LessonPlan unitTest(Unit unit, {required ComposerOptions options, required Random random}) {
    final used = <String>{};
    Unit unitOf(QuizQuestion _) => unit;
    final readingOk = !options.delayReading && unit.level >= 1;
    final steps = <LessonStep>[
      ..._pick(unit.quizBank, 'listen', readingOk ? 4 : 5, unitOf, options, random, used),
      ..._pick(unit.quizBank, 'speak', 3, unitOf, options, random, used),
      if (readingOk) ..._pick(unit.quizBank, 'read', 2, unitOf, options, random, used),
      ..._pick(unit.quizBank, 'write', 2, unitOf, options, random, used),
    ];
    // Top up with listening questions to reach the minimum length.
    if (steps.length < AppConfig.unitTestMinQuestions) {
      steps.addAll(_pick(
        unit.quizBank,
        'listen',
        AppConfig.unitTestMinQuestions - steps.length,
        unitOf,
        options,
        random,
        used,
      ));
    }
    steps.shuffle(random);
    return LessonPlan(
      kind: LessonKind.unitTest,
      unitId: unit.id,
      level: unit.level,
      steps: steps.take(AppConfig.unitTestMaxQuestions).toList(),
    );
  }

  /// Four sections in Cambridge Young Learners style, with original content.
  LessonPlan levelTest(int level, {required ComposerOptions options, required Random random}) {
    final units = curriculum.unitsOf(level);
    final bank = units.expand((u) => u.quizBank).toList();
    final byId = {for (final u in units) u.id: u};
    Unit unitOf(QuizQuestion q) => byId[q.unitId] ?? units.first;
    final used = <String>{};
    final listening = _pick(bank, 'listen', AppConfig.levelTestPerSection, unitOf, options, random, used);
    final reading = options.delayReading && level <= 1
        ? <LessonStep>[]
        : _pick(bank, 'read', AppConfig.levelTestPerSection, unitOf, options, random, used);
    final speaking = options.speechAvailable ? _examiner(level, units, random) : <LessonStep>[];
    final writing = _pick(bank, 'write', AppConfig.levelTestWritingQuestions, unitOf, options, random, used);
    return LessonPlan(
      kind: LessonKind.levelTest,
      unitId: 'L$level',
      level: level,
      steps: [...listening, ...reading, ...speaking, ...writing],
    );
  }

  /// Bi as the examiner: name, age, describe pictures, simple questions.
  List<LessonStep> _examiner(int level, List<Unit> units, Random random) {
    final steps = <LessonStep>[
      const AnswerStep(
        stage: LessonStage.test,
        questionEn: "What's your name?",
        accept: ['my name is'],
        anyAnswer: true,
        questionId: 'EXAM-NAME',
      ),
      AnswerStep(
        stage: LessonStage.test,
        questionEn: 'How old are you?',
        accept: [
          for (var age = 5; age <= 12; age++) ...["I'm $age", '$age', "I'm $age years old"],
        ],
        questionId: 'EXAM-AGE',
      ),
    ];
    final pictures = units
        .expand((u) => u.items)
        .where((i) => i.picturable && !i.isLetter && i.type == ItemType.word)
        .toList()
      ..shuffle(random);
    for (final item in pictures.take(2)) {
      steps.add(AnswerStep(
        stage: LessonStage.test,
        questionEn: level <= 1 ? "What's this?" : 'Look at the picture. What can you see?',
        accept: [item.en, 'a ${item.en}', 'an ${item.en}', "it's a ${item.en}", 'I can see a ${item.en}'],
        pictureItemId: item.id,
        questionId: 'EXAM-PIC-${item.id}',
      ));
    }
    final questions = units
        .expand((u) => u.quizBank)
        .where((q) => q.kind == QuizKind.answerQuestion)
        .toList()
      ..shuffle(random);
    for (final q in questions.take(1)) {
      steps.add(AnswerStep(
        stage: LessonStage.test,
        questionEn: q.audioEn,
        accept: [q.answer, ...q.accept],
        questionId: q.id,
      ));
    }
    return steps;
  }

  /// About 5 minutes, voice and pictures only. Questions marked with the
  /// level they probe through their unit id (L0 / L1).
  LessonPlan placement({required ComposerOptions options, required Random random}) {
    final steps = <LessonStep>[];
    for (final level in [0, 1]) {
      final units = curriculum.unitsOf(level).take(4).toList();
      if (units.isEmpty) {
        continue;
      }
      final pool = units
          .expand((u) => u.items)
          .where((i) => i.picturable && !i.isLetter && i.type == ItemType.word)
          .toList()
        ..shuffle(random);
      for (final item in pool.take(AppConfig.placementPerLevel)) {
        final others = pool.where((i) => i.en != item.en).toList()..shuffle(random);
        final options = [item, ...others.take(level == 0 ? 2 : 3)]..shuffle(random);
        steps.add(PickImageStep(
          stage: LessonStage.test,
          itemId: item.id,
          optionIds: [for (final i in options) i.id],
          questionId: 'PLACE-L$level-${item.id}',
        ));
      }
    }
    return LessonPlan(kind: LessonKind.placement, unitId: 'PLACEMENT', level: 0, steps: steps);
  }
}
