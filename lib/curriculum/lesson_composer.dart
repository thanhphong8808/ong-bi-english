// lib/curriculum/lesson_composer.dart
//
// Decides what today's lesson is and assembles its steps. Pure Dart and
// deterministic for a given random seed, so it is unit-tested.
import 'dart:math';

import '../core/config/app_config.dart';
import 'leitner_scheduler.dart';
import 'lesson_plan.dart';
import 'models.dart';
import 'progress_snapshot.dart';
import 'test_builder.dart';

class ComposerOptions {
  const ComposerOptions({
    required this.now,
    this.delayReading = false,
    this.speechAvailable = true,
    this.inkAvailable = true,
  });

  final DateTime now;

  /// Hide written English (grade-1 pupils still learning to read Vietnamese).
  final bool delayReading;

  /// The speech models are installed and the microphone is allowed.
  final bool speechAvailable;

  /// The handwriting recognition model is installed.
  final bool inkAvailable;
}

/// Where the child stands in a unit.
enum UnitPhase { learning, review, test, waitRetake, remedial, done }

class LessonComposer {
  LessonComposer({required this.curriculum, this.scheduler = const LeitnerScheduler()});

  final Curriculum curriculum;
  final LeitnerScheduler scheduler;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  /// The first unit of [level] that is not passed yet, or null when the whole
  /// level is done.
  Unit? currentUnit(int level, ProgressSnapshot snapshot) {
    for (final unit in curriculum.unitsOf(level)) {
      if (!snapshot.unit(unit.id).passed) {
        return unit;
      }
    }
    return null;
  }

  UnitPhase phaseOf(Unit unit, ProgressSnapshot snapshot, DateTime now) {
    final progress = snapshot.unit(unit.id);
    if (progress.passed) {
      return UnitPhase.done;
    }
    if (progress.remedialPending) {
      return UnitPhase.remedial;
    }
    if (unit.items.any((item) => !snapshot.introduced(item.id))) {
      return UnitPhase.learning;
    }
    if (!progress.reviewDone) {
      return UnitPhase.review;
    }
    final last = progress.lastTestAt;
    if (last == null) {
      return UnitPhase.test;
    }
    final retakeDay = LeitnerScheduler.startOfDay(last).add(
      const Duration(days: AppConfig.unitRetakeDelayDays),
    );
    return now.isBefore(retakeDay) ? UnitPhase.waitRetake : UnitPhase.test;
  }

  bool levelTestOpen(int level, ProgressSnapshot snapshot, DateTime now) {
    if (currentUnit(level, snapshot) != null || curriculum.unitsOf(level).isEmpty) {
      return false;
    }
    final until = snapshot.levelReviewUntil;
    return until == null || !now.isBefore(until);
  }

  // ---------------------------------------------------------------------------
  // Entry point
  // ---------------------------------------------------------------------------

  LessonPlan compose({
    required int level,
    required ProgressSnapshot snapshot,
    required ComposerOptions options,
    required Random random,
  }) {
    final plan = _compose(level: level, snapshot: snapshot, options: options, random: random);
    return plan.isTest ? plan : _withParentWords(plan, level, snapshot, options, random);
  }

  /// Up to [AppConfig.parentWordsPerLesson] words from the parents' list
  /// that the child has not met yet, taught right after the warm-up, so they
  /// land in the first stage even when the child rests after it (school
  /// words are often needed soon). Once met, Leitner review brings them back
  /// like any other word.
  LessonPlan _withParentWords(
    LessonPlan plan,
    int level,
    ProgressSnapshot snapshot,
    ComposerOptions o,
    Random random,
  ) {
    final fresh = curriculum.parentItems
        .where((i) => !snapshot.introduced(i.id))
        .take(AppConfig.parentWordsPerLesson)
        .toList();
    if (fresh.isEmpty) {
      return plan;
    }
    final levelUnits = curriculum.unitsOf(level);
    final unit = curriculum.unitById(plan.unitId) ?? (levelUnits.isNotEmpty ? levelUnits.first : null);
    if (unit == null) {
      return plan;
    }
    final ctx = _Ctx(this, unit, snapshot, o, random);
    final block = <LessonStep>[];
    for (final item in fresh) {
      block.add(PresentItemStep(itemId: item.id));
      final check = ctx.listenStep(item, LessonStage.learnNew);
      if (check != null) {
        block.add(check);
      }
    }
    final at = plan.steps.indexWhere((s) => s.stage != LessonStage.warmUp);
    final steps = [...plan.steps]..insertAll(at < 0 ? plan.steps.length : at, block);
    return LessonPlan(
      kind: plan.kind,
      unitId: plan.unitId,
      level: plan.level,
      steps: steps,
      newItemIds: [...plan.newItemIds, for (final i in fresh) i.id],
    );
  }

  LessonPlan _compose({
    required int level,
    required ProgressSnapshot snapshot,
    required ComposerOptions options,
    required Random random,
  }) {
    final unit = currentUnit(level, snapshot);
    if (unit == null) {
      if (curriculum.unitsOf(level).isEmpty) {
        return LessonPlan(kind: LessonKind.practice, unitId: '', level: level, steps: const []);
      }
      if (levelTestOpen(level, snapshot, options.now)) {
        return TestBuilder(curriculum).levelTest(level, options: options, random: random);
      }
      return _levelReview(level, snapshot, options, random);
    }
    switch (phaseOf(unit, snapshot, options.now)) {
      case UnitPhase.learning:
        return _newContent(unit, snapshot, options, random);
      case UnitPhase.review:
        return _unitReview(unit, snapshot, options, random);
      case UnitPhase.test:
        return TestBuilder(curriculum).unitTest(unit, options: options, random: random);
      case UnitPhase.remedial:
        return _remedial(unit, snapshot, options, random);
      case UnitPhase.waitRetake:
      case UnitPhase.done:
        return _practice(unit, snapshot, options, random);
    }
  }

  // ---------------------------------------------------------------------------
  // Lesson kinds
  // ---------------------------------------------------------------------------

  _Mix _mix(int level) {
    final m = AppConfig.lessonMix[level.clamp(0, AppConfig.lessonMix.length - 1)];
    return _Mix(warmUp: m[0], review: m[1], newMax: m[2], speak: m[3], write: m[4], read: m[5]);
  }

  LessonPlan _newContent(Unit unit, ProgressSnapshot snapshot, ComposerOptions o, Random random) {
    final mix = _mix(unit.level);
    final ctx = _Ctx(this, unit, snapshot, o, random);
    final steps = <LessonStep>[];

    steps.addAll(ctx.warmUp(mix.warmUp));
    steps.addAll(ctx.reviewBlock(mix.review));

    final fresh = unit.items.where((i) => !snapshot.introduced(i.id)).take(mix.newMax).toList();
    for (final item in fresh) {
      if (item.isLetter) {
        steps.add(PhonicsStep(itemId: item.id));
      } else {
        steps.add(PresentItemStep(itemId: item.id));
        final pick = ctx.pickImage(item, LessonStage.learnNew, extraPool: fresh);
        if (pick != null) {
          steps.add(pick);
        }
      }
    }
    final pictured = fresh.where((i) => i.picturable && !i.isLetter).toList();
    if (pictured.length >= 3) {
      steps.add(random.nextBool()
          ? MatchPairsStep(stage: LessonStage.learnNew, itemIds: [for (final i in pictured.take(4)) i.id])
          : ctx.bubble(pictured[random.nextInt(pictured.length)], pictured));
    } else if (pictured.isNotEmpty && unit.level <= 1) {
      final color = ctx.colorStep(pictured.first);
      if (color != null) {
        steps.add(color);
      }
    }

    steps.addAll(ctx.speakBlock(fresh, mix.speak));
    steps.addAll(ctx.readBlock(fresh, mix.read));
    final reading = ctx.readingStep(snapshot.unit(unit.id).lessonsDone);
    if (reading != null && snapshot.unit(unit.id).lessonsDone >= 1) {
      steps.add(reading);
    }
    steps.addAll(ctx.writeBlock(fresh, mix.write));
    final dialogue = ctx.dialogueStep(allowStart: snapshot.unit(unit.id).lessonsDone > 0 || fresh.isEmpty);
    if (dialogue != null) {
      steps.add(dialogue);
    }
    return LessonPlan(
      kind: LessonKind.newContent,
      unitId: unit.id,
      level: unit.level,
      steps: steps,
      newItemIds: [for (final i in fresh) i.id],
    );
  }

  LessonPlan _unitReview(Unit unit, ProgressSnapshot snapshot, ComposerOptions o, Random random) {
    final ctx = _Ctx(this, unit, snapshot, o, random);
    final steps = <LessonStep>[];
    final items = [...unit.items]..shuffle(random);
    for (final item in items.where((i) => !i.isLetter).take(8)) {
      final step = ctx.listenStep(item, LessonStage.review);
      if (step != null) {
        steps.add(step);
      }
    }
    for (final letter in unit.items.where((i) => i.isLetter)) {
      steps.add(ctx.letterReview(letter));
    }
    for (final item in items.where((i) => i.picturable && !i.isLetter).take(4)) {
      steps.add(SayStep(
        stage: LessonStage.speak,
        itemId: item.id,
        text: item.en,
        modelFirst: false,
      ));
    }
    for (final pattern in unit.patterns.take(2)) {
      final expansions = pattern.expansions();
      steps.add(SayStep(
        stage: LessonStage.speak,
        text: expansions[random.nextInt(expansions.length)],
        showPicture: false,
      ));
    }
    steps.addAll(ctx.readBlock(items, 2));
    for (var i = 0; i < unit.readings.length; i++) {
      final reading = ctx.readingStep(i);
      if (reading != null) {
        steps.add(reading);
      }
    }
    steps.addAll(ctx.writeBlock(items, 2, review: true));
    for (final dialogue in unit.dialogues.take(2)) {
      final stage = snapshot.dialogueStage(dialogue.id);
      steps.add(DialogueStep(
        dialogueId: dialogue.id,
        dialogueStage: stage >= 3 ? 4 : 3,
      ));
    }
    return LessonPlan(kind: LessonKind.unitReview, unitId: unit.id, level: unit.level, steps: steps);
  }

  LessonPlan _remedial(Unit unit, ProgressSnapshot snapshot, ComposerOptions o, Random random) {
    final ctx = _Ctx(this, unit, snapshot, o, random);
    final wrong = [
      for (final id in snapshot.lastUnitTestWrong)
        if (curriculum.item(id) != null) curriculum.item(id)!,
    ];
    final targets = wrong.isNotEmpty ? wrong : ctx.weakest(unit.items, 6);
    final steps = <LessonStep>[];
    for (final item in targets.take(8)) {
      if (item.isLetter) {
        steps.add(PhonicsStep(itemId: item.id));
        steps.add(TraceStep(stage: LessonStage.write, letter: item.letter.toLowerCase(), itemId: item.id));
        continue;
      }
      steps.add(PresentItemStep(itemId: item.id));
      final listen = ctx.listenStep(item, LessonStage.review);
      if (listen != null) {
        steps.add(listen);
      }
    }
    steps.addAll(ctx.writeBlock(targets, 2, review: true));
    return LessonPlan(kind: LessonKind.remedial, unitId: unit.id, level: unit.level, steps: steps);
  }

  LessonPlan _practice(Unit unit, ProgressSnapshot snapshot, ComposerOptions o, Random random) {
    final mix = _mix(unit.level);
    final ctx = _Ctx(this, unit, snapshot, o, random);
    final steps = <LessonStep>[
      ...ctx.warmUp(mix.warmUp),
      ...ctx.reviewBlock(mix.review + 4),
    ];
    final practise = ctx.weakest(unit.items, 4);
    steps.addAll(ctx.speakBlock(practise, mix.speak));
    steps.addAll(ctx.readBlock(practise, mix.read));
    steps.addAll(ctx.writeBlock(practise, mix.write, review: true));
    final dialogue = ctx.dialogueStep(allowStart: true);
    if (dialogue != null) {
      steps.add(dialogue);
    }
    return LessonPlan(kind: LessonKind.practice, unitId: unit.id, level: unit.level, steps: steps);
  }

  LessonPlan _levelReview(int level, ProgressSnapshot snapshot, ComposerOptions o, Random random) {
    final units = curriculum.unitsOf(level);
    final unit = units.last;
    final ctx = _Ctx(this, unit, snapshot, o, random);
    final all = units.expand((u) => u.items).toList();
    final weak = ctx.weakest(all, 10);
    final steps = <LessonStep>[...ctx.reviewBlock(6)];
    for (final item in weak) {
      final step = item.isLetter ? ctx.letterReview(item) : ctx.listenStep(item, LessonStage.review);
      if (step != null) {
        steps.add(step);
      }
    }
    steps.addAll(ctx.speakBlock(weak, 3));
    steps.addAll(ctx.readBlock(weak, 2));
    steps.addAll(ctx.writeBlock(weak, 2, review: true));
    return LessonPlan(kind: LessonKind.levelReview, unitId: 'L$level', level: level, steps: steps);
  }
}

class _Mix {
  const _Mix({
    required this.warmUp,
    required this.review,
    required this.newMax,
    required this.speak,
    required this.write,
    required this.read,
  });

  final int warmUp;
  final int review;
  final int newMax;
  final int speak;
  final int write;
  final int read;
}

/// Helpers bound to one lesson being composed.
class _Ctx {
  _Ctx(this.composer, this.unit, this.snapshot, this.options, this.random);

  final LessonComposer composer;
  final Unit unit;
  final ProgressSnapshot snapshot;
  final ComposerOptions options;
  final Random random;

  Curriculum get curriculum => composer.curriculum;

  bool get readingAllowed => !options.delayReading && unit.level >= 1;

  bool get canWriteFreely => options.inkAvailable || unit.level >= AppConfig.typingAllowedFromLevel;

  /// Items already met in this level and the levels below.
  late final List<Item> known = [
    for (final u in curriculum.units)
      if (u.level <= unit.level)
        for (final item in u.items)
          if (snapshot.introduced(item.id)) item,
  ];

  List<Item> _picturePool(List<Item> extra) {
    final pool = <String, Item>{};
    for (final item in [...unit.items, ...extra, ...known]) {
      if (item.picturable && !item.isLetter && !item.image.isEmpty) {
        pool[item.en.toLowerCase()] = item;
      }
    }
    return pool.values.toList();
  }

  /// [target] plus up to [count]-1 distractors, preferring the same category.
  List<Item> _options(Item target, List<Item> pool, int count) {
    final others = pool.where((i) => i.en.toLowerCase() != target.en.toLowerCase()).toList()
      ..shuffle(random);
    others.sort((a, b) {
      final sa = a.category == target.category && a.category.isNotEmpty ? 0 : 1;
      final sb = b.category == target.category && b.category.isNotEmpty ? 0 : 1;
      return sa.compareTo(sb);
    });
    final chosen = [target, ...others.take(count - 1)]..shuffle(random);
    return chosen;
  }

  PickImageStep? pickImage(Item item, LessonStage stage, {List<Item> extraPool = const []}) {
    if (!item.picturable || item.isLetter) {
      return null;
    }
    final options = _options(item, _picturePool(extraPool), unit.level == 0 ? 3 : 4);
    if (options.length < 2) {
      return null;
    }
    return PickImageStep(stage: stage, itemId: item.id, optionIds: [for (final i in options) i.id]);
  }

  BubbleStep bubble(Item target, List<Item> pool) {
    final options = _options(target, _picturePool(pool), 5);
    return BubbleStep(
      stage: LessonStage.learnNew,
      itemId: target.id,
      optionIds: [for (final i in options) i.id],
    );
  }

  ColorStep? colorStep(Item target) {
    final options = _options(target, _picturePool(const []), 3);
    if (options.length < 2) {
      return null;
    }
    final color = AppConfig.colorWords[random.nextInt(AppConfig.colorWords.length)];
    return ColorStep(
      stage: LessonStage.learnNew,
      itemId: target.id,
      color: color,
      optionIds: [for (final i in options) i.id],
    );
  }

  /// A listening check for any item: picture when it has one, meaning otherwise.
  LessonStep? listenStep(Item item, LessonStage stage) {
    if (item.isLetter) {
      return letterReview(item);
    }
    final pick = pickImage(item, stage);
    if (pick != null) {
      return pick;
    }
    final pool = [...unit.items, ...known].where((i) => !i.isLetter && i.vi.isNotEmpty).toList();
    final unique = <String, Item>{for (final i in pool) i.vi: i}.values.toList();
    final options = _options(item, unique, 3);
    if (options.length < 2) {
      return null;
    }
    return PickMeaningStep(stage: stage, itemId: item.id, optionIds: [for (final i in options) i.id]);
  }

  LessonStep letterReview(Item letter) {
    if (readingAllowed || (!options.delayReading && unit.level == 0)) {
      final letters = curriculum
          .unitsOf(0)
          .expand((u) => u.items)
          .where((i) => i.isLetter && i.letter != letter.letter)
          .map((i) => i.letter)
          .toList()
        ..shuffle(random);
      final optionLetters = [letter.letter, ...letters.take(2)]..shuffle(random);
      return LetterSoundStep(stage: LessonStage.review, itemId: letter.id, optionLetters: optionLetters);
    }
    return PhonicsStep(itemId: letter.id);
  }

  List<LessonStep> warmUp(int count) {
    final candidates = known.where((i) => i.picturable && !i.isLetter).toList()..shuffle(random);
    return [
      for (final item in candidates.take(count))
        ?pickImage(item, LessonStage.warmUp),
    ];
  }

  /// Due items (Leitner). On Sundays: the weakest items of the past week.
  List<LessonStep> reviewBlock(int count) {
    final now = options.now;
    if (now.weekday == DateTime.sunday) {
      final weekly = _weeklyWeak(count + 2);
      if (weekly.isNotEmpty) {
        return weekly;
      }
    }
    final due = snapshot.allRows
        .where((row) => composer.scheduler.isDue(row, now))
        .where((row) => curriculum.item(row.itemId) != null)
        .toList()
      ..sort((a, b) {
        final byDue = a.dueAt.compareTo(b.dueAt);
        return byDue != 0 ? byDue : a.box.compareTo(b.box);
      });
    final steps = <LessonStep>[];
    final seen = <String>{};
    for (final row in due) {
      if (steps.length >= count) {
        break;
      }
      final item = curriculum.item(row.itemId);
      if (item == null || !seen.add('${row.itemId}/${row.skill}')) {
        continue;
      }
      final step = _stepForSkill(item, row.skill);
      if (step != null) {
        steps.add(step);
      }
    }
    return steps;
  }

  List<LessonStep> _weeklyWeak(int count) {
    final wrong = <String, int>{};
    final total = <String, int>{};
    for (final attempt in snapshot.recentAttempts) {
      total[attempt.itemId] = (total[attempt.itemId] ?? 0) + 1;
      if (!attempt.correct) {
        wrong[attempt.itemId] = (wrong[attempt.itemId] ?? 0) + 1;
      }
    }
    final ids = wrong.keys.toList()
      ..sort((a, b) => (wrong[b]! / total[b]!).compareTo(wrong[a]! / total[a]!));
    final steps = <LessonStep>[];
    for (final id in ids) {
      final item = curriculum.item(id);
      if (item == null) {
        continue;
      }
      final step = listenStep(item, LessonStage.review);
      if (step != null) {
        steps.add(step);
      }
      if (steps.length >= count) {
        break;
      }
    }
    return steps;
  }

  LessonStep? _stepForSkill(Item item, String skill) {
    switch (skill) {
      case 'speak':
        if (!options.speechAvailable) {
          return listenStep(item, LessonStage.review);
        }
        if (item.isLetter) {
          return PhonicsStep(itemId: item.id);
        }
        return SayStep(
          stage: LessonStage.review,
          itemId: item.id,
          text: item.en,
          showPicture: item.picturable,
          modelFirst: !item.picturable,
        );
      case 'write':
        return _writeFor(item, LessonStage.review);
      case 'read':
        if (!readingAllowed) {
          return listenStep(item, LessonStage.review);
        }
        return _readFor(item) ?? listenStep(item, LessonStage.review);
      default:
        return listenStep(item, LessonStage.review);
    }
  }

  List<LessonStep> speakBlock(List<Item> items, int count) {
    final steps = <LessonStep>[];
    final sentences = <String>[
      for (final item in items)
        if (item.exampleEn.isNotEmpty) item.exampleEn,
      for (final pattern in unit.patterns) ...pattern.expansions().take(2),
    ];
    sentences.shuffle(random);
    for (final sentence in sentences.toSet().take(count)) {
      steps.add(SayStep(stage: LessonStage.speak, text: sentence, showPicture: false));
    }
    final focus = items.expand((i) => i.pronFocus).toList();
    if (focus.isNotEmpty) {
      steps.add(PronDrillStep(focus: focus[random.nextInt(focus.length)]));
    }
    return steps;
  }

  List<LessonStep> readBlock(List<Item> items, int count) {
    if (!readingAllowed || count <= 0) {
      return const [];
    }
    final steps = <LessonStep>[];
    final shuffled = [...items]..shuffle(random);
    for (final item in shuffled) {
      if (steps.length >= count) {
        break;
      }
      final step = _readFor(item);
      if (step != null) {
        steps.add(step);
      }
    }
    return steps;
  }

  LessonStep? _readFor(Item item) {
    if (item.isLetter) {
      return letterReview(item);
    }
    final level = unit.level;
    if (level >= 2 && item.exampleEn.isNotEmpty) {
      if (random.nextBool()) {
        final blank = TestBuilder.blankOut(item.exampleEn, item.en);
        if (blank != null) {
          final pool = [...unit.items, ...known]
              .where((i) => !i.isLetter && i.type == item.type && i.en != item.en)
              .map((i) => i.en)
              .toSet()
              .toList()
            ..shuffle(random);
          final options = [blank.answer, ...pool.take(2)]..shuffle(random);
          return FillBlankStep(
            stage: LessonStage.read,
            itemId: item.id,
            text: blank.text,
            answer: blank.answer,
            options: options,
            pictureItemId: item.picturable ? item.id : '',
          );
        }
      } else if (item.picturable) {
        final isTrue = random.nextBool();
        var picture = item;
        if (!isTrue) {
          final others = _options(item, _picturePool(const []), 2).where((i) => i.id != item.id);
          if (others.isEmpty) {
            return null;
          }
          picture = others.first;
        }
        return TrueFalseStep(
          stage: LessonStage.read,
          itemId: item.id,
          text: item.exampleEn,
          pictureItemId: picture.id,
          isTrue: isTrue,
        );
      }
    }
    if (!item.picturable) {
      return null;
    }
    final options = _options(item, _picturePool(const []), 3);
    if (options.length < 2) {
      return null;
    }
    return PickWordStep(stage: LessonStage.read, itemId: item.id, optionIds: [for (final i in options) i.id]);
  }

  LessonStep? _writeFor(Item item, LessonStage stage) {
    final level = unit.level;
    if (item.isLetter) {
      return TraceStep(stage: stage, letter: item.letter.toLowerCase(), itemId: item.id);
    }
    final word = item.en;
    final simple = RegExp(r"^[a-zA-Z' -]+$").hasMatch(word);
    if (!simple) {
      return null;
    }
    if (level <= 1) {
      if (options.delayReading) {
        return null;
      }
      if (options.inkAvailable && word.length <= 6 && !word.contains(' ')) {
        return CopyWordStep(stage: stage, word: word.toLowerCase(), itemId: item.id);
      }
      return item.picturable && word.length <= 7
          ? WordBuilderStep(stage: stage, itemId: item.id, word: word.toLowerCase(), speakWord: false)
          : null;
    }
    if (canWriteFreely) {
      return DictationStep(
        stage: stage,
        itemId: item.id,
        text: word,
        sentence: false,
        allowKeyboard: level >= AppConfig.typingAllowedFromLevel,
      );
    }
    return word.length <= 9 && !word.contains(' ')
        ? WordBuilderStep(stage: stage, itemId: item.id, word: word.toLowerCase())
        : null;
  }

  List<LessonStep> writeBlock(List<Item> items, int count, {bool review = false}) {
    if (count <= 0) {
      return const [];
    }
    final steps = <LessonStep>[];
    final level = unit.level;
    if (level == 0) {
      final letters = <String>[
        for (final item in items)
          if (item.isLetter) ...[item.letter.toUpperCase(), item.letter.toLowerCase()],
      ];
      if (letters.isEmpty) {
        final tasks = unit.writing.where((w) => w.type == 'trace_letter').map((w) => w.target).toList();
        if (tasks.isNotEmpty) {
          final start = snapshot.unit(unit.id).lessonsDone * 2;
          for (var i = 0; i < count + 1; i++) {
            letters.add(tasks[(start + i) % tasks.length]);
          }
        }
      }
      for (final letter in letters.toSet().take(count + 1)) {
        steps.add(TraceStep(stage: LessonStage.write, letter: letter));
      }
      return steps;
    }
    if (level == 1) {
      final tasks = unit.writing.where((w) => w.type == 'trace_letter' || w.type == 'write_letter').toList();
      if (tasks.isNotEmpty) {
        final letter = tasks[random.nextInt(tasks.length)].target;
        steps.add(options.inkAvailable
            ? WriteLetterStep(stage: LessonStage.write, letter: letter)
            : TraceStep(stage: LessonStage.write, letter: letter));
      }
    }
    final shuffled = [...items]..shuffle(random);
    for (final item in shuffled) {
      if (steps.length >= count) {
        break;
      }
      final step = _writeFor(item, LessonStage.write);
      if (step != null) {
        steps.add(step);
      }
    }
    if (level >= 3 && canWriteFreely && steps.length < count + 1) {
      final sentences = [
        for (final item in items)
          if (item.exampleEn.isNotEmpty && item.exampleEn.split(' ').length <= 7) item,
      ];
      if (sentences.isNotEmpty) {
        final item = sentences[random.nextInt(sentences.length)];
        steps.add(DictationStep(
          stage: LessonStage.write,
          itemId: '',
          text: item.exampleEn,
          sentence: true,
          allowKeyboard: level >= AppConfig.typingAllowedFromLevel,
        ));
      }
    }
    if (review && level >= 3 && canWriteFreely) {
      final guided = unit.writing.where((w) => w.type == 'write_sentences').toList();
      if (guided.isNotEmpty) {
        final task = guided.first;
        final starters = task.target.split('|').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        steps.add(WriteSentencesStep(
          stage: LessonStage.write,
          promptVi: unit.topicVi,
          starters: starters,
          minSentences: level >= 5 ? 5 : 3,
          minWords: AppConfig.guidedWritingMinWords[level.clamp(0, 5)],
          allowKeyboard: level >= AppConfig.typingAllowedFromLevel,
        ));
      }
    }
    return steps;
  }

  /// One comprehension question about one of the unit's reading texts,
  /// rotating with [index].
  ReadingStep? readingStep(int index) {
    if (options.delayReading || unit.level < 2 || unit.readings.isEmpty) {
      return null;
    }
    final reading = unit.readings[index % unit.readings.length];
    if (reading.questions.isEmpty) {
      return null;
    }
    final q = reading.questions[random.nextInt(reading.questions.length)];
    final shuffled = [...q.options]..shuffle(random);
    return ReadingStep(
      stage: LessonStage.read,
      readingId: reading.id,
      question: q.question,
      options: shuffled,
      answer: q.answer,
    );
  }

  DialogueStep? dialogueStep({required bool allowStart}) {
    Dialogue? best;
    var bestStage = 99;
    for (final dialogue in unit.dialogues) {
      final stage = snapshot.dialogueStage(dialogue.id);
      if (stage < 4 && stage < bestStage) {
        best = dialogue;
        bestStage = stage;
      }
    }
    if (best == null) {
      if (unit.dialogues.isEmpty) {
        return null;
      }
      final pick = unit.dialogues[random.nextInt(unit.dialogues.length)];
      return DialogueStep(dialogueId: pick.id, dialogueStage: 3);
    }
    if (bestStage == 0 && !allowStart) {
      return null;
    }
    var next = bestStage + 1;
    if (next == 2 && !options.speechAvailable) {
      next = 3;
    }
    if (next == 4 && best.variation == null) {
      next = 3;
    }
    return DialogueStep(dialogueId: best.id, dialogueStage: next);
  }

  /// Items with the lowest boxes and most mistakes first.
  List<Item> weakest(List<Item> items, int count) {
    int weight(Item item) {
      final rows = snapshot.byItem[item.id];
      if (rows == null || rows.isEmpty) {
        return 0;
      }
      var w = 0;
      for (final row in rows.values) {
        w += row.box * 3 - row.wrongCount;
      }
      return w ~/ rows.length;
    }

    final sorted = [...items]..shuffle(random);
    sorted.sort((a, b) => weight(a).compareTo(weight(b)));
    return sorted.take(count).toList();
  }
}
