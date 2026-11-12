// lib/features/daily_lesson/activities/pick_activities.dart
//
// Listening and reading games: tap the right picture, word, letter, bubble,
// colour, true/false or missing word.
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../core/config/app_config.dart';
import '../../../curriculum/lesson_plan.dart';
import '../../../curriculum/models.dart';
import '../../../l10n/strings_vi.dart';
import '../../../widgets/item_picture.dart';
import 'activity_base.dart';
import '../../../widgets/motion.dart';

/// Shared state for "tap one of several options" games.
abstract class _PickState<T extends ActivityView> extends ActivityState<T> {
  final Set<int> dimmed = {};
  int? chosen;

  Future<void> onTapOption(int index, bool correct, {Future<void> Function()? model}) async {
    if (finished || dimmed.contains(index)) {
      return;
    }
    if (correct) {
      setState(() => chosen = index);
      await succeed(attempts == 0 ? 3 : 2);
    } else {
      setState(() => dimmed.add(index));
      await miss(showModel: model);
    }
  }
}

Widget _speakerButton(VoidCallback onTap) =>
    KidIconButton(icon: Icons.volume_up_rounded, onPressed: onTap, size: 84, color: AppColors.honey);

// ---------------------------------------------------------------------------

class PickImageActivity extends ActivityView<PickImageStep> {
  const PickImageActivity({super.key, required super.step, required super.onDone, super.testMode});

  @override
  ActivityState<PickImageActivity> createState() => _PickImageState();
}

class _PickImageState extends _PickState<PickImageActivity> {
  @override
  String get instructionVi => S.insListenPick;

  Item? get target => item(widget.step.itemId);

  @override
  Future<void> onOpened() => sayEn(target?.en ?? '');

  @override
  Widget build(BuildContext context) {
    final options = [for (final id in widget.step.optionIds) item(id)].whereType<Item>().toList();
    return Column(
      children: [
        _speakerButton(() => sayEn(target?.en ?? '')),
        const SizedBox(height: 18),
        Expanded(
          child: Center(
            child: ChoiceGrid(
              children: [
                for (var i = 0; i < options.length; i++)
                  Sparkles(
                    active: chosen == i,
                    child: PictureCard(
                      highlight: chosen == i,
                      dimmed: dimmed.contains(i),
                      onTap: () => onTapOption(
                        i,
                        options[i].id == widget.step.itemId,
                        model: () => sayEn(target?.en ?? '', slow: true),
                      ),
                      child: ItemPicture(item: options[i], size: 110),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class PickMeaningActivity extends ActivityView<PickMeaningStep> {
  const PickMeaningActivity({super.key, required super.step, required super.onDone, super.testMode});

  @override
  ActivityState<PickMeaningActivity> createState() => _PickMeaningState();
}

class _PickMeaningState extends _PickState<PickMeaningActivity> {
  @override
  String get instructionVi => S.insPickMeaning;

  Item? get target => item(widget.step.itemId);

  @override
  Future<void> onOpened() => sayEn(target?.en ?? '');

  @override
  Widget build(BuildContext context) {
    final options = [for (final id in widget.step.optionIds) item(id)].whereType<Item>().toList();
    return Column(
      children: [
        _speakerButton(() => sayEn(target?.en ?? '')),
        const SizedBox(height: 18),
        for (var i = 0; i < options.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              height: 96,
              width: double.infinity,
              child: Sparkles(
                active: chosen == i,
                child: PictureCard(
                  highlight: chosen == i,
                  dimmed: dimmed.contains(i),
                  onTap: () => onTapOption(i, options[i].id == widget.step.itemId),
                  child: Text(
                    options[i].vi,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class PickWordActivity extends ActivityView<PickWordStep> {
  const PickWordActivity({super.key, required super.step, required super.onDone, super.testMode});

  @override
  ActivityState<PickWordActivity> createState() => _PickWordState();
}

class _PickWordState extends _PickState<PickWordActivity> {
  @override
  String get instructionVi => S.insReadPick;

  @override
  Widget build(BuildContext context) {
    final target = item(widget.step.itemId);
    final options = [for (final id in widget.step.optionIds) item(id)].whereType<Item>().toList();
    return Column(
      children: [
        if (target != null) ItemPicture(item: target, size: 150),
        const SizedBox(height: 18),
        for (var i = 0; i < options.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: SizedBox(
              height: 92,
              width: double.infinity,
              child: Sparkles(
                active: chosen == i,
                child: PictureCard(
                  highlight: chosen == i,
                  dimmed: dimmed.contains(i),
                  onTap: () async {
                    final correct = options[i].id == widget.step.itemId;
                    if (correct) {
                      await sayEn(options[i].en);
                    }
                    await onTapOption(i, correct);
                  },
                  child: BigWord(options[i].en, size: 40),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class LetterSoundActivity extends ActivityView<LetterSoundStep> {
  const LetterSoundActivity({super.key, required super.step, required super.onDone, super.testMode});

  @override
  ActivityState<LetterSoundActivity> createState() => _LetterSoundState();
}

class _LetterSoundState extends _PickState<LetterSoundActivity> {
  @override
  String get instructionVi => S.insLetterSound;

  Item? get target => item(widget.step.itemId);

  Future<void> _play() async {
    final t = target;
    if (t == null) {
      return;
    }
    await sayEn(t.soundWords.isNotEmpty ? t.soundWords.join(', ') : t.exampleEn);
  }

  @override
  Future<void> onOpened() => _play();

  @override
  Widget build(BuildContext context) {
    final letters = widget.step.optionLetters;
    final answer = target?.letter.toLowerCase() ?? '';
    return Column(
      children: [
        _speakerButton(_play),
        const SizedBox(height: 18),
        Expanded(
          child: Center(
            child: ChoiceGrid(
              children: [
                for (var i = 0; i < letters.length; i++)
                  Sparkles(
                    active: chosen == i,
                    child: PictureCard(
                      highlight: chosen == i,
                      dimmed: dimmed.contains(i),
                      onTap: () => onTapOption(i, letters[i].toLowerCase() == answer, model: _play),
                      child: BigWord('${letters[i].toUpperCase()} ${letters[i].toLowerCase()}', size: 46),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class BubbleActivity extends ActivityView<BubbleStep> {
  const BubbleActivity({super.key, required super.step, required super.onDone, super.testMode});

  @override
  ActivityState<BubbleActivity> createState() => _BubbleState();
}

class _BubbleState extends _PickState<BubbleActivity> with SingleTickerProviderStateMixin {
  late final AnimationController _float =
      AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    loopUnlessReducedMotion(_float, context);
  }

  @override
  String get instructionVi => S.insBubble;

  Item? get target => item(widget.step.itemId);

  @override
  Future<void> onOpened() => sayEn(target?.en ?? '');

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = [for (final id in widget.step.optionIds) item(id)].whereType<Item>().toList();
    return Column(
      children: [
        _speakerButton(() => sayEn(target?.en ?? '')),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              const size = 132.0;
              return AnimatedBuilder(
                animation: _float,
                builder: (context, _) {
                  final t = _float.value * 2 * math.pi;
                  return Stack(
                    children: [
                      for (var i = 0; i < options.length; i++)
                        Positioned(
                          left: (box.maxWidth - size) * (0.1 + 0.8 * ((i * 0.37 + 0.15) % 1.0)) +
                              math.sin(t + i * 1.7) * 12,
                          top: (box.maxHeight - size) * (i / math.max(1, options.length - 1)) +
                              math.cos(t * 1.3 + i) * 10,
                          child: AnimatedScale(
                            scale: dimmed.contains(i) ? 0.0 : (chosen == i ? 1.25 : 1.0),
                            duration: const Duration(milliseconds: 300),
                            child: SizedBox(
                              width: size,
                              height: size,
                              child: PictureCard(
                                round: true,
                                color: const Color(0xFFDDF3FF),
                                highlight: chosen == i,
                                onTap: () => onTapOption(
                                  i,
                                  options[i].id == widget.step.itemId,
                                  model: () => sayEn(target?.en ?? '', slow: true),
                                ),
                                child: ItemPicture(item: options[i], size: 72),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class MatchPairsActivity extends ActivityView<MatchPairsStep> {
  const MatchPairsActivity({super.key, required super.step, required super.onDone, super.testMode});

  @override
  ActivityState<MatchPairsActivity> createState() => _MatchPairsState();
}

class _MatchPairsState extends ActivityState<MatchPairsActivity> {
  late final List<Item> _items = [for (final id in widget.step.itemIds) item(id)].whereType<Item>().toList();
  late final List<Item> _order = [..._items]..shuffle(ActivityState.random);
  final Set<String> _matched = {};
  int _current = 0;
  int _mistakes = 0;
  String? _flash;

  @override
  String get instructionVi => S.insMatch;

  Item? get _target => _current < _order.length ? _order[_current] : null;

  @override
  Future<void> onOpened() => sayEn(_target?.en ?? '');

  Future<void> _tap(Item tapped) async {
    final target = _target;
    if (target == null || finished || _matched.contains(tapped.id)) {
      return;
    }
    if (tapped.id == target.id) {
      setState(() {
        _matched.add(tapped.id);
        _flash = tapped.id;
        _current++;
      });
      if (_current >= _order.length) {
        await succeed(_mistakes == 0 ? 3 : (_mistakes <= 2 ? 2 : 1));
      } else {
        await sayEn(target.en);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await sayEn(_target!.en);
      }
    } else {
      _mistakes++;
      await sayVi(S.sayRetry);
      await sayEn(target.en, slow: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _speakerButton(() => sayEn(_target?.en ?? '')),
        const SizedBox(height: 18),
        Expanded(
          child: Center(
            child: ChoiceGrid(
              children: [
                for (final it in _items)
                  Sparkles(
                    active: _flash == it.id,
                    child: PictureCard(
                      highlight: _matched.contains(it.id),
                      onTap: () => _tap(it),
                      child: ItemPicture(item: it, size: 96),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

const Map<String, Color> colorPalette = {
  'red': Color(0xFFE63946),
  'blue': Color(0xFF4361EE),
  'green': Color(0xFF52B788),
  'yellow': Color(0xFFFFD23F),
  'pink': Color(0xFFFF8FA3),
  'orange': Color(0xFFFF9F1C),
};

class ColorActivity extends ActivityView<ColorStep> {
  const ColorActivity({super.key, required super.step, required super.onDone, super.testMode});

  @override
  ActivityState<ColorActivity> createState() => _ColorState();
}

class _ColorState extends ActivityState<ColorActivity> {
  String? _brush;
  final Map<String, String> _painted = {};

  @override
  String get instructionVi => S.insColor;

  String get _command {
    final target = item(widget.step.itemId);
    return 'Color the ${target?.en ?? ''} ${widget.step.color}.';
  }

  @override
  Future<void> onOpened() => sayEn(_command);

  Future<void> _paint(Item it) async {
    final brush = _brush;
    if (finished) {
      return;
    }
    if (brush == null) {
      await sayVi(S.pickColorFirst);
      return;
    }
    setState(() => _painted[it.id] = brush);
    final correct = it.id == widget.step.itemId && brush == widget.step.color;
    if (correct) {
      await succeed(attempts == 0 ? 3 : 2);
    } else {
      final again = await miss(showModel: () => sayEn(_command, slow: true));
      if (again && mounted) {
        setState(() {
          _painted.clear();
          _brush = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = [for (final id in widget.step.optionIds) item(id)].whereType<Item>().toList();
    return Column(
      children: [
        _speakerButton(() => sayEn(_command)),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final entry in colorPalette.entries)
              GestureDetector(
                onTap: () {
                  setState(() => _brush = entry.key);
                  sayEn(entry.key);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: _brush == entry.key ? 70 : 58,
                  height: _brush == entry.key ? 70 : 58,
                  decoration: BoxDecoration(
                    color: entry.value,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.ink, width: _brush == entry.key ? 5 : 3),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Center(
            child: ChoiceGrid(
              children: [
                for (final it in options)
                  Sparkles(
                    active: celebrating && it.id == widget.step.itemId,
                    child: PictureCard(
                      color: colorPalette[_painted[it.id]] ?? AppColors.white,
                      onTap: () => _paint(it),
                      child: ItemPicture(item: it, size: 96),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class TrueFalseActivity extends ActivityView<TrueFalseStep> {
  const TrueFalseActivity({super.key, required super.step, required super.onDone, super.testMode});

  @override
  ActivityState<TrueFalseActivity> createState() => _TrueFalseState();
}

class _TrueFalseState extends _PickState<TrueFalseActivity> {
  @override
  String get instructionVi => S.insTrueFalse;

  @override
  Widget build(BuildContext context) {
    final picture = item(widget.step.pictureItemId);
    return Column(
      children: [
        if (picture != null) ItemPicture(item: picture, size: 150),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.ink, width: 2),
          ),
          child: BigWord(widget.step.text, size: 32),
        ),
        const Spacer(),
        Row(
          children: [
            for (final (index, value, emoji) in const [(0, true, '👍'), (1, false, '👎')])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: SizedBox(
                    height: 130,
                    child: Sparkles(
                      active: chosen == index,
                      child: PictureCard(
                        highlight: chosen == index,
                        dimmed: dimmed.contains(index),
                        onTap: () => onTapOption(
                          index,
                          value == widget.step.isTrue,
                          model: () => sayEn(widget.step.text, slow: true),
                        ),
                        child: EmojiText(emoji, size: 72),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class FillBlankActivity extends ActivityView<FillBlankStep> {
  const FillBlankActivity({super.key, required super.step, required super.onDone, super.testMode});

  @override
  ActivityState<FillBlankActivity> createState() => _FillBlankState();
}

class _FillBlankState extends _PickState<FillBlankActivity> {
  @override
  String get instructionVi => S.insFillBlank;

  String get _full => widget.step.text.replaceFirst('___', widget.step.answer);

  @override
  Widget build(BuildContext context) {
    final picture = item(widget.step.pictureItemId);
    final shown = chosen == null ? widget.step.text : _full;
    return Column(
      children: [
        if (picture != null) ItemPicture(item: picture, size: 130),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.ink, width: 2),
          ),
          child: BigWord(shown, size: 32),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < widget.step.options.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: SizedBox(
              height: AppConfig.kidTouchTargetMin + 16,
              width: double.infinity,
              child: PictureCard(
                highlight: chosen == i,
                dimmed: dimmed.contains(i),
                onTap: () async {
                  final correct = widget.step.options[i].toLowerCase() == widget.step.answer.toLowerCase();
                  if (correct) {
                    setState(() => chosen = i);
                    await sayEn(_full);
                    chosen = null;
                  }
                  await onTapOption(i, correct);
                },
                child: BigWord(widget.step.options[i], size: 32),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class ReadingActivity extends ActivityView<ReadingStep> {
  const ReadingActivity({super.key, required super.step, required super.onDone, super.testMode});

  @override
  ActivityState<ReadingActivity> createState() => _ReadingState();
}

class _ReadingState extends _PickState<ReadingActivity> {
  @override
  String get instructionVi => S.insReading;

  Reading? get _reading => curriculum.reading(widget.step.readingId);

  @override
  Widget build(BuildContext context) {
    final reading = _reading;
    if (reading == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => complete());
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.ink, width: 2),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(reading.titleEn,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                      ),
                      if (!widget.testMode)
                        IconButton(
                          iconSize: 36,
                          icon: const Icon(Icons.volume_up_rounded),
                          onPressed: () => sayEn(reading.text),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reading.text,
                    style: const TextStyle(fontFamily: AppTheme.writingFont, fontSize: 22, height: 1.45),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(widget.step.question,
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (var i = 0; i < widget.step.options.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: SizedBox(
              height: 72,
              width: double.infinity,
              child: Sparkles(
                active: chosen == i,
                child: PictureCard(
                  highlight: chosen == i,
                  dimmed: dimmed.contains(i),
                  onTap: () => onTapOption(i, widget.step.options[i] == widget.step.answer),
                  child: Text(widget.step.options[i],
                      textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
