// lib/features/daily_lesson/activities/dialogue_activity.dart
//
// Everyday dialogues in four steps: 1 listen (two voices), 2 shadow each
// line, 3 role-play (the app reads the other part), 4 variation (swap a key
// word for another learned word).
import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../core/services/english_voice.dart';
import '../../../curriculum/lesson_plan.dart';
import '../../../curriculum/models.dart';
import '../../../l10n/strings_vi.dart';
import '../../../widgets/bi_mascot.dart';
import '../../../widgets/item_picture.dart';
import '../../../widgets/spoken_text.dart';
import '../../speak/mic_panel.dart';
import 'activity_base.dart';

const Map<String, String> _roleEmoji = {
  'kid': '🧒',
  'mum': '👩',
  'mom': '👩',
  'dad': '👨',
  'teacher': '👩‍🏫',
  'shopkeeper': '🧑‍💼',
  'seller': '🧑‍💼',
  'doctor': '🧑‍⚕️',
  'nurse': '🧑‍⚕️',
  'waiter': '🧑‍🍳',
  'friend': '🧒',
  'grandma': '👵',
  'grandpa': '👴',
  'tom': '👦',
  'nam': '👦',
  'ben': '👦',
  'lan': '👧',
  'mai': '👧',
  'anna': '👧',
  'driver': '🧑‍✈️',
  'librarian': '🧑‍🏫',
  'man': '👨',
  'woman': '👩',
};

class DialogueActivity extends ActivityView<DialogueStep> {
  const DialogueActivity({super.key, required super.step, required super.onDone, super.testMode});

  @override
  ActivityState<DialogueActivity> createState() => _DialogueState();
}

class _DialogueState extends ActivityState<DialogueActivity> {
  late final Dialogue? _dialogue = curriculum.dialogue(widget.step.dialogueId);
  final GlobalKey<MicPanelState> _mic = GlobalKey<MicPanelState>();

  int _line = -1;
  String? _kidRole;
  bool _waitingForKid = false;
  bool _listenDone = false;
  final List<int> _stars = [];
  int _variant = 0;
  final Map<int, GlobalKey> _lineKeys = {};

  GlobalKey _keyFor(int line) => _lineKeys.putIfAbsent(line, GlobalKey.new);

  /// Keeps the line being read on screen (lines are taller with IPA).
  void _showLine(int line) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _lineKeys[line]?.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(ctx, alignment: 0.3, duration: const Duration(milliseconds: 250));
      }
    });
  }

  int get _stage => widget.step.dialogueStage;

  @override
  String get instructionVi {
    switch (_stage) {
      case 1:
        return S.insDialogueListen;
      case 2:
        return S.insDialogueShadow;
      case 3:
        return S.insDialogueRole;
      default:
        return S.insDialogueVariation;
    }
  }

  EnglishVoice _voiceFor(String role) {
    final roles = _dialogue?.roles ?? const <String>[];
    final first = roles.isNotEmpty && role == roles.first;
    return first ? voice : voice.partner;
  }

  @override
  Future<void> onOpened() async {
    final d = _dialogue;
    if (d == null || d.lines.isEmpty) {
      complete();
      return;
    }
    switch (_stage) {
      case 1:
        await _playAll();
      case 2:
        await _shadowLine(0);
      case 3:
        // The child picks a role first (buttons on screen).
        break;
      default:
        await _playVariant();
    }
  }

  Future<void> _playAll() async {
    final d = _dialogue!;
    for (var i = 0; i < d.lines.length; i++) {
      if (!mounted) {
        return;
      }
      setState(() => _line = i);
      _showLine(i);
      await sayEn(d.lines[i].en, as: _voiceFor(d.lines[i].role));
    }
    if (mounted) {
      setState(() {
        _line = -1;
        _listenDone = true;
      });
    }
  }

  // ---- Stage 2: shadowing ----
  Future<void> _shadowLine(int index) async {
    final d = _dialogue!;
    if (index >= d.lines.length) {
      _finish();
      return;
    }
    setState(() {
      _line = index;
      _waitingForKid = true;
    });
    _showLine(index);
    _mic.currentState?.reset();
    await sayEn(d.lines[index].en, as: _voiceFor(d.lines[index].role));
  }

  // ---- Stage 3: role-play ----
  Future<void> _chooseRole(String role) async {
    setState(() => _kidRole = role);
    await _rolePlayFrom(0);
  }

  Future<void> _rolePlayFrom(int index) async {
    final d = _dialogue!;
    var i = index;
    while (i < d.lines.length && mounted) {
      final line = d.lines[i];
      setState(() => _line = i);
      _showLine(i);
      if (line.role == _kidRole) {
        setState(() => _waitingForKid = true);
        _mic.currentState?.reset();
        return;
      }
      await sayEn(line.en, as: _voiceFor(line.role));
      i++;
    }
    if (mounted) {
      _finish();
    }
  }

  // ---- Stage 4: variation ----
  List<String> get _variantSentences {
    final d = _dialogue!;
    final v = d.variation;
    if (v == null || v.line >= d.lines.length) {
      return [d.lines.last.en];
    }
    final base = d.lines[v.line].en;
    return [
      for (final option in v.options.take(2))
        base.replaceAll(RegExp('\\b${RegExp.escape(v.key)}\\b', caseSensitive: false), option),
    ];
  }

  Future<void> _playVariant() async {
    final sentences = _variantSentences;
    if (_variant >= sentences.length) {
      _finish();
      return;
    }
    setState(() => _waitingForKid = true);
    _mic.currentState?.reset();
    await sayEn(sentences[_variant]);
  }

  String get _currentTarget {
    final d = _dialogue!;
    if (_stage == 4) {
      final sentences = _variantSentences;
      return _variant < sentences.length ? sentences[_variant] : '';
    }
    return _line >= 0 && _line < d.lines.length ? d.lines[_line].en : '';
  }

  Future<void> _onSpoken(MicOutcome outcome) async {
    _stars.add(outcome.score?.stars ?? 2);
    setState(() => _waitingForKid = false);
    if (outcome.score != null && outcome.score!.passed) {
      await sayVi(S.praiseLines[ActivityState.random.nextInt(S.praiseLines.length)]);
    } else if (outcome.score != null) {
      await sayEn(_currentTarget, slow: true);
    }
    if (!mounted) {
      return;
    }
    switch (_stage) {
      case 2:
        await _shadowLine(_line + 1);
      case 3:
        await _rolePlayFrom(_line + 1);
      default:
        _variant++;
        await _playVariant();
    }
  }

  void _finish() {
    if (finished) {
      return;
    }
    final average = _stars.isEmpty ? 2 : (_stars.reduce((a, b) => a + b) / _stars.length).round();
    complete(StepResult(correct: average >= 1, stars: average.clamp(1, 3).toInt()));
  }

  Widget _avatar(String role, {double size = 56}) {
    if (role.toLowerCase() == 'bi') {
      return BiMascot(size: size * 1.3, mood: BiMood.happy);
    }
    return EmojiText(_roleEmoji[role.toLowerCase()] ?? '🙂', size: size);
  }

  Widget _lineRow(Dialogue d, int i) {
    final line = d.lines[i];
    final left = d.roles.isNotEmpty && line.role == d.roles.first;
    final active = i == _line;
    final bubble = Flexible(
      child: GestureDetector(
        onTap: () => sayEn(line.en, as: _voiceFor(line.role)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.cream : AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? AppColors.honeyDeep : AppColors.ink, width: active ? 4 : 1.5),
          ),
          child: hideText
              ? const Icon(Icons.volume_up_rounded, size: 36)
              : SpokenText(
                  line.en,
                  fontSize: 24,
                  alignment: WrapAlignment.start,
                  voice: _voiceFor(line.role),
                ),
        ),
      ),
    );
    return Row(
      mainAxisAlignment: left ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: left
          ? [_avatar(line.role, size: 44), bubble]
          : [bubble, _avatar(line.role, size: 44)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _dialogue;
    if (d == null) {
      return const SizedBox.shrink();
    }
    final kidRole = _kidRole;
    if (_stage == 3 && kidRole == null) {
      return Column(
        children: [
          Text(d.titleVi, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              children: [
                for (final role in d.roles)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: PictureCard(
                        onTap: () => _chooseRole(role),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _avatar(role, size: 90),
                            const SizedBox(height: 8),
                            Text(role, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    if (_stage == 4) {
      final v = d.variation;
      final sentences = _variantSentences;
      final option = v != null && _variant < v.options.length ? v.options[_variant] : null;
      final picture = option == null ? null : curriculum.itemByWord(option);
      return Column(
        children: [
          Text(d.titleVi, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (picture != null) ItemPicture(item: picture, size: 150),
                const SizedBox(height: 12),
                if (!hideText && _variant < sentences.length)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SpokenText(sentences[_variant], fontSize: 34),
                  ),
              ],
            ),
          ),
          MicPanel(
            key: _mic,
            target: _currentTarget,
            sentence: true,
            enabled: _waitingForKid,
            onPlayModel: () => sayEn(_currentTarget),
            onResult: _onSpoken,
          ),
          const SizedBox(height: 12),
        ],
      );
    }

    return Column(
      children: [
        Text(d.titleVi, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (var i = 0; i < d.lines.length; i++) KeyedSubtree(key: _keyFor(i), child: _lineRow(d, i)),
              ],
            ),
          ),
        ),
        if (_stage == 1)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                KidIconButton(icon: Icons.replay_rounded, label: S.listenAgain, onPressed: _listenDone ? _playAll : null),
                KidIconButton(
                  icon: Icons.arrow_forward_rounded,
                  label: S.next,
                  color: AppColors.leaf,
                  size: 84,
                  onPressed: _listenDone ? _finish : null,
                ),
              ],
            ),
          )
        else ...[
          MicPanel(
            key: _mic,
            target: _currentTarget,
            sentence: true,
            enabled: _waitingForKid,
            onPlayModel: _line >= 0 ? () => sayEn(_currentTarget, as: _voiceFor(d.lines[_line].role)) : null,
            onResult: _onSpoken,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
