// lib/features/talk_with_bi/talk_screen.dart
//
// "Nói chuyện với Bi": free conversation with the on-device LLM. The model
// is loaded only on this screen and released when the child leaves.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../core/config/app_config.dart';
import '../../core/db/repositories.dart';
import '../../core/providers.dart';
import '../../core/services/stt_service.dart';
import '../../curriculum/basic_words.dart';
import '../../curriculum/lesson_composer.dart';
import '../../l10n/strings_vi.dart';
import '../../widgets/bi_mascot.dart';
import '../../widgets/item_picture.dart';
import '../daily_lesson/activities/activity_base.dart';
import 'bi_brain.dart';
import 'bi_scenarios.dart';
import 'llm_chat_model.dart';

enum _Phase { chooseMode, chooseScenario, chooseStory, loading, talking, ended }

class _Line {
  const _Line(this.fromBi, this.text);

  final bool fromBi;
  final String text;
}

class TalkScreen extends ConsumerStatefulWidget {
  const TalkScreen({super.key});

  @override
  ConsumerState<TalkScreen> createState() => _TalkScreenState();
}

class _TalkScreenState extends ConsumerState<TalkScreen> {
  late final AppServices _services = ref.read(appServicesProvider);
  _Phase _phase = _Phase.chooseMode;
  BiMood _mood = BiMood.happy;
  BiBrain? _brain;
  Profile? _profile;
  Set<String> _vocabulary = const {};
  final Map<String, String> _itemIdByWord = {};
  final List<_Line> _lines = [];
  List<BiHint> _hints = const [];
  bool _busy = false;
  double _level = 0;
  Timer? _limit;
  final String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _services.studyClock.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _services.speech.sayVi(S.talkChooseSpoken).catchError((Object _) {});
    });
  }

  @override
  void dispose() {
    _limit?.cancel();
    _scroll.dispose();
    _services.studyClock.stop();
    _services.speech.stop();
    // Release the model: RAM, battery and heat.
    _services.llm.cancel().whenComplete(_services.llm.unload);
    super.dispose();
  }

  Future<void> _start(BiMode mode, {BiScenario? scenario, BiStory? story}) async {
    if (_phase == _Phase.loading || _phase == _Phase.talking) {
      return; // a second tap while Bi wakes up
    }
    setState(() {
      _phase = _Phase.loading;
      _mood = BiMood.thinking;
    });
    unawaited(_services.speech.sayVi(S.talkWaking).catchError((Object _) {}));
    final settings = ref.read(parentSettingsProvider);
    final profile = await ref.read(activeProfileProvider.future);
    _profile = profile;
    final snapshot = await _services.progress.snapshot(profile.id);
    final curriculum = _services.curriculum;
    final known = <String>{};
    for (final unit in curriculum.units) {
      if (unit.level > profile.level) {
        continue;
      }
      for (final item in unit.items) {
        if (snapshot.introduced(item.id) && !item.isLetter) {
          known.addAll(wordTokens(item.en));
          _itemIdByWord[item.en.toLowerCase()] = item.id;
        }
      }
    }
    final unit = LessonComposer(curriculum: curriculum).currentUnit(profile.level, snapshot) ??
        (curriculum.unitsOf(profile.level).isNotEmpty ? curriculum.unitsOf(profile.level).last : null);
    final unitWords = unit?.items.where((i) => !i.isLetter).toList() ?? const [];
    final topicWords = [
      for (final item in unitWords)
        if (item.picturable && !item.en.contains(' ') && snapshot.introduced(item.id)) item.en,
    ];
    // The current unit's words count as known for Bi's vocabulary check.
    for (final item in unitWords) {
      known.addAll(wordTokens(item.en));
    }
    _vocabulary = {..._itemIdByWord.keys};
    final biContext = BiContext(
      level: profile.level,
      childName: profile.name,
      knownWords: known,
      learningWords: [for (final i in unitWords) i.en],
      topicEn: unit?.topicEn ?? 'animals',
      topicWords: topicWords.isNotEmpty ? topicWords : [for (final i in unitWords.take(6)) i.en],
      mode: mode,
      scenario: scenario,
      story: story,
      support: settings.vietnameseSupport,
    );
    final path = _services.gemmaPath();
    try {
      if (path == null) {
        throw StateError('no model');
      }
      await _services.llm.load(modelPath: path, preferGpu: _services.profile.preferGpu);
      if (!mounted) {
        // The child left while Gemma was loading: dispose() already asked to
        // unload, but the load finished afterwards. Free the gigabytes now.
        await _services.llm.unload();
        return;
      }
      final brain = BiBrain(model: LlmChatModel(_services.llm), context: biContext, filter: _services.contentFilter);
      await brain.start();
      _brain = brain;
    } catch (_) {
      if (!mounted) {
        return;
      }
      await _services.speech.sayVi(S.talkErrorSpoken).catchError((Object _) {});
      if (mounted) {
        context.pop();
      }
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _phase = _Phase.talking;
      _mood = BiMood.happy;
    });
    final minutes = profile.level <= 1 ? AppConfig.biSessionMinutesLow : AppConfig.biSessionMinutesHigh;
    _limit = Timer(Duration(minutes: minutes), _timeUp);
    await _play(_brain!.opener());
  }

  Future<void> _play(Iterable<BiEvent> events) async {
    for (final e in events) {
      await _handle(e);
    }
  }

  Future<void> _handle(BiEvent event) async {
    final profile = _profile;
    switch (event) {
      case BiSay():
        if (!mounted) {
          return;
        }
        setState(() {
          _lines.add(_Line(true, event.text));
          _mood = BiMood.happy;
        });
        _scrollDown();
        if (profile != null) {
          unawaited(_services.db.chatLogRepo
              .add(profileId: profile.id, sessionId: _sessionId, role: 'bi', content: event.text)
              .catchError((Object _) => 0));
        }
        await _services.speech
            .sayEn(event.text, voice: ref.read(parentSettingsProvider).voice, speed: _speed)
            .catchError((Object _) {});
      case BiSayVi():
        await _services.speech.sayVi(event.text).catchError((Object _) {});
      case BiHints():
        if (mounted) {
          setState(() => _hints = event.hints);
        }
      case BiFlag():
        if (profile != null) {
          unawaited(_services.db.chatLogRepo
              .add(
                profileId: profile.id,
                sessionId: _sessionId,
                role: 'system',
                content: S.flagLabel(event.reason),
                flagged: true,
                flagReason: event.reason,
              )
              .catchError((Object _) => 0));
        }
      case BiDone():
        break;
    }
  }

  double get _speed => ref.read(slowModeProvider) ? AppConfig.slowSpeechRate : AppConfig.normalSpeechRate;

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _listen() async {
    final brain = _brain;
    final profile = _profile;
    if (brain == null || profile == null || _busy || _phase != _Phase.talking) {
      return;
    }
    setState(() {
      _busy = true;
      _mood = BiMood.listening;
      _hints = const [];
    });
    await _services.speech.stop();
    var text = '';
    var speechMs = 0;
    try {
      await _services.stt.ensureReady(_services.profile);
      final result = await _services.stt.listenOnce(
        timeout: const Duration(seconds: AppConfig.listenTimeoutSentenceSeconds),
        onLevel: (level) {
          if (mounted) {
            setState(() => _level = level);
          }
        },
      );
      text = result.text;
      speechMs = result.speechMs;
    } on SttException catch (e) {
      if (e.code == 'mic_permission') {
        await _services.speech.sayVi(S.insMicDenied).catchError((Object _) {});
      }
    } catch (_) {
      // Treated as silence below.
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _level = 0;
      _mood = BiMood.thinking;
    });
    if (text.trim().isNotEmpty) {
      setState(() => _lines.add(_Line(false, text)));
      _scrollDown();
      unawaited(_services.db.chatLogRepo
          .add(profileId: profile.id, sessionId: _sessionId, role: 'kid', content: text)
          .catchError((Object _) => 0));
      // Words used in conversation count as speaking practice.
      for (final word in BiBrain.usedWords(text, _vocabulary)) {
        final id = _itemIdByWord[word.toLowerCase()];
        if (id != null) {
          unawaited(_services.progress
              .recordAnswer(profileId: profile.id, itemId: id, skill: 'speak', correct: true, score: 1)
              .catchError((Object _) {}));
        }
      }
    }
    try {
      await for (final event in brain.respond(text, speechMs: speechMs)) {
        if (!mounted) {
          return;
        }
        await _handle(event);
      }
    } catch (_) {
      await _services.speech.sayVi(S.talkErrorSpoken).catchError((Object _) {});
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _mood = BiMood.happy;
      });
    }
  }

  Future<void> _timeUp() async {
    if (!mounted) {
      return;
    }
    final voice = ref.read(parentSettingsProvider).voice;
    setState(() {
      _phase = _Phase.ended;
      _mood = BiMood.cheering;
    });
    await _services.llm.cancel();
    await _services.speech.sayEn(S.talkTimeUpEn, voice: voice).catchError((Object _) {});
    await _services.speech.sayVi(S.talkTimeUpSpoken).catchError((Object _) {});
    await _services.llm.unload();
  }

  Widget _modeButton(String emoji, String label, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        width: double.infinity,
        height: 120,
        child: PictureCard(
          color: color,
          onTap: onTap,
          child: Row(
            children: [
              EmojiText(emoji, size: 64),
              const SizedBox(width: 16),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _picker<T>(List<T> options, String Function(T) emoji, String Function(T) title, void Function(T) onTap) {
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(12),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        for (final o in options)
          PictureCard(
            onTap: () => onTap(o),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                EmojiText(emoji(o), size: 70),
                const SizedBox(height: 6),
                Text(title(o), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final level = ref.watch(activeProfileProvider).value?.level ?? 0;
    final hideText = ref.watch(hideEnglishTextProvider);
    Widget body;
    switch (_phase) {
      case _Phase.chooseMode:
        body = Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BiMascot(size: 180, level: level),
              _modeButton('💬', S.talkModeChat, AppColors.sky, () => _start(BiMode.chat)),
              _modeButton('🎭', S.talkModeRole, AppColors.honey, () {
                setState(() => _phase = _Phase.chooseScenario);
                _services.speech.sayVi(S.talkChooseScenario).catchError((Object _) {});
              }),
              _modeButton('📖', S.talkModeStory, AppColors.berry, () {
                setState(() => _phase = _Phase.chooseStory);
                _services.speech.sayVi(S.talkChooseStory).catchError((Object _) {});
              }),
            ],
          ),
        );
      case _Phase.chooseScenario:
        body = _picker<BiScenario>(
          biScenarios.where((s) => s.minLevel <= level).toList(),
          (s) => s.emoji,
          (s) => s.titleVi,
          (s) => _start(BiMode.rolePlay, scenario: s),
        );
      case _Phase.chooseStory:
        body = _picker<BiStory>(biStories, (s) => s.emoji, (s) => '', (s) => _start(BiMode.story, story: s));
      case _Phase.loading:
        body = Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BiMascot(mood: BiMood.thinking, size: 240, level: level),
              const SizedBox(height: 16),
              const Text(S.talkWaking, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
            ],
          ),
        );
      case _Phase.talking:
      case _Phase.ended:
        body = Column(
          children: [
            BiMascot(mood: _mood, size: 150, level: level),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _lines.length,
                itemBuilder: (context, i) {
                  final line = _lines[i];
                  return Align(
                    alignment: line.fromBi ? Alignment.centerLeft : Alignment.centerRight,
                    child: GestureDetector(
                      onTap: line.fromBi
                          ? () => _services.speech
                              .sayEn(line.text, voice: ref.read(parentSettingsProvider).voice, speed: _speed)
                              .catchError((Object _) {})
                          : null,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        constraints: const BoxConstraints(maxWidth: 320),
                        decoration: BoxDecoration(
                          color: line.fromBi ? AppColors.white : AppColors.honey,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.ink, width: 1.5),
                        ),
                        child: hideText
                            ? Icon(line.fromBi ? Icons.volume_up_rounded : Icons.child_care_rounded, size: 30)
                            : Text(line.text, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_hints.isNotEmpty && _phase == _Phase.talking)
              SizedBox(
                height: 92,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    for (final hint in _hints)
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: PictureCard(
                          onTap: () => _services.speech
                              .sayEn(hint.text, voice: ref.read(parentSettingsProvider).voice, speed: _speed)
                              .catchError((Object _) {}),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              EmojiText(hint.emoji, size: 32),
                              if (!hideText) ...[
                                const SizedBox(width: 6),
                                Text(hint.text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            if (_phase == _Phase.talking)
              GestureDetector(
                onTap: _busy ? null : _listen,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 120 + (_level * 200).clamp(0.0, 30.0),
                  height: 120 + (_level * 200).clamp(0.0, 30.0),
                  decoration: BoxDecoration(
                    color: _mood == BiMood.listening ? AppColors.berry : (_busy ? const Color(0xFFDDD5C0) : AppColors.honey),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.ink, width: 4),
                  ),
                  child: Icon(
                    _mood == BiMood.listening ? Icons.hearing_rounded : Icons.mic_rounded,
                    size: 64,
                    color: AppColors.ink,
                  ),
                ),
              )
            else
              KidIconButton(icon: Icons.home_rounded, size: 100, color: AppColors.honey, onPressed: () => context.pop()),
            const SizedBox(height: 12),
          ],
        );
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  KidIconButton(icon: Icons.close_rounded, size: 60, onPressed: () => context.pop()),
                  const Spacer(),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
