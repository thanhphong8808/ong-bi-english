// lib/features/write/write_set_screen.dart
//
// One writing set: look and listen (3-5 words with pictures and IPA), copy
// each word, then the test (write each word from its picture and Bi's voice,
// in a new order), then the result: what the child wrote, stars, and the
// next set when 80 % is reached.
import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/kid_scaffold.dart';
import '../../app/theme.dart';
import '../../core/providers.dart';
import '../../curriculum/lesson_plan.dart';
import '../../curriculum/models.dart';
import '../../curriculum/write_ladder.dart';
import '../../l10n/strings_vi.dart';
import '../../widgets/bi_mascot.dart';
import '../../widgets/item_picture.dart';
import '../../widgets/spoken_text.dart';
import '../daily_lesson/activities/activity_base.dart';
import '../daily_lesson/activities/activity_factory.dart';
import 'write_ladder_screen.dart';

enum _Phase { look, copy, test, result }

class _Answer {
  const _Answer(this.item, this.written, this.score);

  final Item item;
  final String written;

  /// 0..1 letter similarity.
  final double score;

  bool get correct => score >= 0.999;
}

class WriteSetScreen extends ConsumerStatefulWidget {
  const WriteSetScreen({super.key, required this.args});

  final WriteSetArgs args;

  @override
  ConsumerState<WriteSetScreen> createState() => _WriteSetScreenState();
}

class _WriteSetScreenState extends ConsumerState<WriteSetScreen> {
  late final AppServices _services;
  late int _setIndex = widget.args.index;
  _Phase _phase = _Phase.look;
  int _step = 0;
  int _reading = -1;
  List<Item> _testOrder = const [];
  final List<_Answer> _answers = [];
  double _score = 0;
  bool _passed = false;
  int _run = 0;

  WriteSet get _set => widget.args.sets[_setIndex];

  bool get _hasNext => _setIndex + 1 < widget.args.sets.length;

  bool get _ink => _services.capabilities.value.ink;

  @override
  void initState() {
    super.initState();
    _services = ref.read(appServicesProvider);
    _services.studyClock.start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _readAll());
  }

  @override
  void dispose() {
    _services.studyClock.stop();
    unawaited(_services.speech.stop());
    super.dispose();
  }

  /// Bi reads every word once, highlighting it.
  Future<void> _readAll() async {
    final run = _run;
    final settings = ref.read(parentSettingsProvider);
    await _services.speech.sayVi(S.writeLookSpoken).catchError((Object _) {});
    for (var i = 0; i < _set.items.length; i++) {
      if (!mounted || run != _run || _phase != _Phase.look) {
        return;
      }
      setState(() => _reading = i);
      await _services.speech.sayEn(_set.items[i].en, voice: settings.voice, speed: settings.speechRate).catchError((Object _) {});
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    if (mounted && run == _run) {
      setState(() => _reading = -1);
    }
  }

  Future<void> _startCopy() async {
    await _services.speech.stop();
    setState(() {
      _phase = _Phase.copy;
      _step = 0;
      _reading = -1;
    });
  }

  LessonStep _copyStep(Item item) => _ink
      ? CopyWordStep(stage: LessonStage.write, word: item.en, itemId: item.id)
      : WordBuilderStep(stage: LessonStage.write, itemId: item.id, word: item.en);

  LessonStep _testStep(Item item) => _ink
      ? WriteRecallStep(stage: LessonStage.test, itemId: item.id, word: item.en)
      : WordBuilderStep(stage: LessonStage.test, itemId: item.id, word: item.en);

  void _copyDone(StepResult _) {
    if (!mounted) {
      return;
    }
    if (_step + 1 < _set.items.length) {
      setState(() => _step++);
      return;
    }
    setState(() {
      _phase = _Phase.test;
      _step = 0;
      _answers.clear();
      _testOrder = [..._set.items]..shuffle(Random());
    });
    unawaited(_services.speech.sayVi(S.writeTestSpoken).catchError((Object _) {}));
  }

  Future<void> _testDone(StepResult result) async {
    if (!mounted) {
      return;
    }
    final item = _testOrder[_step];
    final score = result.unscored ? 1.0 : result.value.clamp(0.0, 1.0).toDouble();
    _answers.add(_Answer(item, result.answer ?? '', score));
    final profile = await ref.read(activeProfileProvider.future);
    if (!result.unscored) {
      unawaited(_services.progress
          .recordAnswer(profileId: profile.id, itemId: item.id, skill: 'write', correct: score >= 0.999, score: score)
          .catchError((Object _) {}));
    }
    if (_step + 1 < _testOrder.length) {
      if (mounted) {
        setState(() => _step++);
      }
      return;
    }
    await _finish(profile.id);
  }

  Future<void> _finish(int profileId) async {
    final score = _answers.isEmpty ? 0.0 : _answers.map((a) => a.score).reduce((a, b) => a + b) / _answers.length;
    final passed = score >= WriteLadder.passScore;
    await WriteScores.save(_services, profileId, _set.id, score);
    final stars = WriteLadder.stars(score);
    await _services.db.profileRepo.addStars(profileId, stars).catchError((Object _) {});
    if (!mounted) {
      return;
    }
    ref.invalidate(activeProfileProvider);
    setState(() {
      _phase = _Phase.result;
      _score = score;
      _passed = passed;
    });
    await _services.speech.sayVi(passed && _hasNext ? S.writePassedSpoken : S.writeRetrySpoken).catchError((Object _) {});
  }

  void _restart({bool next = false}) {
    setState(() {
      if (next && _hasNext) {
        _setIndex++;
      }
      _run++;
      _phase = _Phase.look;
      _step = 0;
      _answers.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _readAll());
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.look:
        return _look();
      case _Phase.copy:
        return _activity(_copyStep(_set.items[_step]), 'copy', _copyDone, testMode: false);
      case _Phase.test:
        return _activity(_testStep(_testOrder[_step]), 'test', _testDone, testMode: true);
      case _Phase.result:
        return _result();
    }
  }

  Widget _look() {
    return KidScaffold(
      instructionVi: '',
      showBack: true,
      topRight: Text(
        '${_set.group == WriteLadder.parentGroup ? S.writeGroupParent : 'Cấp ${_set.group}'} · ${_set.index + 1}',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              children: [
                for (var i = 0; i < _set.items.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: PictureCard(
                      highlight: i == _reading,
                      onTap: () {
                        final settings = ref.read(parentSettingsProvider);
                        _services.speech
                            .sayEn(_set.items[i].en, voice: settings.voice, speed: settings.speechRate)
                            .catchError((Object _) {});
                      },
                      child: Row(
                        children: [
                          ItemPicture(item: _set.items[i], size: 80),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SpokenText(
                                  _set.items[i].en,
                                  fontSize: 38,
                                  ipa: _set.items[i].ipa.isEmpty ? null : _set.items[i].ipa,
                                  alignment: WrapAlignment.start,
                                ),
                                Text(_set.items[i].vi, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                KidIconButton(
                  icon: Icons.replay_rounded,
                  label: S.listenAgain,
                  onPressed: () {
                    _run++;
                    _readAll();
                  },
                ),
                KidIconButton(
                  icon: Icons.edit_rounded,
                  label: S.writeCopyStart,
                  color: AppColors.leaf,
                  size: 96,
                  onPressed: _startCopy,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _activity(LessonStep step, String tag, StepDone onDone, {required bool testMode}) {
    final total = _phase == _Phase.copy ? _set.items.length : _testOrder.length;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  KidIconButton(icon: Icons.close_rounded, size: 56, onPressed: () => Navigator.of(context).maybePop()),
                  const SizedBox(width: 12),
                  EmojiText(_phase == _Phase.copy ? '✏️' : '📝', size: 30),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (_step + 1) / total,
                        minHeight: 14,
                        color: _phase == _Phase.copy ? AppColors.honeyDeep : AppColors.grape,
                        backgroundColor: AppColors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${_step + 1}/$total', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: buildActivity(step, key: ValueKey('$_run-$tag-$_setIndex-$_step'), onDone: onDone, testMode: testMode),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _result() {
    final level = ref.watch(activeProfileProvider).value?.level ?? 0;
    final stars = WriteLadder.stars(_score);
    return KidScaffold(
      instructionVi: '',
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Center(child: BiMascot(mood: _passed ? BiMood.cheering : BiMood.happy, size: 130, level: level)),
          const Center(child: Text(S.writeResultTitle, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900))),
          const SizedBox(height: 6),
          Center(child: StarRow(stars: stars, size: 48)),
          Center(
            child: Text('${(_score * 100).round()}%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          ),
          if (_passed && _hasNext) const Center(child: EmojiText('🔓', size: 48)),
          const SizedBox(height: 10),
          for (final a in _answers)
            Card(
              color: AppColors.white,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    ItemPicture(item: a.item, size: 56),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.item.en,
                            style: const TextStyle(fontFamily: AppTheme.writingFont, fontSize: 30, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            S.writeYouWrote(a.written.trim().isEmpty ? S.writeNothing : a.written.trim()),
                            style: TextStyle(
                              fontFamily: AppTheme.writingFont,
                              fontSize: 18,
                              color: a.correct ? AppColors.ink : const Color(0xFFB5452B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      a.correct ? Icons.check_circle_rounded : Icons.edit_note_rounded,
                      color: a.correct ? AppColors.leaf : AppColors.honeyDeep,
                      size: 40,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 18,
            runSpacing: 12,
            children: [
              KidIconButton(icon: Icons.replay_rounded, label: S.writeAgain, onPressed: _restart),
              if (_passed && _hasNext)
                KidIconButton(
                  icon: Icons.arrow_forward_rounded,
                  label: S.writeNextSet,
                  color: AppColors.leaf,
                  size: 88,
                  onPressed: () => _restart(next: true),
                ),
              KidIconButton(icon: Icons.grid_view_rounded, label: S.writeBack, onPressed: () => Navigator.of(context).maybePop()),
            ],
          ),
        ],
      ),
    );
  }
}
