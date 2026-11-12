// lib/features/daily_lesson/activities/write_activities.dart
//
// Writing: trace letters (geometric scoring), write letters and copy words
// (ML Kit), dictation (handwriting or the big keyboard), letter tiles and
// guided sentence writing.
import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../core/services/ink_service.dart';
import '../../../curriculum/basic_words.dart';
import '../../../curriculum/lesson_plan.dart';
import '../../../curriculum/letter_strokes.dart';
import '../../../curriculum/scorers/spelling_scorer.dart';
import '../../../curriculum/scorers/trace_scorer.dart';
import '../../../l10n/strings_vi.dart';
import '../../../widgets/item_picture.dart';
import '../../write/big_keyboard.dart';
import '../../write/ink_pad.dart';
import '../../write/trace_canvas.dart';
import 'activity_base.dart';

Widget _toolRow({required VoidCallback onClear, required VoidCallback onCheck, Widget? extra}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        KidIconButton(icon: Icons.cleaning_services_rounded, onPressed: onClear, label: S.clear),
        ?extra,
        KidIconButton(icon: Icons.check_rounded, onPressed: onCheck, label: S.done, color: AppColors.leaf, size: 84),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------

class TraceActivity extends ActivityView<TraceStep> {
  const TraceActivity({super.key, required super.step, required super.onDone, super.testMode});

  @override
  ActivityState<TraceActivity> createState() => _TraceState();
}

class _TraceState extends ActivityState<TraceActivity> {
  final GlobalKey<TraceCanvasState> _canvas = GlobalKey<TraceCanvasState>();
  late final LetterTemplate? _template = LetterStrokes.of(widget.step.letter);
  bool _checking = false;

  @override
  String get instructionVi => S.insTrace;

  @override
  Future<void> onOpened() async {
    if (!hideText) {
      await sayEn(widget.step.letter.toLowerCase());
    }
  }

  void _pause(List<List<P>> strokes) {
    final template = _template;
    if (template != null && strokes.length >= template.strokes.length) {
      _check();
    }
  }

  Future<void> _check() async {
    final template = _template;
    final canvas = _canvas.currentState;
    if (template == null || canvas == null || !canvas.hasInk || _checking || finished) {
      return;
    }
    _checking = true;
    final result = const TraceScorer().score(template, canvas.strokesInBands());
    if (result.passed) {
      await succeed(result.stars, score: result.coverage);
    } else {
      if (result.nearly && (!result.directionOk || !result.orderOk) && !widget.testMode) {
        await sayVi(S.traceDirection);
      }
      final again = await miss(score: result.coverage);
      if (again && mounted) {
        canvas.clear();
      }
    }
    _checking = false;
  }

  @override
  Widget build(BuildContext context) {
    final template = _template;
    if (template == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => complete());
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        BigWord(widget.step.letter, size: 54),
        Expanded(
          child: Sparkles(
            active: celebrating,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.ink, width: 3),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: TraceCanvas(key: _canvas, template: template, onPause: _pause, enabled: !finished),
              ),
            ),
          ),
        ),
        _toolRow(onClear: () => _canvas.currentState?.clear(), onCheck: _check),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

/// Shared logic: recognise handwriting with ML Kit, then compare.
abstract class _InkState<T extends ActivityView> extends ActivityState<T> {
  final GlobalKey<InkPadState> pad = GlobalKey<InkPadState>();
  bool busy = false;

  String get target;

  bool get sentence => false;

  Future<List<String>> recognize(List<List<InkPoint>> strokes) async {
    try {
      return await services.ink.recognize(strokes);
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> check() async {
    final state = pad.currentState;
    if (state == null || !state.hasInk || busy || finished) {
      return;
    }
    busy = true;
    final candidates = await recognize(state.strokes);
    await judgeText(candidates);
    busy = false;
  }

  Future<void> judgeText(List<String> candidates) async {
    if (candidates.isEmpty && !services.capabilities.value.ink) {
      // No handwriting model: count the effort without a grade.
      complete(StepResult.practised);
      return;
    }
    final result = const SpellingScorer().bestOf(target, candidates.take(5).toList());
    final ok = sentence ? result.score >= 0.9 : result.correct;
    if (ok) {
      await succeed(result.score >= 0.99 ? 3 : 2, score: result.score, answer: result.written);
    } else {
      final again = await miss(showModel: showModel, score: result.score, answer: result.written);
      if (again && mounted) {
        pad.currentState?.clear();
      }
    }
  }

  Future<void> showModel() async {}
}

// ---------------------------------------------------------------------------

class WriteLetterActivity extends ActivityView<WriteLetterStep> {
  const WriteLetterActivity({super.key, required super.step, required super.onDone, super.testMode});

  @override
  ActivityState<WriteLetterActivity> createState() => _WriteLetterState();
}

class _WriteLetterState extends _InkState<WriteLetterActivity> {
  @override
  String get instructionVi => S.insWriteLetter;

  @override
  String get target => widget.step.letter;

  @override
  Future<void> onOpened() => sayEn(widget.step.letter.toLowerCase());

  @override
  Future<void> judgeText(List<String> candidates) async {
    // A single letter: either case counts, any of the top candidates.
    final want = widget.step.letter.toLowerCase();
    final hit = candidates.take(3).any((c) => c.trim().toLowerCase() == want);
    if (candidates.isEmpty && !services.capabilities.value.ink) {
      complete(StepResult.practised);
      return;
    }
    if (hit) {
      await succeed(candidates.first.trim().toLowerCase() == want ? 3 : 2);
    } else {
      final again = await miss(showModel: showModel);
      if (again && mounted) {
        pad.currentState?.clear();
      }
    }
  }

  @override
  Future<void> showModel() => sayEn(widget.step.letter.toLowerCase(), slow: true);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        KidIconButton(icon: Icons.volume_up_rounded, onPressed: () => sayEn(widget.step.letter.toLowerCase())),
        if (attempts > 0 && !hideText) BigWord(widget.step.letter, size: 48),
        const SizedBox(height: 10),
        Expanded(
          child: Sparkles(active: celebrating, child: InkPad(key: pad, onPause: (_) => check(), enabled: !finished)),
        ),
        _toolRow(onClear: () => pad.currentState?.clear(), onCheck: check),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class CopyWordActivity extends ActivityView<CopyWordStep> {
  const CopyWordActivity({super.key, required super.step, required super.onDone, super.testMode});

  @override
  ActivityState<CopyWordActivity> createState() => _CopyWordState();
}

class _CopyWordState extends _InkState<CopyWordActivity> {
  @override
  String get instructionVi => S.insCopy;

  @override
  String get target => widget.step.word;

  @override
  Future<void> onOpened() => sayEn(widget.step.word);

  @override
  Widget build(BuildContext context) {
    final picture = item(widget.step.itemId);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (picture != null) ItemPicture(item: picture, size: 80),
            const SizedBox(width: 16),
            BigWord(widget.step.word, size: 52),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Sparkles(active: celebrating, child: InkPad(key: pad, onPause: (_) => check(), enabled: !finished)),
        ),
        _toolRow(onClear: () => pad.currentState?.clear(), onCheck: check),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class DictationActivity extends ActivityView<DictationStep> {
  const DictationActivity({super.key, required super.step, required super.onDone, super.testMode});

  @override
  ActivityState<DictationActivity> createState() => _DictationState();
}

class _DictationState extends _InkState<DictationActivity> {
  bool _keyboard = false;
  String _typed = '';

  @override
  String get instructionVi => S.insDictate;

  @override
  String get target => widget.step.text;

  @override
  bool get sentence => widget.step.sentence;

  @override
  Future<void> onOpened() => sayEn(widget.step.text);

  @override
  Future<void> showModel() async {
    await sayEn(widget.step.text, slow: true);
    if (mounted && !widget.step.sentence) {
      // Spell the word letter by letter on the second try.
      await sayEn(widget.step.text.split('').join(', '), slow: true);
    }
  }

  Future<void> _submitTyped() async {
    if (_typed.trim().isEmpty || busy || finished) {
      return;
    }
    busy = true;
    await judgeText([_typed]);
    busy = false;
    if (mounted && !finished) {
      setState(() => _typed = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final picture = item(widget.step.itemId);
    final canType = widget.step.allowKeyboard;
    final useKeyboard = canType && (_keyboard || !services.capabilities.value.ink);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            KidIconButton(icon: Icons.volume_up_rounded, onPressed: () => sayEn(widget.step.text)),
            if (picture != null && !widget.testMode) ...[
              const SizedBox(width: 16),
              ItemPicture(item: picture, size: 72),
            ],
          ],
        ),
        const SizedBox(height: 10),
        if (useKeyboard) ...[
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 90),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.ink, width: 3),
            ),
            child: Sparkles(active: celebrating, child: BigWord(_typed.isEmpty ? ' ' : _typed, size: 36)),
          ),
          const Spacer(),
          BigKeyboard(
            punctuation: widget.step.sentence,
            onKey: (k) => setState(() => _typed += k),
            onBackspace: () => setState(() {
              if (_typed.isNotEmpty) {
                _typed = _typed.substring(0, _typed.length - 1);
              }
            }),
            onDone: _submitTyped,
          ),
        ] else ...[
          Expanded(
            child: Sparkles(
              active: celebrating,
              child: InkPad(
                key: pad,
                lines: widget.step.sentence ? 2 : 1,
                onPause: (_) {
                  if (!widget.step.sentence) {
                    check();
                  }
                },
                enabled: !finished,
              ),
            ),
          ),
          _toolRow(
            onClear: () => pad.currentState?.clear(),
            onCheck: check,
            extra: canType
                ? KidIconButton(
                    icon: Icons.keyboard_rounded,
                    label: S.keyboard,
                    onPressed: () => setState(() => _keyboard = true),
                  )
                : null,
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------

/// Writing test: the picture and Bi's voice, the word stays hidden.
class WriteRecallActivity extends ActivityView<WriteRecallStep> {
  const WriteRecallActivity({super.key, required super.step, required super.onDone, super.testMode});

  @override
  ActivityState<WriteRecallActivity> createState() => _WriteRecallState();
}

class _WriteRecallState extends _InkState<WriteRecallActivity> {
  @override
  String get instructionVi => S.insWriteRecall;

  @override
  String get target => widget.step.word;

  @override
  bool get sentence => widget.step.word.contains(' ');

  @override
  Future<void> onOpened() => sayEn(widget.step.word);

  @override
  Future<void> showModel() => sayEn(widget.step.word, slow: true);

  @override
  Widget build(BuildContext context) {
    final picture = item(widget.step.itemId);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (picture != null) ItemPicture(item: picture, size: 110),
            const SizedBox(width: 16),
            KidIconButton(icon: Icons.volume_up_rounded, onPressed: () => sayEn(widget.step.word)),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Sparkles(
            active: celebrating,
            child: InkPad(key: pad, lines: sentence ? 2 : 1, onPause: (_) {}, enabled: !finished),
          ),
        ),
        _toolRow(onClear: () => pad.currentState?.clear(), onCheck: check),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class WordBuilderActivity extends ActivityView<WordBuilderStep> {
  const WordBuilderActivity({super.key, required super.step, required super.onDone, super.testMode});

  @override
  ActivityState<WordBuilderActivity> createState() => _WordBuilderState();
}

class _WordBuilderState extends ActivityState<WordBuilderActivity> {
  late final String _word = widget.step.word.toLowerCase().replaceAll(' ', '');
  late final List<String> _tiles = _makeTiles();
  final Set<int> _used = {};
  int _filled = 0;
  int _errors = 0;
  int? _shake;

  List<String> _makeTiles() {
    final letters = _word.split('');
    const extra = 'aeioustnrlmp';
    final pool = extra.split('').where((c) => !letters.contains(c)).toList()..shuffle(ActivityState.random);
    final tiles = [...letters, ...pool.take(letters.length <= 4 ? 1 : 2)]..shuffle(ActivityState.random);
    return tiles;
  }

  @override
  String get instructionVi => widget.step.speakWord ? S.insTilesListen : S.insTiles;

  @override
  Future<void> onOpened() async {
    if (widget.step.speakWord) {
      await sayEn(widget.step.word);
    }
  }

  Future<void> _tap(int index) async {
    if (finished || _used.contains(index) || _filled >= _word.length) {
      return;
    }
    if (_tiles[index] == _word[_filled]) {
      setState(() {
        _used.add(index);
        _filled++;
      });
      if (_filled == _word.length) {
        await sayEn(widget.step.word);
        if (widget.testMode && _errors > 0) {
          await miss(score: 0.5, answer: widget.step.word);
        } else {
          await succeed(_errors == 0 ? 3 : (_errors <= 2 ? 2 : 1), score: _errors == 0 ? 1 : 0.7, answer: widget.step.word);
        }
      }
    } else {
      _errors++;
      setState(() => _shake = index);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (mounted) {
        setState(() => _shake = null);
      }
      if (!widget.testMode && _errors % 2 == 0) {
        // Show which letter comes next.
        await sayEn(_word[_filled], slow: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final picture = item(widget.step.itemId);
    return Column(
      children: [
        if (picture != null) ItemPicture(item: picture, size: 120),
        if (widget.step.speakWord)
          KidIconButton(icon: Icons.volume_up_rounded, onPressed: () => sayEn(widget.step.word), size: 64),
        const SizedBox(height: 16),
        Sparkles(
          active: celebrating,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < _word.length; i++)
                Container(
                  width: 54,
                  height: 66,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i < _filled ? AppColors.honey : AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.ink, width: 2.5),
                  ),
                  child: BigWord(i < _filled ? _word[i] : '', size: 36),
                ),
            ],
          ),
        ),
        const Spacer(),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < _tiles.length; i++)
              AnimatedSlide(
                offset: _shake == i ? const Offset(0.08, 0) : Offset.zero,
                duration: const Duration(milliseconds: 90),
                child: AnimatedOpacity(
                  opacity: _used.contains(i) ? 0.2 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: SizedBox(
                    width: 76,
                    height: 76,
                    child: PictureCard(onTap: () => _tap(i), child: BigWord(_tiles[i], size: 36)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class WriteSentencesActivity extends ActivityView<WriteSentencesStep> {
  const WriteSentencesActivity({super.key, required super.step, required super.onDone, super.testMode});

  @override
  ActivityState<WriteSentencesActivity> createState() => _WriteSentencesState();
}

class _WriteSentencesState extends _InkState<WriteSentencesActivity> {
  final List<String> _sentences = [];
  String _typed = '';
  bool _keyboard = false;

  @override
  String get instructionVi => S.insWriteSentences;

  @override
  String get target => '';

  int get _words => _sentences.join(' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  void _add(String text) {
    final clean = text.trim();
    if (clean.isEmpty) {
      return;
    }
    setState(() => _sentences.add(clean));
    pad.currentState?.clear();
  }

  Future<void> _addHandwritten() async {
    final state = pad.currentState;
    if (state == null || !state.hasInk || busy) {
      return;
    }
    busy = true;
    final candidates = await recognize(state.strokes);
    busy = false;
    if (candidates.isNotEmpty) {
      _add(candidates.first);
    }
  }

  /// Deterministic grading: enough sentences, enough words, mostly known
  /// vocabulary, capital letters and full stops.
  Future<void> _finish() async {
    if (finished) {
      return;
    }
    if (_typed.trim().isNotEmpty) {
      _add(_typed);
      _typed = '';
    }
    final known = {
      for (final unit in curriculum.units)
        if (unit.level <= (curriculum.unitById(widget.step.itemId)?.level ?? 5))
          for (final it in unit.items) it.en.toLowerCase(),
    };
    final tokens = wordTokens(_sentences.join(' '));
    final knownRatio = tokens.isEmpty ? 0.0 : tokens.where((w) => isKnownWord(w, known)).length / tokens.length;
    final tidy = _sentences.isEmpty
        ? 0.0
        : _sentences.where((s) => RegExp(r'^[A-Z]').hasMatch(s) && RegExp(r'[.!?]$').hasMatch(s)).length /
            _sentences.length;
    var points = 0.0;
    if (_sentences.length >= widget.step.minSentences) {
      points += 1;
    }
    if (_words >= widget.step.minWords) {
      points += 1;
    }
    if (knownRatio >= 0.7) {
      points += 1;
    }
    points += tidy;
    final score = points / 4;
    if (score >= 0.75) {
      await succeed(score >= 0.95 ? 3 : 2, score: score);
    } else {
      final again = await miss(score: score);
      if (again && mounted) {
        await sayVi(S.writeMoreSentences);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final useKeyboard = widget.step.allowKeyboard && (_keyboard || !services.capabilities.value.ink);
    return Column(
      children: [
        Text(widget.step.promptVi, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (final starter in widget.step.starters)
              ActionChip(
                label: Text(starter, style: const TextStyle(fontSize: 16)),
                onPressed: useKeyboard ? () => setState(() => _typed = '$starter ') : null,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 80, maxHeight: 150),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.ink, width: 2),
          ),
          child: SingleChildScrollView(
            child: Text(
              [..._sentences, if (_typed.isNotEmpty) _typed].join(' '),
              style: const TextStyle(fontFamily: AppTheme.writingFont, fontSize: 24),
            ),
          ),
        ),
        Text('${_sentences.length} / ${widget.step.minSentences} · $_words / ${widget.step.minWords}',
            style: const TextStyle(fontSize: 16)),
        if (useKeyboard) ...[
          const Spacer(),
          BigKeyboard(
            punctuation: true,
            onKey: (k) => setState(() {
              _typed += k;
              if (k == '.' || k == '?' || k == '!') {
                _add(_typed);
                _typed = '';
              }
            }),
            onBackspace: () => setState(() {
              if (_typed.isNotEmpty) {
                _typed = _typed.substring(0, _typed.length - 1);
              } else if (_sentences.isNotEmpty) {
                _typed = _sentences.removeLast();
              }
            }),
            onDone: _finish,
          ),
        ] else ...[
          Expanded(child: InkPad(key: pad, onPause: (_) {}, enabled: !finished)),
          _toolRow(
            onClear: () => pad.currentState?.clear(),
            onCheck: _finish,
            extra: KidIconButton(icon: Icons.add_rounded, label: S.addSentence, onPressed: _addHandwritten),
          ),
          if (widget.step.allowKeyboard)
            TextButton(onPressed: () => setState(() => _keyboard = true), child: const Text(S.keyboard)),
        ],
      ],
    );
  }
}
