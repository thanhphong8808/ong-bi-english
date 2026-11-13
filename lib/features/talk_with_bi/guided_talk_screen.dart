// lib/features/talk_with_bi/guided_talk_screen.dart
//
// Plays a guided chat, role-play or story: Bi (and the characters) speak in
// English with the Vietnamese meaning under every line (and read aloud when
// "VI" is on); on the child's turn 1-3 answers are shown with pictures, Bi
// reads them, and the child says one into the microphone. Whichever answer
// the child says decides how the talk goes on.
import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../core/config/app_config.dart';
import '../../core/db/repositories.dart';
import '../../core/providers.dart';
import '../../core/services/audio_request.dart';
import '../../core/services/english_voice.dart';
import '../../curriculum/scorers/pronunciation_scorer.dart';
import '../../curriculum/skill_map.dart';
import '../../curriculum/talk_scripts.dart';
import '../../l10n/strings_vi.dart';
import '../../widgets/bi_mascot.dart';
import '../../widgets/item_picture.dart';
import '../../widgets/spoken_text.dart';
import '../../widgets/story_art.dart';
import '../../widgets/ui_kit.dart';
import '../daily_lesson/activities/activity_base.dart';
import '../speak/mic_panel.dart';
import 'talk_home_screen.dart';

class _Bubble {
  const _Bubble(this.role, this.en, this.vi, {this.fromKid = false});

  final String role;
  final String en;
  final String vi;
  final bool fromKid;
}

class _Turn {
  _Turn(this.options, {required this.repeat});

  final List<TalkOption> options;

  /// One line to say after Bi (role-play lines, "say it with me").
  final bool repeat;
  final Completer<TalkOption?> done = Completer<TalkOption?>();
  final DateTime openedAt = DateTime.now();
  int misses = 0;

  /// The child tapped the microphone or an answer: stop reading answers.
  bool quiet = false;

  /// After two misses (or without speech recognition) a tap chooses.
  bool tapToChoose = false;
  int selected = 0;
}

class GuidedTalkScreen extends ConsumerStatefulWidget {
  const GuidedTalkScreen({super.key, required this.args});

  final GuidedTalkArgs args;

  @override
  ConsumerState<GuidedTalkScreen> createState() => _GuidedTalkScreenState();
}

class _GuidedTalkScreenState extends ConsumerState<GuidedTalkScreen> {
  late final AppServices _services;
  final List<_Bubble> _bubbles = [];
  final ScrollController _scroll = ScrollController();
  final GlobalKey<MicPanelState> _mic = GlobalKey<MicPanelState>();
  final Random _random = Random();
  final String _sessionId = 'guided-${DateTime.now().millisecondsSinceEpoch}';

  late String _scene = widget.args.script.emoji;

  /// Story illustration on screen (0 = cover).
  int _sceneIndex = 0;
  _Turn? _turn;
  bool _vietnamese = true;
  bool _finished = false;
  bool _firstTurnSpoken = false;
  int _run = 0;
  int? _profileId;

  TalkScript get _script => widget.args.script;
  String get _kid => widget.args.kidRole;

  @override
  void initState() {
    super.initState();
    _services = ref.read(appServicesProvider);
    _services.studyClock.start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _run++;
    final turn = _turn;
    if (turn != null && !turn.done.isCompleted) {
      turn.done.complete(null);
    }
    _scroll.dispose();
    _services.studyClock.stop();
    unawaited(_services.speech.stop());
    super.dispose();
  }

  EnglishVoice get _voice => ref.read(parentSettingsProvider).voice;

  double get _speed => ref.read(slowModeProvider) ? AppConfig.slowSpeechRate : AppConfig.normalSpeechRate;

  /// Bi and the child's model lines use the parent's voice; the other
  /// characters the partner voice, so two speakers sound different.
  EnglishVoice _voiceFor(String role) => role == TalkScript.biRole || role == _kid ? _voice : _voice.partner;

  bool get _alive => mounted && !_finished;

  Future<void> _start() async {
    final profile = await ref.read(activeProfileProvider.future);
    if (!mounted) {
      return;
    }
    _profileId = profile.id;
    setState(() => _vietnamese = profile.level <= 2);
    // Render every line ahead, so Bi answers without waiting.
    final requests = <AudioRequest>[];
    for (final block in _script.blocks.values) {
      for (final item in block.items) {
        if (item is TalkLine) {
          requests.add(AudioRequest.en(item.en, voice: _voiceFor(item.role), speed: _speed));
          requests.add(AudioRequest.vi(item.vi));
        }
      }
      for (final option in block.choice?.options ?? const <TalkOption>[]) {
        requests.add(AudioRequest.en(option.en, voice: _voiceFor(block.choice!.role), speed: _speed));
      }
    }
    _services.audioCache.prewarm(requests);
    await _runFrom(_script.startId);
  }

  Future<void> _say(String role, String en, String vi) async {
    await _services.speech.sayEn(en, voice: _voiceFor(role), speed: _speed).catchError((Object _) {});
    if (_vietnamese && vi.isNotEmpty && _alive) {
      await _services.speech.sayVi(vi).catchError((Object _) {});
    }
  }

  void _add(_Bubble bubble) {
    setState(() => _bubbles.add(bubble));
    // The list is reversed (newest at the bottom, kept in view when the
    // answer panel opens); bring the child back down to the new line.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients && _scroll.offset > 0) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
    final profileId = _profileId;
    if (profileId != null) {
      unawaited(_services.db.chatLogRepo
          .add(
            profileId: profileId,
            sessionId: _sessionId,
            role: bubble.fromKid ? 'kid' : 'bi',
            content: bubble.en,
          )
          .catchError((Object _) => 0));
    }
  }

  Future<void> _runFrom(String startId) async {
    final run = _run;
    var id = startId;
    while (_alive && run == _run && id != TalkScript.end) {
      final block = _script.blocks[id];
      if (block == null) {
        break;
      }
      for (final item in block.items) {
        if (!_alive || run != _run) {
          return;
        }
        switch (item) {
          case TalkPicture():
            setState(() => _scene = item.emoji);
          case TalkScene():
            setState(() => _sceneIndex = item.index);
          case TalkLine():
            if (item.role == _kid) {
              final said = await _kidTurn([
                TalkOption(emoji: _script.role(_kid)?.emoji ?? '🧒', en: item.en, vi: item.vi),
              ], repeat: true);
              if (said == null) {
                return;
              }
            } else {
              _add(_Bubble(item.role, item.en, item.vi));
              await _say(item.role, item.en, item.vi);
            }
        }
      }
      if (!_alive || run != _run) {
        return;
      }
      final choice = block.choice;
      if (choice == null) {
        id = block.after;
        continue;
      }
      TalkOption? option;
      if (choice.role == _kid) {
        option = await _kidTurn(choice.options, repeat: false);
        if (option == null) {
          return;
        }
        widget.args.onChoice?.call(block.id, option);
      } else {
        option = choice.options[_random.nextInt(choice.options.length)];
        _add(_Bubble(choice.role, option.en, option.vi));
        await _say(choice.role, option.en, option.vi);
      }
      id = optionTarget(block, option);
    }
    if (_alive && run == _run) {
      await _finish();
    }
  }

  /// The child's turn: show the answers, read them, wait for the child.
  Future<TalkOption?> _kidTurn(List<TalkOption> options, {required bool repeat}) async {
    final turn = _Turn(options, repeat: repeat);
    turn.tapToChoose = !_services.capabilities.value.speech;
    setState(() => _turn = turn);
    _mic.currentState?.reset();
    final first = !_firstTurnSpoken;
    _firstTurnSpoken = true;
    unawaited(() async {
      if (first || turn.tapToChoose) {
        await _services.speech
            .sayVi(turn.tapToChoose ? S.talkTapToChooseSpoken : (repeat ? S.talkSayThisSpoken : S.talkYourTurnSpoken))
            .catchError((Object _) {});
      }
      bool reading() => mounted && _turn == turn && !turn.done.isCompleted && !turn.quiet;
      if (repeat) {
        // The meaning first, then the English to say, so the last thing the
        // child hears is what to repeat.
        if (_vietnamese && reading()) {
          await _services.speech.sayVi(options.first.vi).catchError((Object _) {});
        }
        if (reading()) {
          await _services.speech.sayEn(options.first.en, voice: _voice, speed: _speed).catchError((Object _) {});
        }
        return;
      }
      // Read the answers so a child who cannot read yet knows them.
      for (var i = 0; i < options.length; i++) {
        if (!reading()) {
          return;
        }
        setState(() => turn.selected = i);
        await _services.speech.sayEn(options[i].en, voice: _voice, speed: _speed).catchError((Object _) {});
        if (_vietnamese && reading()) {
          await _services.speech.sayVi(options[i].vi).catchError((Object _) {});
        }
      }
    }());
    return turn.done.future;
  }

  void _accept(_Turn turn, TalkOption option, {String heard = '', int speechMs = 0, int latencyMs = -1}) {
    if (turn.done.isCompleted) {
      return;
    }
    unawaited(_services.speech.stop());
    _add(_Bubble(_kid, option.en, option.vi, fromKid: true));
    final profileId = _profileId;
    if (profileId != null && heard.isNotEmpty) {
      final elapsed = DateTime.now().difference(turn.openedAt).inMilliseconds;
      final reaction = elapsed - speechMs - (latencyMs < 0 ? 0 : latencyMs);
      unawaited(_services.db.speechTurnRepo
          .add(
            profileId,
            SpeechTurn(
              source: SpeechTurn.talk,
              at: DateTime.now(),
              responseMs: reaction >= 0 && reaction <= AppConfig.maxResponseMs ? reaction : -1,
              speechMs: speechMs,
              words: englishWordCount(heard),
              latencyMs: latencyMs,
            ),
          )
          .catchError((Object _) {}));
    }
    setState(() => _turn = null);
    turn.done.complete(option);
  }

  Future<void> _tapOption(_Turn turn, int index) async {
    if (turn.done.isCompleted) {
      return;
    }
    turn.quiet = true;
    setState(() => turn.selected = index);
    final option = turn.options[index];
    await _services.speech.sayEn(option.en, voice: _voice, speed: _speed).catchError((Object _) {});
    if (turn.tapToChoose && mounted) {
      _accept(turn, option);
    }
  }

  Future<void> _onSpoken(MicOutcome outcome) async {
    final turn = _turn;
    if (turn == null || turn.done.isCompleted) {
      return;
    }
    final result = outcome.result;
    if (result == null) {
      // No speech engine or no microphone: choosing by tapping.
      setState(() => turn.tapToChoose = true);
      await _services.speech.sayVi(S.talkTapToChooseSpoken).catchError((Object _) {});
      return;
    }
    final heard = result.text.trim();
    final profileId = _profileId;
    if (heard.isNotEmpty) {
      final check = _services.contentFilter.checkInput(heard);
      if (check.distress && profileId != null) {
        unawaited(_services.db.chatLogRepo
            .add(
              profileId: profileId,
              sessionId: _sessionId,
              role: 'kid',
              content: heard,
              flagged: true,
              flagReason: 'distress',
            )
            .catchError((Object _) => 0));
        await _services.speech.sayEn(_distressEn, voice: _voice, speed: _speed).catchError((Object _) {});
        await _services.speech.sayVi(_distressVi).catchError((Object _) {});
      }
    }
    final scorer = PronunciationScorer(difficulty: ref.read(parentSettingsProvider).speechDifficulty);
    var best = -1;
    var bestScore = 0.0;
    for (var i = 0; i < turn.options.length; i++) {
      final s = scorer.score(turn.options[i].en, heard).similarity;
      if (s > bestScore) {
        best = i;
        bestScore = s;
      }
    }
    final threshold = turn.repeat ? 0.35 : 0.45;
    if (best >= 0 && bestScore >= threshold && result.speechMs >= AppConfig.minAnswerSpeechMs) {
      _accept(turn, turn.options[best], heard: heard, speechMs: result.speechMs, latencyMs: result.scoreLatencyMs);
      return;
    }
    turn.misses++;
    if (turn.misses >= 2) {
      if (turn.repeat || (best >= 0 && bestScore >= 0.25)) {
        // Close enough after two tries: keep the talk going.
        _accept(turn, turn.options[best < 0 ? 0 : best], heard: heard, speechMs: result.speechMs);
        return;
      }
      setState(() => turn.tapToChoose = true);
      await _services.speech.sayVi(S.talkTapToChooseSpoken).catchError((Object _) {});
      return;
    }
    await _services.speech.sayVi(S.talkTryAgainSpoken).catchError((Object _) {});
    _mic.currentState?.reset();
  }

  static const String _distressEn = "I'm so sorry. Please tell Mum, Dad or your teacher.";
  static const String _distressVi = 'Tớ thương cậu lắm. Cậu hãy kể với bố mẹ hoặc cô giáo nhé.';

  Future<void> _finish() async {
    if (_finished) {
      return;
    }
    final profileId = _profileId;
    if (profileId != null) {
      if (widget.args.record) {
        await TalkDone.add(_services, profileId, _script.id).catchError((Object _) {});
      }
      await _services.db.profileRepo.addStars(profileId, AppConfig.starsPerStage).catchError((Object _) {});
      ref.invalidate(activeProfileProvider);
    }
    await widget.args.onFinished?.call().catchError((Object _) {});
    if (!mounted) {
      return;
    }
    setState(() => _finished = true);
    if (_script.kind == TalkKind.story) {
      await _services.speech.sayVi(S.talkStoryDoneSpoken).catchError((Object _) {});
      if (!mounted) {
        return;
      }
      await _services.speech.sayEn(_script.moralEn, voice: _voice, speed: _speed).catchError((Object _) {});
      if (!mounted) {
        return;
      }
      await _services.speech.sayVi(_script.moralVi).catchError((Object _) {});
    } else {
      await _services.speech.sayVi(widget.args.doneSpokenVi ?? S.talkDoneSpoken).catchError((Object _) {});
    }
  }

  void _restart() {
    _run++;
    final turn = _turn;
    if (turn != null && !turn.done.isCompleted) {
      turn.done.complete(null);
    }
    setState(() {
      _bubbles.clear();
      _turn = null;
      _finished = false;
      _scene = _script.emoji;
      _sceneIndex = 0;
    });
    unawaited(_services.speech.stop());
    WidgetsBinding.instance.addPostFrameCallback((_) => _runFrom(_script.startId));
  }

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final level = ref.watch(activeProfileProvider).value?.level ?? 0;
    final turn = _turn;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            if (_script.kind == TalkKind.role) _rolesLine(),
            if (_script.kind == TalkKind.story)
              _storyHeader(turn, level)
            else
              SizedBox(
                height: 76,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    BiMascot(mood: turn != null ? BiMood.listening : BiMood.happy, size: 64, level: level),
                    const SizedBox(width: 16),
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.honeySoft, borderRadius: BorderRadius.circular(20)),
                      child: EmojiText(_scene, size: 42),
                    ),
                  ],
                ),
              ),
            Expanded(
              // Reversed, like a messaging app: the newest line stays at the
              // bottom, just above the answers, whatever their height.
              child: ListView.builder(
                controller: _scroll,
                reverse: true,
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                itemCount: _bubbles.length + (_finished ? 1 : 0),
                itemBuilder: (context, i) {
                  final index = _bubbles.length + (_finished ? 1 : 0) - 1 - i;
                  return index < _bubbles.length ? _bubble(_bubbles[index]) : _endCard();
                },
              ),
            ),
            if (turn != null) _turnPanel(turn),
          ],
        ),
      ),
    );
  }

  /// The illustration of the current scene, with Bi watching in the corner.
  Widget _storyHeader(_Turn? turn, int level) {
    // A smaller picture while the child answers, so the lines stay in view.
    final height = turn != null ? 150.0 : 210.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: height,
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), boxShadow: AppShadows.card),
      child: Stack(
        fit: StackFit.expand,
        children: [
          StoryScene(storyId: _script.id, scene: _sceneIndex, fallbackEmoji: _scene),
          Positioned(
            left: 6,
            bottom: 0,
            child: BiMascot(mood: turn != null ? BiMood.listening : BiMood.happy, size: 60, level: level),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: Row(
        children: [
          RoundIconButton(icon: Icons.close_rounded, semanticLabel: S.close, onPressed: () => Navigator.of(context).maybePop()),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_script.titleVi,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                Text(_script.titleEn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontFamily: AppTheme.writingFont)),
              ],
            ),
          ),
          Tooltip(
            message: S.talkVietnameseVoice,
            child: FilterChip(
              label: const Text('VI', style: TextStyle(fontWeight: FontWeight.w900)),
              avatar: const EmojiText('🔊', size: 16),
              selected: _vietnamese,
              onSelected: (v) => setState(() => _vietnamese = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rolesLine() {
    final mine = _script.role(_kid);
    final others = _script.roles.where((r) => r.id != _kid).map((r) => r.vi).join(', ');
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '${mine?.emoji ?? ''} ${S.talkYouPlay(mine?.vi ?? '')} · 🐝 ${S.talkBiPlays(others)}',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _bubble(_Bubble b) {
    final role = _script.role(b.role);
    final left = !b.fromKid;
    final card = Flexible(
      child: GestureDetector(
        onTap: () => _say(b.role, b.en, b.vi),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
          decoration: BoxDecoration(
            color: b.fromKid ? AppColors.honey : AppColors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(22),
              topRight: const Radius.circular(22),
              bottomLeft: Radius.circular(b.fromKid ? 22 : 6),
              bottomRight: Radius.circular(b.fromKid ? 6 : 22),
            ),
            boxShadow: AppShadows.soft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (role != null && _script.roles.length > 2)
                Text(role.vi,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.inkSoft)),
              SpokenText(b.en, fontSize: 22, alignment: WrapAlignment.start, voice: _voiceFor(b.role)),
              const SizedBox(height: 2),
              Text(b.vi, style: const TextStyle(fontSize: 16, color: AppColors.inkSoft, fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      ),
    );
    final avatar = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: EmojiText(role?.emoji ?? (b.fromKid ? '🧒' : '🐝'), size: 34),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: left ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: left ? [avatar, card] : [card, avatar],
    );
  }

  Widget _turnPanel(_Turn turn) {
    final speech = _services.capabilities.value.speech;
    final option = turn.options[turn.selected.clamp(0, turn.options.length - 1)];
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: AppShadows.sheet,
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            turn.tapToChoose ? S.talkTapToChoose : (turn.repeat ? S.talkSayThis : S.talkYourTurn),
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 230),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < turn.options.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: PictureCard(
                        highlight: i == turn.selected && turn.options.length > 1,
                        onTap: () => _tapOption(turn, i),
                        child: Row(
                          children: [
                            EmojiText(turn.options[i].emoji, size: 34),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // The whole card is the answer: a tap on its words chooses it too.
                                  SpokenText(
                                    turn.options[i].en,
                                    fontSize: 21,
                                    alignment: WrapAlignment.start,
                                    wordTaps: false,
                                  ),
                                  Text(turn.options[i].vi,
                                      style: const TextStyle(fontSize: 15, color: AppColors.inkSoft)),
                                ],
                              ),
                            ),
                            if (turn.tapToChoose) const Icon(Icons.touch_app_rounded, size: 30),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (speech && !turn.tapToChoose)
            MicPanel(
              key: _mic,
              target: turn.options.first.en,
              alternatives: [for (final o in turn.options.skip(1)) o.en],
              sentence: true,
              anyAnswer: false,
              onPlayModel: () => _services.speech.sayEn(option.en, voice: _voice, speed: _speed),
              onStart: () => turn.quiet = true,
              onResult: _onSpoken,
            ),
        ],
      ),
    );
  }

  Widget _endCard() {
    final story = _script.kind == TalkKind.story;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.leafSoft, width: 3),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          const Text(S.talkDoneTitle, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const StarRow(stars: 3, size: 36),
          if (story) ...[
            const SizedBox(height: 8),
            const Text('💡 ${S.talkMoral}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            SpokenText(_script.moralEn, fontSize: 22),
            Text(_script.moralVi,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, fontStyle: FontStyle.italic, color: AppColors.inkSoft)),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              KidIconButton(icon: Icons.replay_rounded, label: S.talkAgain, onPressed: _restart),
              KidIconButton(
                icon: Icons.grid_view_rounded,
                label: S.talkOther,
                color: AppColors.leaf,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
