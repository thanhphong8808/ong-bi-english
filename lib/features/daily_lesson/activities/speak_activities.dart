// lib/features/daily_lesson/activities/speak_activities.dart
//
// Activities that use the microphone: new items, phonics, shadowing,
// answering Bi, pronunciation drills.
import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../curriculum/lesson_plan.dart';
import '../../../curriculum/models.dart';
import '../../../l10n/strings_vi.dart';
import '../../../widgets/bi_mascot.dart';
import '../../../widgets/item_picture.dart';
import '../../speak/mic_panel.dart';
import '../../speak/pron_drills.dart';
import 'activity_base.dart';

/// Shared handling of a microphone result with the two-attempt rule.
mixin _MicJudge<T extends ActivityView> on ActivityState<T> {
  final GlobalKey<MicPanelState> micKey = GlobalKey<MicPanelState>();

  Future<void> model();

  Future<void> judge(MicOutcome outcome) async {
    final score = outcome.score;
    if (score == null) {
      // No speech model or no microphone: practice without scoring.
      if (!finished) {
        await sayVi(S.praiseLines[ActivityState.random.nextInt(S.praiseLines.length)]);
        complete(StepResult.practised);
      }
      return;
    }
    if (score.passed) {
      await succeed(score.stars, score: score.similarity);
      return;
    }
    final again = await miss(showModel: model, score: score.similarity);
    if (again) {
      micKey.currentState?.reset();
    }
  }
}

// ---------------------------------------------------------------------------

class PresentItemActivity extends ActivityView<PresentItemStep> {
  const PresentItemActivity({super.key, required super.step, required super.onDone, super.testMode});

  @override
  ActivityState<PresentItemActivity> createState() => _PresentItemState();
}

class _PresentItemState extends ActivityState<PresentItemActivity> with _MicJudge<PresentItemActivity> {
  bool _ready = false;

  Item? get _item => item(widget.step.itemId);

  @override
  String get instructionVi => S.insNewItem;

  @override
  Future<void> model() => sayEn(_item?.en ?? '', slow: true);

  @override
  Future<void> onOpened() async {
    final it = _item;
    if (it == null) {
      complete();
      return;
    }
    await sayEn(it.en);
    if (it.syllables.length > 1) {
      await sayEn(it.syllables.join(', '), slow: true);
    } else {
      await sayEn(it.en, slow: true);
    }
    if (it.vi.isNotEmpty) {
      await sayVi('${S.meaningPrefix} ${it.vi}');
    }
    if (it.exampleEn.isNotEmpty) {
      await sayEn(it.exampleEn);
    }
    if (mounted) {
      setState(() => _ready = true);
      await sayVi(S.saySayAfter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final it = _item;
    if (it == null) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        Expanded(
          child: Sparkles(
            active: celebrating,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ItemPicture(item: it, size: 170),
                const SizedBox(height: 10),
                if (!hideText) BigWord(it.en, size: 52),
                if (!hideText && it.ipa.isNotEmpty)
                  Text(it.ipa, style: const TextStyle(fontSize: 20, color: Color(0xFF7A6A55))),
                const SizedBox(height: 6),
                Text(it.vi, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        MicPanel(
          key: micKey,
          target: it.en,
          itemId: it.id,
          enabled: _ready && !finished,
          onPlayModel: () => sayEn(it.en),
          onResult: judge,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class PhonicsActivity extends ActivityView<PhonicsStep> {
  const PhonicsActivity({super.key, required super.step, required super.onDone, super.testMode});

  @override
  ActivityState<PhonicsActivity> createState() => _PhonicsState();
}

class _PhonicsState extends ActivityState<PhonicsActivity> with _MicJudge<PhonicsActivity> {
  bool _ready = false;

  Item? get _item => item(widget.step.itemId);

  @override
  String get instructionVi => hideText ? S.insNewSoundNoLetter : S.insNewSound;

  String get _firstWord {
    final it = _item;
    if (it == null) {
      return '';
    }
    return it.soundWords.isNotEmpty ? it.soundWords.first : it.en;
  }

  @override
  Future<void> model() => sayEn(_firstWord, slow: true);

  @override
  Future<void> onOpened() async {
    final it = _item;
    if (it == null) {
      complete();
      return;
    }
    if (it.tipVi.isNotEmpty) {
      await sayVi(it.tipVi);
    }
    for (final word in it.soundWords) {
      await sayEn(word);
    }
    if (mounted) {
      setState(() => _ready = true);
      await sayVi(S.saySayAfter);
      await sayEn(_firstWord);
    }
  }

  @override
  Widget build(BuildContext context) {
    final it = _item;
    if (it == null) {
      return const SizedBox.shrink();
    }
    final pictures = [
      for (final word in it.soundWords)
        ?curriculum.itemByWord(word),
    ];
    return Column(
      children: [
        Expanded(
          child: Sparkles(
            active: celebrating,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!hideText)
                  BigWord('${it.letter.toUpperCase()} ${it.letter.toLowerCase()}', size: 110),
                if (!hideText && it.sound.isNotEmpty)
                  Text(it.sound, style: const TextStyle(fontSize: 26, color: Color(0xFF7A6A55))),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 18,
                  children: [
                    if (pictures.isEmpty) ItemPicture(item: it, size: 110),
                    for (final w in pictures)
                      GestureDetector(onTap: () => sayEn(w.en), child: ItemPicture(item: w, size: 100)),
                  ],
                ),
              ],
            ),
          ),
        ),
        MicPanel(
          key: micKey,
          target: _firstWord,
          alternatives: it.soundWords.skip(1).toList(),
          itemId: it.id,
          enabled: _ready && !finished,
          onPlayModel: () => sayEn(_firstWord),
          onResult: judge,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class SayActivity extends ActivityView<SayStep> {
  const SayActivity({super.key, required super.step, required super.onDone, super.testMode});

  @override
  ActivityState<SayActivity> createState() => _SayState();
}

class _SayState extends ActivityState<SayActivity> with _MicJudge<SayActivity> {
  bool get _sentence => widget.step.text.trim().contains(' ');

  @override
  String get instructionVi => widget.step.modelFirst ? S.insShadow : S.insSeeSay;

  @override
  Future<void> model() => sayEn(widget.step.text, slow: true);

  @override
  Future<void> onOpened() async {
    if (widget.step.modelFirst) {
      await sayEn(widget.step.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final picture = widget.step.showPicture ? item(widget.step.itemId) : null;
    final showText = widget.step.modelFirst && !hideText;
    final allowModel = widget.step.modelFirst || !widget.testMode;
    return Column(
      children: [
        Expanded(
          child: Sparkles(
            active: celebrating,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (picture != null) ItemPicture(item: picture, size: 170),
                if (picture == null) const BiMascot(mood: BiMood.happy, size: 140),
                const SizedBox(height: 14),
                if (showText)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.ink, width: 2),
                    ),
                    child: BigWord(widget.step.text, size: _sentence ? 30 : 46),
                  ),
              ],
            ),
          ),
        ),
        MicPanel(
          key: micKey,
          target: widget.step.text,
          alternatives: widget.step.alternatives,
          sentence: _sentence,
          itemId: widget.step.itemId,
          enabled: !finished,
          onPlayModel: allowModel ? () => sayEn(widget.step.text) : null,
          onResult: judge,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class AnswerActivity extends ActivityView<AnswerStep> {
  const AnswerActivity({super.key, required super.step, required super.onDone, super.testMode});

  @override
  ActivityState<AnswerActivity> createState() => _AnswerState();
}

class _AnswerState extends ActivityState<AnswerActivity> with _MicJudge<AnswerActivity> {
  @override
  String get instructionVi => S.insAnswer;

  @override
  Future<void> model() => sayEn(widget.step.questionEn, slow: true);

  @override
  Future<void> onOpened() => sayEn(widget.step.questionEn);

  @override
  Widget build(BuildContext context) {
    final picture = item(widget.step.pictureItemId);
    final accept = widget.step.accept;
    return Column(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const BiMascot(mood: BiMood.listening, size: 130),
              if (picture != null) ItemPicture(item: picture, size: 150),
              const SizedBox(height: 8),
              KidIconButton(icon: Icons.volume_up_rounded, onPressed: () => sayEn(widget.step.questionEn)),
            ],
          ),
        ),
        MicPanel(
          key: micKey,
          target: accept.isNotEmpty ? accept.first : '',
          alternatives: accept.skip(1).toList(),
          anyAnswer: widget.step.anyAnswer,
          sentence: true,
          enabled: !finished,
          onResult: judge,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class PronDrillActivity extends ActivityView<PronDrillStep> {
  const PronDrillActivity({super.key, required super.step, required super.onDone, super.testMode});

  @override
  ActivityState<PronDrillActivity> createState() => _PronDrillState();
}

class _PronDrillState extends ActivityState<PronDrillActivity> {
  final GlobalKey<MicPanelState> _mic = GlobalKey<MicPanelState>();
  late final PronDrill? _drill = pronDrills[widget.step.focus] ?? pronDrills['final_consonant'];
  late final List<String> _targets = (_drill?.practice ?? const <String>[]).take(3).toList();
  int _index = 0;
  int _stars = 0;
  bool _ready = false;

  @override
  String get instructionVi => _drill?.tipVi ?? '';

  String get _target => _index < _targets.length ? _targets[_index] : '';

  @override
  Future<void> onOpened() async {
    await sayEn(_target);
    if (mounted) {
      setState(() => _ready = true);
    }
  }

  Future<void> _next(MicOutcome outcome) async {
    _stars += outcome.score?.stars ?? 2;
    if (outcome.score != null && outcome.score!.passed) {
      await sayVi(S.praiseLines[ActivityState.random.nextInt(S.praiseLines.length)]);
    }
    if (!mounted) {
      return;
    }
    if (_index + 1 >= _targets.length) {
      final average = (_stars / _targets.length).round().clamp(1, 3).toInt();
      complete(StepResult(correct: true, stars: average));
      return;
    }
    setState(() => _index++);
    _mic.currentState?.reset();
    await sayEn(_target);
  }

  @override
  Widget build(BuildContext context) {
    final drill = _drill;
    if (drill == null || _targets.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              EmojiText(drill.emoji, size: 90),
              const SizedBox(height: 8),
              Text(drill.titleVi, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              if (!hideText) BigWord(_target, size: 44),
              const SizedBox(height: 8),
              Text('${_index + 1} / ${_targets.length}', style: const TextStyle(fontSize: 18)),
            ],
          ),
        ),
        MicPanel(
          key: _mic,
          target: _target,
          sentence: _target.contains(' '),
          enabled: _ready && !finished,
          onPlayModel: () => sayEn(_target, slow: true),
          onResult: _next,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
