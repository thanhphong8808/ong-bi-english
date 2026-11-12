// test/lesson_composer_test.dart
//
// Runs the LessonComposer and the TestBuilder over every unit of the real
// curriculum, in every phase and device situation, and checks that each
// generated step can actually be shown to the child.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ong_bi_english/core/config/app_config.dart';
import 'package:ong_bi_english/core/db/repositories.dart';
import 'package:ong_bi_english/curriculum/letter_strokes.dart';
import 'package:ong_bi_english/curriculum/lesson_composer.dart';
import 'package:ong_bi_english/curriculum/lesson_stages.dart';
import 'package:ong_bi_english/curriculum/lesson_plan.dart';
import 'package:ong_bi_english/curriculum/models.dart';
import 'package:ong_bi_english/curriculum/progress_snapshot.dart';
import 'package:ong_bi_english/curriculum/test_builder.dart';

import 'support/curriculum_fixture.dart';

final DateTime now = DateTime(2026, 5, 4, 18);

/// Every unit before [unit] in its level passed; nothing of [unit] done yet.
ProgressSnapshot snapshotAt(
  Curriculum c,
  Unit unit, {
  bool introduceAll = false,
  bool reviewDone = false,
  DateTime? lastTestAt,
  bool remedial = false,
  int lessonsDone = 0,
  List<String> wrong = const [],
}) {
  final units = <UnitProgress>[
    for (final u in c.unitsOf(unit.level))
      if (u.id.compareTo(unit.id) < 0) UnitProgress(unitId: u.id, passed: true, reviewDone: true),
    UnitProgress(
      unitId: unit.id,
      reviewDone: reviewDone,
      lastTestAt: lastTestAt,
      remedialPending: remedial,
      lessonsDone: lessonsDone,
    ),
  ];
  final rows = <ItemProgressRow>[
    for (final u in c.unitsOf(unit.level))
      if (u.id.compareTo(unit.id) < 0 || (u.id == unit.id && introduceAll))
        for (final item in u.items)
          for (final skill in const ['listen', 'speak', 'read', 'write'])
            ItemProgressRow(
              itemId: item.id,
              unitId: u.id,
              skill: skill,
              box: (item.id.hashCode % 5) + 1,
              dueAt: now.subtract(Duration(days: item.id.hashCode % 3)),
              correctCount: 2,
              wrongCount: item.id.hashCode % 2,
              lastSeenAt: now.subtract(const Duration(days: 2)),
            ),
  ];
  return ProgressSnapshot(
    rows: rows,
    units: units,
    dialogueStages: const {},
    recentAttempts: const [],
    lastUnitTestWrong: wrong,
  );
}

const Set<Type> readingSteps = {PickWordStep, TrueFalseStep, FillBlankStep, ReadingStep, CopyWordStep};

/// Returns a list of problems found in [plan] (empty when the plan is valid).
List<String> problems(Curriculum c, LessonPlan plan, ComposerOptions o) {
  final out = <String>[];
  void bad(LessonStep s, String why) => out.add('${plan.unitId} ${plan.kind.name} ${s.runtimeType}: $why');

  Item? item(String id) => id.isEmpty ? null : c.item(id);

  void checkOptions(LessonStep s, String target, List<String> ids, {bool pictures = false}) {
    if (ids.length < 2) {
      bad(s, 'only ${ids.length} option(s)');
    }
    if (ids.toSet().length != ids.length) {
      bad(s, 'duplicate options $ids');
    }
    if (!ids.contains(target)) {
      bad(s, 'target $target not among options');
    }
    for (final id in ids) {
      final it = item(id);
      if (it == null) {
        bad(s, 'unknown option $id');
      } else if (pictures && !it.picturable) {
        bad(s, 'option ${it.en} has no picture');
      }
    }
    final words = [for (final id in ids) item(id)?.en.toLowerCase()];
    if (words.toSet().length != words.length) {
      bad(s, 'two options show the same word $words');
    }
  }

  for (final s in plan.steps) {
    if (s.itemId.isNotEmpty && item(s.itemId) == null) {
      bad(s, 'unknown item ${s.itemId}');
    }
    if (o.delayReading && readingSteps.contains(s.runtimeType)) {
      bad(s, 'needs reading English while reading is delayed');
    }
    switch (s) {
      case PickImageStep():
        checkOptions(s, s.itemId, s.optionIds, pictures: true);
      case BubbleStep():
        checkOptions(s, s.itemId, s.optionIds, pictures: true);
      case ColorStep():
        checkOptions(s, s.itemId, s.optionIds, pictures: true);
      case PickWordStep():
        checkOptions(s, s.itemId, s.optionIds);
      case PickMeaningStep():
        checkOptions(s, s.itemId, s.optionIds);
        final meanings = [for (final id in s.optionIds) item(id)?.vi];
        if (meanings.toSet().length != meanings.length) {
          bad(s, 'two options have the same meaning $meanings');
        }
      case MatchPairsStep():
        if (s.itemIds.length < 2 || s.itemIds.any((id) => !(item(id)?.picturable ?? false))) {
          bad(s, 'match pairs needs pictured items');
        }
      case FillBlankStep():
        if (!s.options.contains(s.answer) || s.options.length < 2) {
          bad(s, 'answer ${s.answer} not in ${s.options}');
        }
      case ReadingStep():
        final r = c.reading(s.readingId);
        if (r == null) {
          bad(s, 'unknown reading ${s.readingId}');
        }
        if (!s.options.contains(s.answer) || s.options.length < 2) {
          bad(s, 'answer not among options');
        }
      case DialogueStep():
        if (c.units.expand((u) => u.dialogues).every((d) => d.id != s.dialogueId)) {
          bad(s, 'unknown dialogue ${s.dialogueId}');
        }
      case TraceStep():
        if (LetterStrokes.of(s.letter) == null) {
          bad(s, 'no stroke template for "${s.letter}"');
        }
      case WriteLetterStep():
        if (!o.inkAvailable) {
          bad(s, 'handwriting step without the ink model');
        }
        if (LetterStrokes.of(s.letter) == null) {
          bad(s, 'no stroke template for "${s.letter}"');
        }
      case CopyWordStep():
        if (!o.inkAvailable) {
          bad(s, 'handwriting step without the ink model');
        }
      case DictationStep():
        if (!o.inkAvailable && !s.allowKeyboard) {
          bad(s, 'dictation without ink model or keyboard');
        }
        if (s.text.trim().isEmpty) {
          bad(s, 'empty dictation');
        }
      case WriteSentencesStep():
        if (!o.inkAvailable && !s.allowKeyboard) {
          bad(s, 'free writing without ink model or keyboard');
        }
      case SayStep():
        if (s.text.trim().isEmpty) {
          bad(s, 'nothing to say');
        }
        if (plan.isTest && !o.speechAvailable) {
          bad(s, 'speaking question in a test without speech recognition');
        }
      case AnswerStep():
        if (plan.isTest && !o.speechAvailable) {
          bad(s, 'speaking question in a test without speech recognition');
        }
      case LetterSoundStep():
        final it = item(s.itemId);
        if (it == null || !s.optionLetters.map((l) => l.toLowerCase()).contains(it.letter.toLowerCase())) {
          bad(s, 'letter not among options');
        }
      case WordBuilderStep():
        if (s.word.trim().isEmpty) {
          bad(s, 'empty word');
        }
      case TrueFalseStep():
        if (s.text.trim().isEmpty) {
          bad(s, 'empty sentence');
        }
      case PresentItemStep() || PhonicsStep() || PronDrillStep():
        break;
    }
  }
  return out;
}

const List<ComposerOptions Function()> situations = [_full, _noSpeech, _noInk, _delayReading, _bare];
ComposerOptions _full() => ComposerOptions(now: now);
ComposerOptions _noSpeech() => ComposerOptions(now: now, speechAvailable: false);
ComposerOptions _noInk() => ComposerOptions(now: now, inkAvailable: false);
ComposerOptions _delayReading() => ComposerOptions(now: now, delayReading: true);
ComposerOptions _bare() => ComposerOptions(now: now, speechAvailable: false, inkAvailable: false);

void main() {
  final c = loadCurriculum();
  final composer = LessonComposer(curriculum: c);

  group('parent word lists', () {
    Item parentWord(int id, String en, String vi, String emoji) => Item(
          id: 'P-$id',
          unitId: Curriculum.parentUnitId,
          level: 0,
          type: en.contains(' ') ? ItemType.phrase : ItemType.word,
          en: en,
          vi: vi,
          image: ItemImage.fromEmoji(emoji),
          exampleEn: '',
          exampleVi: '',
          skills: const ['listen', 'speak', 'read', 'write'],
          picturable: emoji.isNotEmpty,
        );

    tearDown(() => c.setParentItems(const []));

    test('parent words resolve by id and can be replaced', () {
      c.setParentItems([parentWord(1, 'pencil case', 'hộp bút', '✏️')]);
      expect(c.item('P-1')?.en, 'pencil case');
      expect(c.item('P-1')?.image.emoji, '✏️');
      c.setParentItems([parentWord(2, 'ruler', 'thước kẻ', '')]);
      expect(c.item('P-1'), isNull);
      expect(c.item('P-2')?.picturable, isFalse);
      c.setParentItems(const []);
      expect(c.parentItems, isEmpty);
    });

    test('two new parent words join the first stage of a daily lesson, and the lesson stays valid', () {
      c.setParentItems([
        parentWord(1, 'pencil case', 'hộp bút', '✏️'),
        parentWord(2, 'teacher', 'cô giáo', '🧑‍🏫'),
        parentWord(3, 'ruler', 'thước kẻ', ''),
      ]);
      for (final level in [0, 2, 4]) {
        final unit = c.unitsOf(level)[1];
        final o = ComposerOptions(now: now);
        final plan = composer.compose(level: level, snapshot: snapshotAt(c, unit), options: o, random: Random(3));
        final presented = [for (final s in plan.steps) if (s is PresentItemStep && s.itemId.startsWith('P-')) s.itemId];
        expect(presented, ['P-1', 'P-2'], reason: 'level $level');
        final ends = stageEnds(plan);
        for (var i = 0; i < plan.steps.length; i++) {
          final step = plan.steps[i];
          if (step is PresentItemStep && step.itemId.startsWith('P-')) {
            expect(stageOf(ends, i), 0, reason: 'level $level: ${step.itemId} at $i, stages $ends');
          }
        }
        expect(plan.newItemIds, containsAll(['P-1', 'P-2']));
        expect(problems(c, plan, o), isEmpty, reason: 'level $level');
      }
    });

    test('met parent words come back in review instead of being taught again', () {
      c.setParentItems([parentWord(1, 'pencil case', 'hộp bút', '✏️')]);
      final unit = c.unitsOf(1)[2];
      final base = snapshotAt(c, unit);
      final snapshot = ProgressSnapshot(
        rows: [
          ...base.allRows,
          ItemProgressRow(
            itemId: 'P-1',
            unitId: Curriculum.parentUnitId,
            skill: 'listen',
            box: 1,
            dueAt: now.subtract(const Duration(days: 1)),
            correctCount: 0,
            wrongCount: 0,
            lastSeenAt: now.subtract(const Duration(days: 2)),
          ),
        ],
        units: base.units.values.toList(),
        dialogueStages: const {},
        recentAttempts: const [],
      );
      final o = ComposerOptions(now: now);
      final plan = composer.compose(level: 1, snapshot: snapshot, options: o, random: Random(5));
      expect(plan.steps.whereType<PresentItemStep>().any((s) => s.itemId == 'P-1'), isFalse);
      expect(problems(c, plan, o), isEmpty);
    });
  });

  test('the curriculum has six levels with the planned number of units', () {
    expect([for (var l = 0; l < 6; l++) c.unitsOf(l).length], [10, 15, 13, 14, 12, 16]);
  });

  test('a brand-new child starts with new words of the first unit', () {
    final plan = composer.compose(
      level: 0,
      snapshot: ProgressSnapshot.empty(),
      options: ComposerOptions(now: now),
      random: Random(1),
    );
    expect(plan.kind, LessonKind.newContent);
    expect(plan.unitId, c.unitsOf(0).first.id);
    expect(plan.newItemIds, isNotEmpty);
    expect(plan.newItemIds.length, lessThanOrEqualTo(AppConfig.lessonMix[0][2]));
    expect(problems(c, plan, ComposerOptions(now: now)), isEmpty);
  });

  test('the same seed gives the same lesson', () {
    final unit = c.unitsOf(2)[3];
    LessonPlan make() => composer.compose(
          level: 2,
          snapshot: snapshotAt(c, unit),
          options: ComposerOptions(now: now),
          random: Random(7),
        );
    expect(make().steps.map((s) => '${s.runtimeType}${s.itemId}').toList(),
        make().steps.map((s) => '${s.runtimeType}${s.itemId}').toList());
  });

  test('phases follow the unit state', () {
    final unit = c.unitsOf(1)[2];
    expect(composer.phaseOf(unit, snapshotAt(c, unit), now), UnitPhase.learning);
    expect(composer.phaseOf(unit, snapshotAt(c, unit, introduceAll: true), now), UnitPhase.review);
    expect(composer.phaseOf(unit, snapshotAt(c, unit, introduceAll: true, reviewDone: true), now), UnitPhase.test);
    expect(
      composer.phaseOf(unit, snapshotAt(c, unit, introduceAll: true, reviewDone: true, lastTestAt: now), now),
      UnitPhase.waitRetake,
    );
    expect(
      composer.phaseOf(
        unit,
        snapshotAt(c, unit, introduceAll: true, reviewDone: true, lastTestAt: now.subtract(const Duration(days: 1))),
        now,
      ),
      UnitPhase.test,
    );
    expect(composer.phaseOf(unit, snapshotAt(c, unit, introduceAll: true, remedial: true), now), UnitPhase.remedial);
  });

  test('every unit gives valid lessons in every phase and situation', () {
    final all = <String>[];
    var plans = 0;
    for (final unit in c.units) {
      final states = <ProgressSnapshot>[
        snapshotAt(c, unit),
        snapshotAt(c, unit, lessonsDone: 2),
        snapshotAt(c, unit, introduceAll: true),
        snapshotAt(c, unit, introduceAll: true, reviewDone: true),
        snapshotAt(c, unit, introduceAll: true, reviewDone: true, lastTestAt: now),
        snapshotAt(c, unit, introduceAll: true, remedial: true, wrong: [unit.items.first.id, unit.items.last.id]),
      ];
      for (final snapshot in states) {
        for (final make in situations) {
          final o = make();
          for (final seed in const [1, 2]) {
            final plan = composer.compose(level: unit.level, snapshot: snapshot, options: o, random: Random(seed));
            plans++;
            expect(plan.unitId, unit.id);
            if (plan.steps.isEmpty) {
              all.add('${unit.id} ${plan.kind.name}: empty plan (speech=${o.speechAvailable} ink=${o.inkAvailable} '
                  'delay=${o.delayReading})');
            }
            all.addAll(problems(c, plan, o));
          }
        }
      }
    }
    expect(plans, greaterThan(4000));
    expect(all.take(30).toList(), isEmpty, reason: '${all.length} problem(s)');
  });

  test('unit tests are long enough and use only questions of their unit', () {
    final builder = TestBuilder(c);
    final issues = <String>[];
    for (final unit in c.units) {
      for (final make in situations) {
        final o = make();
        final plan = builder.unitTest(unit, options: o, random: Random(3));
        expect(plan.kind, LessonKind.unitTest);
        if (plan.steps.length < 8) {
          issues.add('${unit.id}: only ${plan.steps.length} test steps (speech=${o.speechAvailable} '
              'ink=${o.inkAvailable} delay=${o.delayReading})');
        }
        for (final s in plan.steps) {
          if (!s.questionId.startsWith(unit.id)) {
            issues.add('${unit.id}: foreign question ${s.questionId}');
          }
        }
        issues.addAll(problems(c, plan, o));
      }
    }
    expect(issues.take(30).toList(), isEmpty, reason: '${issues.length} issue(s)');
  });

  test('level tests cover several sections in every situation', () {
    final builder = TestBuilder(c);
    final issues = <String>[];
    for (var level = 0; level < 6; level++) {
      for (final make in situations) {
        final o = make();
        final plan = builder.levelTest(level, options: o, random: Random(5));
        expect(plan.kind, LessonKind.levelTest);
        final skills = plan.steps.map((s) => s.skill).toSet();
        if (plan.steps.length < 12) {
          issues.add('L$level: only ${plan.steps.length} steps');
        }
        if (!skills.contains('listen')) {
          issues.add('L$level: no listening section');
        }
        if (o.speechAvailable && !skills.contains('speak')) {
          issues.add('L$level: no speaking section');
        }
        issues.addAll(problems(c, plan, o));
      }
    }
    expect(issues, isEmpty);
  });

  test('the level test opens only after the last unit and after the review wait', () {
    final level = 1;
    final passedAll = ProgressSnapshot(
      rows: const [],
      units: [for (final u in c.unitsOf(level)) UnitProgress(unitId: u.id, passed: true, reviewDone: true)],
      dialogueStages: const {},
      recentAttempts: const [],
    );
    expect(composer.levelTestOpen(level, passedAll, now), isTrue);
    final plan = composer.compose(level: level, snapshot: passedAll, options: ComposerOptions(now: now), random: Random(1));
    expect(plan.kind, LessonKind.levelTest);

    final waiting = ProgressSnapshot(
      rows: const [],
      units: [for (final u in c.unitsOf(level)) UnitProgress(unitId: u.id, passed: true, reviewDone: true)],
      dialogueStages: const {},
      recentAttempts: const [],
      levelReviewUntil: now.add(const Duration(days: 2)),
    );
    expect(composer.levelTestOpen(level, waiting, now), isFalse);
    final review = composer.compose(level: level, snapshot: waiting, options: ComposerOptions(now: now), random: Random(1));
    expect(review.kind, LessonKind.levelReview);
    expect(review.steps, isNotEmpty);
    expect(problems(c, review, ComposerOptions(now: now)), isEmpty);
  });

  test('the placement test mixes level 0 and level 1 questions', () {
    final plan = TestBuilder(c).placement(options: ComposerOptions(now: now), random: Random(2));
    expect(plan.kind, LessonKind.placement);
    expect(plan.steps.any((s) => s.questionId.startsWith('PLACE-L0-')), isTrue);
    expect(plan.steps.any((s) => s.questionId.startsWith('PLACE-L1-')), isTrue);
    expect(plan.steps.length, 2 * AppConfig.placementPerLevel);
    expect(problems(c, plan, ComposerOptions(now: now)), isEmpty);
  });
}
