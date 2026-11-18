// lib/features/grammar/grammar_practice_screen.dart
//
// One grammar lesson: Bi explains in Vietnamese (with a table and examples
// the child can tap to hear), then practice: pick the missing word, or tap
// the words in the right order. Every answer gets a short reason in
// Vietnamese. The score is saved as a test result ("grammar"), so it shows
// in the test centre and the parent's progress. Also used for the mixed
// grammar test, which skips the explanation.
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/kid_scaffold.dart';
import '../../app/theme.dart';
import '../../core/providers.dart';
import '../../curriculum/grammar.dart';
import '../../l10n/strings_vi.dart';
import '../../widgets/bi_mascot.dart';
import '../../widgets/item_picture.dart';
import '../../widgets/ui_kit.dart';

class GrammarPracticeArgs {
  const GrammarPracticeArgs._({required this.title, required this.targetId, required this.tasks, this.lesson});

  factory GrammarPracticeArgs.lesson(GrammarLesson lesson) => GrammarPracticeArgs._(
        title: lesson.titleVi,
        targetId: lesson.id,
        tasks: [for (final t in lesson.practice) t.withLesson(lesson.id)],
        lesson: lesson,
      );

  factory GrammarPracticeArgs.mixed(GrammarBook book, {List<String> fromLessons = const []}) =>
      GrammarPracticeArgs._(
        title: S.grammarQuiz,
        targetId: mixedId,
        tasks: book.mixedTest(fromLessons: fromLessons),
      );

  /// Test result kind and the target id of the mixed test.
  static const String resultKind = 'grammar';
  static const String mixedId = 'GMIX';

  final String title;
  final String targetId;
  final List<GrammarTask> tasks;

  /// The lesson to explain first; null for the mixed test.
  final GrammarLesson? lesson;
}

enum _Phase { learn, practice, result }

class GrammarPracticeScreen extends ConsumerStatefulWidget {
  const GrammarPracticeScreen({super.key, required this.args});

  final GrammarPracticeArgs args;

  @override
  ConsumerState<GrammarPracticeScreen> createState() => _GrammarPracticeScreenState();
}

class _GrammarPracticeScreenState extends ConsumerState<GrammarPracticeScreen> {
  late final AppServices _services = ref.read(appServicesProvider);
  final Random _random = Random();
  late _Phase _phase = widget.args.lesson == null ? _Phase.practice : _Phase.learn;
  late List<GrammarTask> _tasks = widget.args.tasks;
  int _index = 0;
  int _right = 0;
  final List<String> _wrongLessons = [];

  // Current question.
  String? _picked;
  bool _answered = false;
  bool _correct = false;
  List<int> _bank = [];
  List<int> _chosen = [];
  List<String> _bankWords = [];

  @override
  void initState() {
    super.initState();
    _services.studyClock.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_phase == _Phase.learn) {
        unawaited(_explain());
      } else {
        _startQuestion();
      }
    });
  }

  @override
  void dispose() {
    _services.studyClock.stop();
    unawaited(_services.speech.stop());
    super.dispose();
  }

  double get _rate => ref.read(parentSettingsProvider).speechRate;

  Future<void> _sayVi(String text) => _services.speech.sayVi(text, speed: _rate).catchError((Object _) {});

  Future<void> _sayEn(String text) => _services.speech
      .sayEn(text, voice: ref.read(parentSettingsProvider).voice, speed: _rate)
      .catchError((Object _) {});

  /// Bi reads the explanation, one sentence after another.
  Future<void> _explain() async {
    final lesson = widget.args.lesson;
    if (lesson == null) {
      return;
    }
    for (final line in lesson.explainVi) {
      if (!mounted || _phase != _Phase.learn) {
        return;
      }
      await _sayVi(line);
    }
  }

  void _startPractice() {
    unawaited(_services.speech.stop());
    setState(() {
      _phase = _Phase.practice;
      _index = 0;
      _right = 0;
      _wrongLessons.clear();
    });
    _startQuestion();
  }

  void _startQuestion() {
    if (_tasks.isEmpty) {
      return;
    }
    final task = _tasks[_index];
    setState(() {
      _picked = null;
      _answered = false;
      _correct = false;
      _chosen = [];
      if (task.kind == GrammarTaskKind.order) {
        _bankWords = task.words;
        _bank = List<int>.generate(task.words.length, (i) => i)..shuffle(_random);
        // Never start already in order.
        if (_bank.length > 1 && List<int>.generate(_bank.length, (i) => i).join() == _bank.join()) {
          _bank = _bank.reversed.toList();
        }
      } else {
        _bankWords = [...task.options]..shuffle(_random);
        _bank = [];
      }
    });
    final first = _index == 0 || _tasks[_index - 1].kind != task.kind;
    if (first) {
      unawaited(_sayVi(task.kind == GrammarTaskKind.order ? S.grammarOrderSpoken : S.grammarChooseSpoken));
    }
  }

  Future<void> _answer(bool correct) async {
    final task = _tasks[_index];
    setState(() {
      _answered = true;
      _correct = correct;
      if (correct) {
        _right++;
      } else if (task.lessonId.isNotEmpty) {
        _wrongLessons.add(task.lessonId);
      }
    });
    if (correct) {
      await _sayVi(S.praiseGrammar[_random.nextInt(S.praiseGrammar.length)]);
    } else {
      await _sayVi(task.whyVi.isEmpty ? S.grammarWrong : S.grammarWhySpoken(task.whyVi));
    }
    if (mounted && _answered) {
      await _sayEn(task.sentence);
    }
  }

  void _pick(String option) {
    if (_answered) {
      return;
    }
    setState(() => _picked = option);
    unawaited(_answer(option == _tasks[_index].answer));
  }

  void _tapBank(int position) {
    if (_answered) {
      return;
    }
    setState(() {
      _chosen = [..._chosen, _bank[position]];
      _bank = [..._bank]..removeAt(position);
    });
    if (_bank.isEmpty) {
      final task = _tasks[_index];
      unawaited(_answer(task.orderIsRight([for (final i in _chosen) _bankWords[i]])));
    }
  }

  void _tapChosen(int position) {
    if (_answered) {
      return;
    }
    setState(() {
      _bank = [..._bank, _chosen[position]];
      _chosen = [..._chosen]..removeAt(position);
    });
  }

  Future<void> _next() async {
    unawaited(_services.speech.stop());
    if (_index + 1 < _tasks.length) {
      setState(() => _index++);
      _startQuestion();
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    final total = _tasks.length;
    final score = grammarScore(_right, total);
    setState(() => _phase = _Phase.result);
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      final profile = await ref.read(activeProfileProvider.future);
      await _services.db.testRepo.add(
        profile.id,
        kind: GrammarPracticeArgs.resultKind,
        targetId: widget.args.targetId,
        score: score,
        passed: score >= 0.6,
        detailJson: jsonEncode({
          'total': score,
          'right': _right,
          'count': total,
          'sections': {'grammar': score},
          'wrongLessons': _wrongLessons.toSet().toList(),
        }),
      );
      await _services.db.profileRepo.addStars(profile.id, _right);
      container.invalidate(activeProfileProvider);
    } catch (_) {
      // The result screen still shows; only the history misses this round.
    }
    await _sayVi(S.grammarResultSpoken(_right, total));
  }

  void _again() {
    final lesson = widget.args.lesson;
    if (lesson == null) {
      // A new mix of questions for the mixed test.
      unawaited(_services.grammarBook().then((book) {
        if (mounted) {
          setState(() => _tasks = book.mixedTest());
          _startPractice();
        }
      }));
      return;
    }
    _startPractice();
  }

  @override
  Widget build(BuildContext context) {
    final level = ref.watch(activeProfileProvider).value?.level ?? 0;
    return KidScaffold(
      instructionVi: '',
      showBack: true,
      topRight: _phase == _Phase.practice && _tasks.isNotEmpty
          ? StatPill(emoji: '📝', text: S.grammarQuestion(_index + 1, _tasks.length))
          : null,
      child: switch (_phase) {
        _Phase.learn => _learn(level),
        _Phase.practice => _tasks.isEmpty ? const SizedBox.shrink() : _practice(),
        _Phase.result => _result(level),
      },
    );
  }

  // ---------------------------------------------------------------- learn

  Widget _learn(int level) {
    final lesson = widget.args.lesson!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            BiMascot(mood: BiMood.thinking, size: 96, level: level),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lesson.titleVi, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, height: 1.2)),
                  Text(lesson.titleEn,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
                ],
              ),
            ),
          ],
        ),
        SectionTitle(S.grammarLearn,
            trailing: RoundIconButton(
              icon: Icons.volume_up_rounded,
              semanticLabel: S.listenAgain,
              onPressed: () {
                unawaited(_services.speech.stop().then((_) => _explain()));
              },
            )),
        SoftCard(
          color: AppColors.honeySoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in lesson.explainVi)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🐝 ', style: TextStyle(fontSize: 16)),
                      Expanded(
                        child: Text(line, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.3)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (lesson.tableRows.isNotEmpty) ...[
          const SizedBox(height: 14),
          _GrammarTable(head: lesson.tableHead, rows: lesson.tableRows, onTapRow: _sayRow),
        ],
        const SectionTitle(S.grammarExamples),
        for (final e in lesson.examples)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SoftCard(
              semanticLabel: e.en,
              onTap: () => unawaited(_sayEn(e.en)),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.volume_up_rounded, color: AppColors.honeyDeep),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.en, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        Text(e.vi, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        Center(
          child: PillButton(
            label: S.grammarStartPractice,
            icon: Icons.play_arrow_rounded,
            big: true,
            onPressed: _startPractice,
          ),
        ),
      ],
    );
  }

  /// Reads the English cells of a table row (a sentence if there is one).
  void _sayRow(List<String> row) {
    final english = row.where((c) => RegExp(r'^[A-Za-z]').hasMatch(c) && !_looksVietnamese(c)).toList();
    if (english.isEmpty) {
      return;
    }
    final sentence = english.where((c) => c.endsWith('.') || c.endsWith('?')).toList();
    unawaited(_sayEn(sentence.isNotEmpty ? sentence.last.split(' / ').first : english.join(', ').replaceAll(' / ', ', ')));
  }

  static bool _looksVietnamese(String s) =>
      RegExp(r'[àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ]', caseSensitive: false)
          .hasMatch(s);

  // ------------------------------------------------------------- practice

  Widget _practice() {
    final task = _tasks[_index];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(widget.args.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.inkSoft)),
        const SizedBox(height: 8),
        SoftProgress(value: (_index + (_answered ? 1 : 0)) / _tasks.length),
        const SizedBox(height: 16),
        if (task.kind == GrammarTaskKind.choose) ..._choose(task) else ..._order(task),
        if (_answered) ...[
          const SizedBox(height: 16),
          _Feedback(correct: _correct, task: task, onListen: () => unawaited(_sayEn(task.sentence))),
          const SizedBox(height: 16),
          Center(
            child: PillButton(
              label: _index + 1 < _tasks.length ? S.grammarNext : S.grammarDone,
              icon: Icons.arrow_forward_rounded,
              big: true,
              onPressed: _next,
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _choose(GrammarTask task) {
    final parts = task.questionText.split('___');
    return [
      SoftCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(children: [
                for (var i = 0; i < parts.length; i++) ...[
                  TextSpan(text: parts[i]),
                  if (i < parts.length - 1)
                    const TextSpan(
                      text: ' ____ ',
                      style: TextStyle(color: AppColors.honeyDeep, fontWeight: FontWeight.w900),
                    ),
                ],
              ]),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.35),
            ),
            if (task.hint.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('💡 ${task.hint}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.grape)),
              ),
            const SizedBox(height: 6),
            Text(task.vi, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: [
          for (final option in _bankWords)
            _OptionButton(
              label: option,
              state: !_answered
                  ? _OptionState.idle
                  : option == task.answer
                      ? _OptionState.right
                      : option == _picked
                          ? _OptionState.wrong
                          : _OptionState.dim,
              onTap: () => _pick(option),
            ),
        ],
      ),
    ];
  }

  List<Widget> _order(GrammarTask task) {
    return [
      SoftCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🇻🇳 ${task.vi}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, height: 1.3)),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(minHeight: 64),
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: !_answered ? AppColors.line : (_correct ? AppColors.leaf : AppColors.berry),
                  width: 2,
                ),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _chosen.length; i++)
                    _WordChip(word: _bankWords[_chosen[i]], filled: true, onTap: () => _tapChosen(i)),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: [
          for (var i = 0; i < _bank.length; i++)
            _WordChip(word: _bankWords[_bank[i]], filled: false, onTap: () => _tapBank(i)),
        ],
      ),
    ];
  }

  // --------------------------------------------------------------- result

  Widget _result(int level) {
    final total = _tasks.length;
    final score = grammarScore(_right, total);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BiMascot(mood: score >= 0.6 ? BiMood.cheering : BiMood.happy, size: 200, level: level),
            Text(widget.args.title,
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            StarRow(stars: grammarStars(score), size: 52),
            const SizedBox(height: 8),
            Text(S.percent(score), style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: AppColors.honeyDeep)),
            Text(S.grammarScore(_right, total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 24),
            Wrap(
              spacing: 14,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                PillButton(label: S.grammarAgain, icon: Icons.replay_rounded, color: AppColors.skySoft, onPressed: _again),
                PillButton(label: S.grammarDone, icon: Icons.check_rounded, onPressed: () => Navigator.of(context).maybePop()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GrammarTable extends StatelessWidget {
  const _GrammarTable({required this.head, required this.rows, required this.onTapRow});

  final List<String> head;
  final List<List<String>> rows;
  final void Function(List<String> row) onTapRow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (head.any((h) => h.isNotEmpty))
            Container(
              color: AppColors.honey,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  for (final h in head)
                    Expanded(child: Text(h, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900))),
                ],
              ),
            ),
          for (var r = 0; r < rows.length; r++)
            Material(
              color: r.isEven ? AppColors.white : AppColors.cream,
              child: InkWell(
                onTap: () => onTapRow(rows[r]),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Row(
                    children: [
                      for (var c = 0; c < rows[r].length; c++)
                        Expanded(
                          child: Text(
                            rows[r][c],
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: c == 0 ? FontWeight.w900 : FontWeight.w700,
                              color: c == 0 ? AppColors.ink : AppColors.inkSoft,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _OptionState { idle, right, wrong, dim }

class _OptionButton extends StatelessWidget {
  const _OptionButton({required this.label, required this.state, required this.onTap});

  final String label;
  final _OptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _OptionState.idle => AppColors.white,
      _OptionState.right => AppColors.leafSoft,
      _OptionState.wrong => AppColors.berrySoft,
      _OptionState.dim => AppColors.cream,
    };
    final border = switch (state) {
      _OptionState.idle => AppColors.honey,
      _OptionState.right => AppColors.leaf,
      _OptionState.wrong => AppColors.berry,
      _OptionState.dim => AppColors.line,
    };
    return Semantics(
      button: true,
      container: true,
      label: label,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 120, minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border, width: 3),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (state == _OptionState.right) const Text('✅ ', style: TextStyle(fontSize: 18)),
                if (state == _OptionState.wrong) const Text('❌ ', style: TextStyle(fontSize: 18)),
                Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  const _WordChip({required this.word, required this.filled, required this.onTap});

  final String word;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      container: true,
      label: word,
      child: Material(
        color: filled ? AppColors.honey : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: filled ? AppColors.honeyDeep : AppColors.line, width: 2),
            ),
            child: Text(word, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          ),
        ),
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({required this.correct, required this.task, required this.onListen});

  final bool correct;
  final GrammarTask task;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: correct ? AppColors.leafSoft : AppColors.berrySoft,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EmojiText(correct ? '🎉' : '💡', size: 30),
              const SizedBox(width: 8),
              Text(correct ? S.grammarRight : S.grammarWrong,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const Spacer(),
              RoundIconButton(icon: Icons.volume_up_rounded, semanticLabel: S.listenAgain, onPressed: onListen),
            ],
          ),
          const SizedBox(height: 6),
          Text(task.sentence, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          Text(task.vi, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
          if (!correct && task.whyVi.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('🐝 ${task.whyVi}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }
}
