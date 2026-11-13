// lib/features/talk_with_bi/bi_chat_screen.dart
//
// "Chat với Bi": a natural voice chat with Bi's brain (Gemma 4, on the
// phone). The microphone opens by itself after Bi speaks and waits through
// short pauses. Bi echoes a word at once while it thinks, answers in simple
// English with the Vietnamese meaning, invites the child to say a whole
// sentence when they said only a word or two, and helps when the child is
// stuck: an easier question first, then a sentence to copy. The child can
// ask Bi questions, use rescue phrases ("Say it again, please") and ask
// "Bi ơi, nói thế nào?" in Vietnamese. Safety never depends on the model:
// what the child said and every line of Bi is checked before it is shown or
// spoken.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../core/config/app_config.dart';
import '../../core/db/repositories.dart';
import '../../core/providers.dart';
import '../../core/services/english_voice.dart';
import '../../core/services/stt_service.dart';
import '../../curriculum/basic_words.dart';
import '../../curriculum/bi_notes.dart';
import '../../curriculum/bi_world.dart';
import '../../curriculum/scorers/pronunciation_scorer.dart';
import '../../curriculum/skill_map.dart';
import '../../curriculum/talk_scripts.dart';
import '../../l10n/strings_vi.dart';
import '../../widgets/bi_mascot.dart';
import '../../widgets/item_picture.dart';
import '../../widgets/spoken_text.dart';
import '../../widgets/ui_kit.dart';
import '../../core/services/content_filter.dart';
import 'bi_chat.dart';

enum _Phase { loading, noBrain, ready, ended }

enum _MsgKind { bi, kid, note }

class _Msg {
  _Msg(this.kind, this.en, {this.vi = ''});

  final _MsgKind kind;
  String en;
  String vi;
}

/// What one model turn produced so far.
class _Turn {
  _Turn(this.prompt);

  final String prompt;
  final StringBuffer raw = StringBuffer();
  String heard = '';
  String? fix;
  String? bi;
  String? vi;
  String? easy;
  String? teach;
  String? teachVi;
  final List<BiSuggestion> says = [];
  (String, String)? note;
  bool unsafe = false;
  bool fixSeen = false;
  final Completer<void> biReady = Completer<void>();
  final Completer<void> viReady = Completer<void>();
  final Completer<void> done = Completer<void>();

  void finish() {
    for (final c in [biReady, viReady, done]) {
      if (!c.isCompleted) {
        c.complete();
      }
    }
  }
}

/// Saved "Bi ơi, nói thế nào?" sentences (the child's own pocket phrases).
class MyPhrases {
  const MyPhrases._();

  static const String key = 'pocket_mine';

  static Future<List<(String, String)>> load(AppServices services, int profileId) async {
    final raw = await services.db.settingsRepo.read(key, profileId: profileId);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          ('${(e as Map)['en']}', '${e['vi']}'),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(AppServices services, int profileId, String en, String vi) async {
    final list = await load(services, profileId);
    if (list.any((p) => p.$1.toLowerCase() == en.toLowerCase())) {
      return;
    }
    list.insert(0, (en, vi));
    final kept = list.take(60).toList();
    await services.db.settingsRepo.write(
      key,
      jsonEncode([for (final p in kept) {'en': p.$1, 'vi': p.$2}]),
      profileId: profileId,
    );
  }
}

class BiChatScreen extends ConsumerStatefulWidget {
  const BiChatScreen({super.key, this.topic});

  /// Chat about this topic (from a topic page), or about anything (null).
  final TalkTopic? topic;

  @override
  ConsumerState<BiChatScreen> createState() => _BiChatScreenState();
}

class _BiChatScreenState extends ConsumerState<BiChatScreen> {
  late final AppServices _services;
  final List<_Msg> _messages = [];
  final ScrollController _scroll = ScrollController();
  final TextEditingController _typed = TextEditingController();
  final String _sessionId = 'chat-${DateTime.now().millisecondsSinceEpoch}';

  _Phase _phase = _Phase.loading;
  BiMood _mood = BiMood.thinking;
  String _status = S.chatWaking;
  Profile? _profile;
  BiNotes _notes = BiNotes.decode(null);
  bool _notesOn = true;
  BiChatContext? _context;
  Set<String> _vocabulary = const {};
  final Map<String, String> _itemIdByWord = {};

  List<BiSuggestion> _suggestions = const [];
  int _highlight = -1;
  bool _showAsk = false;
  bool _typing = false;
  bool _vietnamese = true;
  bool _slow = false;
  bool _busy = false;
  bool _listening = false;
  double _level = 0;

  String _lastBi = '';
  String _lastBiVi = '';
  String? _easy;
  int _silence = 0;
  int _turns = 0;
  int _echoTurn = 0;
  bool _practisedLast = false;
  final List<(String, String)> _recent = [];
  Timer? _limit;
  int _run = 0;

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
    _limit?.cancel();
    _scroll.dispose();
    _typed.dispose();
    _services.studyClock.stop();
    unawaited(_services.speech.stop());
    // Release the model: RAM, battery and heat.
    unawaited(_services.llm.cancel().whenComplete(_services.llm.unload));
    super.dispose();
  }

  EnglishVoice get _voice => ref.read(parentSettingsProvider).voice;

  double get _speed => (_slow || ref.read(slowModeProvider)) ? AppConfig.slowSpeechRate : AppConfig.normalSpeechRate;

  bool get _alive => mounted && _phase == _Phase.ready;

  // ------------------------------------------------------------ start-up

  Future<void> _start() async {
    final profile = await ref.read(activeProfileProvider.future);
    _profile = profile;
    final path = _services.gemmaPath();
    if (path == null || !_services.capabilities.value.llm) {
      if (mounted) {
        setState(() {
          _phase = _Phase.noBrain;
          _mood = BiMood.happy;
        });
      }
      await _services.speech.sayVi(S.chatNeedBrainSpoken).catchError((Object _) {});
      return;
    }
    unawaited(_services.speech.sayVi(S.talkWaking).catchError((Object _) {}));
    final settings = await Future.wait([
      _services.db.settingsRepo.read(BiNotes.key, profileId: profile.id),
      _services.db.settingsRepo.read(BiNotes.offKey, profileId: profile.id),
    ]);
    _notes = BiNotes.decode(settings[0]);
    _notesOn = settings[1] != '1';
    await _buildVocabulary(profile);
    final topic = widget.topic;
    _context = BiChatContext(
      childName: profile.name,
      level: profile.level,
      notes: _notesOn ? _notes : BiNotes.decode(null),
      news: BiWorld.newsFor(DateTime.now()),
      topicEn: topic?.en,
      topicWords: topic?.words ?? const [],
    );
    try {
      await _services.llm.load(
        modelPath: path,
        preferGpu: _services.profile.preferGpu,
        audio: true,
        mtp: true,
      );
      if (!mounted) {
        await _services.llm.unload();
        return;
      }
      await _newConversation();
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
      _phase = _Phase.ready;
      _mood = BiMood.happy;
      _vietnamese = profile.level <= 2;
    });
    final minutes = profile.level <= 1 ? AppConfig.biSessionMinutesLow + 3 : AppConfig.biSessionMinutesHigh;
    _limit = Timer(Duration(minutes: minutes), _timeUp);
    await _opener();
  }

  Future<void> _newConversation() async {
    final c = _context!;
    final withMemory = BiChatContext(
      childName: c.childName,
      level: c.level,
      notes: _notesOn ? _notes : BiNotes.decode(null),
      news: c.news,
      topicEn: c.topicEn,
      topicWords: c.topicWords,
      recent: _recent.length > 2 ? _recent.sublist(_recent.length - 2) : List.of(_recent),
    );
    await _services.llm.startConversation(
      BiChat.systemPrompt(withMemory),
      examples: BiChat.examples(withMemory),
      temperature: BiChat.temperature,
      topK: BiChat.topK,
      topP: BiChat.topP,
      maxOutputTokens: BiChat.maxOutputTokens,
    );
    _turns = 0;
  }

  Future<void> _buildVocabulary(Profile profile) async {
    final snapshot = await _services.progress.snapshot(profile.id);
    final words = <String>{...basicWords};
    for (final unit in _services.curriculum.units) {
      if (unit.level > profile.level + 1) {
        continue;
      }
      for (final item in unit.items) {
        if (item.isLetter) {
          continue;
        }
        words.addAll(wordTokens(item.en));
        if (snapshot.introduced(item.id)) {
          _itemIdByWord[item.en.toLowerCase()] = item.id;
        }
      }
    }
    for (final item in _services.curriculum.parentItems) {
      words.addAll(wordTokens(item.en));
      if (snapshot.introduced(item.id)) {
        _itemIdByWord[item.en.toLowerCase()] = item.id;
      }
    }
    words.addAll(widget.topic?.words.map((w) => w.toLowerCase()) ?? const []);
    _vocabulary = words;
  }

  /// The Vietnamese for an English word from the curriculum ("dogs" -> "con
  /// chó"), or the word itself in quotes when the curriculum does not know it.
  String _viWord(String word) {
    final w = word.trim().toLowerCase();
    for (final v in {w, ...wordVariants(w)}) {
      // "mì, phở" -> "mì"; "con chó" -> "chó" ("cậu thích chó").
      var vi = (_services.curriculum.itemByWord(v)?.vi ?? '').split(',').first.trim().toLowerCase();
      if (vi.startsWith('con ') && vi.length > 4) {
        vi = vi.substring(4);
      }
      if (vi.isNotEmpty) {
        return vi;
      }
    }
    return '"$word"';
  }

  /// Bi's first line: no model call, so it starts at once.
  Future<void> _opener() async {
    final name = _profile?.name ?? '';
    final hi = name.isEmpty ? 'Hi!' : 'Hi, $name!';
    String en;
    String vi;
    List<BiSuggestion> says;
    final animal = _notesOn ? _notes['animal'] : null;
    final topic = widget.topic;
    final opener = topic == null ? null : BiChat.topicOpener(topic.id);
    if (topic != null && opener != null) {
      en = '$hi ${opener.$1}';
      vi = 'Chào cậu! ${opener.$2}';
      says = opener.$3;
    } else if (topic != null) {
      en = "$hi Let's talk about ${topic.en.toLowerCase()}! What do you like?";
      vi = 'Chào cậu! Mình nói về chủ đề ${topic.vi.toLowerCase()} nhé! Cậu thích gì?';
      says = const [
        BiSuggestion('👍', 'I like it!', 'Tớ thích lắm!'),
        BiSuggestion('🤔', "I don't know.", 'Tớ không biết.'),
        BiSuggestion('🐝', 'What do you like?', 'Cậu thích gì?'),
      ];
    } else if (animal != null) {
      en = '$hi I remember you like $animal! Do you still like them?';
      vi = 'Chào cậu! Tớ nhớ cậu thích ${_viWord(animal)}. Cậu vẫn thích chứ?';
      says = const [
        BiSuggestion('👍', 'Yes, I do!', 'Có chứ!'),
        BiSuggestion('👎', "No, I don't.", 'Không, tớ hết thích rồi.'),
        BiSuggestion('🐝', 'What do you like?', 'Cậu thích gì?'),
      ];
    } else {
      en = "$hi I'm Bi. How are you today?";
      vi = 'Chào cậu! Tớ là Bi. Hôm nay cậu thế nào?';
      says = const [
        BiSuggestion('😄', "I'm happy!", 'Tớ vui lắm!'),
        BiSuggestion('🙂', "I'm fine, thank you.", 'Tớ khoẻ, cảm ơn cậu.'),
        BiSuggestion('😴', "I'm sleepy.", 'Tớ buồn ngủ.'),
      ];
    }
    _easy = null;
    await _biSays(en, vi, suggestions: says);
    _afterBi();
  }

  // ------------------------------------------------------------- talking

  void _add(_Msg msg) {
    if (!mounted) {
      return;
    }
    setState(() => _messages.add(msg));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients && _scroll.offset > 0) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
    final profile = _profile;
    if (profile != null && msg.kind != _MsgKind.note) {
      unawaited(_services.db.chatLogRepo
          .add(
            profileId: profile.id,
            sessionId: _sessionId,
            role: msg.kind == _MsgKind.kid ? 'kid' : 'bi',
            content: msg.en,
          )
          .catchError((Object _) => 0));
    }
  }

  void _flag(String reason) {
    final profile = _profile;
    if (profile == null) {
      return;
    }
    unawaited(_services.db.chatLogRepo
        .add(
          profileId: profile.id,
          sessionId: _sessionId,
          role: 'system',
          content: S.flagLabel(reason),
          flagged: true,
          flagReason: reason,
        )
        .catchError((Object _) => 0));
  }

  void _setStatus(String status, BiMood mood) {
    if (mounted) {
      setState(() {
        _status = status;
        _mood = mood;
      });
    }
  }

  /// Bi says a line in English (karaoke bubble), then its meaning when "VI"
  /// is on.
  Future<void> _biSays(String en, String vi, {List<BiSuggestion>? suggestions, bool remember = true}) async {
    if (!mounted) {
      return;
    }
    final msg = _Msg(_MsgKind.bi, en, vi: vi);
    _add(msg);
    if (remember) {
      _lastBi = en;
      _lastBiVi = vi;
    }
    if (suggestions != null) {
      setState(() {
        _suggestions = suggestions;
        _highlight = -1;
      });
    }
    _setStatus(S.chatSpeaking, BiMood.happy);
    await _services.speech.sayEn(en, voice: _voice, speed: _speed).catchError((Object _) {});
    if (_vietnamese && vi.isNotEmpty && mounted) {
      await _services.speech.sayVi(vi).catchError((Object _) {});
    }
  }

  Future<void> _biSaysVi(String vi) async {
    if (mounted) {
      await _services.speech.sayVi(vi).catchError((Object _) {});
    }
  }

  /// After Bi's turn: open the microphone by itself, unless the child has
  /// been silent three times (then Bi waits for a tap).
  void _afterBi() {
    if (!_alive) {
      return;
    }
    setState(() => _busy = false);
    _setStatus(S.chatTapMic, BiMood.happy);
    if (_silence < 3 && !_typing) {
      unawaited(_listen());
    }
  }

  Future<void> _listen({bool teach = false}) async {
    final profile = _profile;
    if (!_alive || profile == null || _listening || _busy) {
      return;
    }
    final run = _run;
    setState(() {
      _listening = true;
      _level = 0;
    });
    _setStatus(S.chatListening, BiMood.listening);
    await _services.speech.stop();
    SttResult? result;
    try {
      await _services.stt.ensureReady(_services.profile);
      result = await _services.stt.listenOnce(
        timeout: const Duration(seconds: AppConfig.listenTimeoutSentenceSeconds),
        saveWavPath: _services.recordingPath(profile.id),
        patienceMs: 900,
        onLevel: (level) {
          if (mounted && _listening) {
            setState(() => _level = level);
          }
        },
      );
    } on SttException catch (e) {
      if (e.code == 'mic_permission') {
        await _biSaysVi(S.insMicDenied);
      }
    } catch (_) {
      // Treated as silence.
    }
    if (!mounted || run != _run) {
      return;
    }
    setState(() {
      _listening = false;
      _level = 0;
    });
    final text = result?.text.trim() ?? '';
    final speechMs = result?.speechMs ?? 0;
    final wav = result?.wavPath;
    if (wav != null) {
      unawaited(_services.db.mediaRepo
          .addRecording(profileId: profile.id, filePath: wav)
          .catchError((Object _) => 0));
    }
    // The child spoke (in English or Vietnamese) when the detector heard
    // enough voice, even if the English recogniser wrote nothing.
    final spoke = speechMs >= AppConfig.minAnswerSpeechMs;
    if (!spoke) {
      if (teach) {
        _afterBi();
        return;
      }
      await _onSilence();
      return;
    }
    _silence = 0;
    if (text.isNotEmpty) {
      unawaited(_services.db.speechTurnRepo
          .add(
            profile.id,
            SpeechTurn(
              source: SpeechTurn.talk,
              at: DateTime.now(),
              speechMs: speechMs,
              words: englishWordCount(text),
              latencyMs: result!.timedOut ? -1 : result.scoreLatencyMs,
            ),
          )
          .catchError((Object _) {}));
      for (final word in usedVocabulary(text)) {
        final id = _itemIdByWord[word];
        if (id != null) {
          unawaited(_services.progress
              .recordAnswer(profileId: profile.id, itemId: id, skill: 'speak', correct: true, score: 1)
              .catchError((Object _) {}));
        }
      }
    }
    await _childSaid(text, audioPath: wav, teach: teach);
  }

  Iterable<String> usedVocabulary(String text) {
    final tokens = wordTokens(text).toSet();
    return _itemIdByWord.keys.where((w) => !w.contains(' ') && tokens.contains(w));
  }

  /// The child stayed silent: an easier question, then a sentence to copy,
  /// then Bi waits for a tap.
  Future<void> _onSilence() async {
    _silence++;
    if (!_alive) {
      return;
    }
    setState(() => _busy = true);
    if (_silence == 1) {
      final easy = _easy ?? BiChat.lastQuestion(_lastBi);
      if (easy != null) {
        await _biSays(easy, '', remember: false);
      } else {
        await _biSays('Take your time!', 'Cứ từ từ nhé!', remember: false);
      }
    } else if (_silence == 2 && _suggestions.isNotEmpty) {
      final s = _suggestions.first;
      setState(() => _highlight = 0);
      await _biSays('You can say: ${s.en}', s.vi.isEmpty ? '' : S.chatYouCanSayVi(s.vi), remember: false);
    } else {
      await _biSaysVi(S.chatReadyTapSpoken);
      if (mounted) {
        setState(() => _busy = false);
        _setStatus(S.chatTapMic, BiMood.happy);
      }
      return;
    }
    _afterBi();
  }

  /// What the child said (spoken, typed or a tapped card).
  Future<void> _childSaid(String text, {String? audioPath, bool teach = false}) async {
    if (!_alive) {
      return;
    }
    final run = _run;
    final kid = _Msg(_MsgKind.kid, text.isEmpty ? '…' : text);
    _add(kid);
    setState(() {
      _busy = true;
      _highlight = -1;
      _showAsk = false;
    });
    _setStatus(S.chatThinking, BiMood.thinking);

    // Safety first, before anything reaches the model.
    if (text.isNotEmpty) {
      final check = _services.contentFilter.checkInput(text);
      if (check.distress) {
        _flag('distress');
        await _biSays(ContentFilter.distressReplyEn, ContentFilter.distressReplyVi);
        _afterBi();
        return;
      }
      if (check.inappropriate) {
        _flag('inappropriate_input');
        await _biSays(ContentFilter.redirectReplyEn, "Mình nói chuyện khác nhé! Cậu thích màu gì nhất?");
        _afterBi();
        return;
      }
    }

    // Rescue phrases are answered at once, without the model.
    if (!teach) {
      switch (BiChat.rescue(text)) {
        case BiRescue.again:
          await _biSays('Sure! $_lastBi', _lastBiVi, remember: false);
          _afterBi();
          return;
        case BiRescue.slowly:
          setState(() => _slow = true);
          await _biSays('Okay! $_lastBi', _lastBiVi, remember: false);
          _afterBi();
          return;
        case BiRescue.dontKnow:
          final easy = _easy ?? BiChat.lastQuestion(_lastBi);
          await _biSays("That's okay!${easy == null ? '' : ' $easy'}", 'Không sao đâu!', remember: false);
          _afterBi();
          return;
        case BiRescue.howSay:
          await _startTeach();
          return;
        case BiRescue.none:
          break;
      }
    }

    // A conversation restarting in the background must finish first.
    await _restarting?.catchError((Object _) {});
    if (!mounted || run != _run) {
      return;
    }
    final hearsAudio = audioPath != null && _services.llm.hearsAudio;
    final prompt = teach
        ? BiChat.teachTurn(text, audio: hearsAudio)
        : BiChat.userTurn(text, audio: hearsAudio);
    final turn = _Turn(prompt);
    final level = _context?.level ?? 0;
    final filter = _services.contentFilter;
    final parser = BiTurnParser();
    String lastTag = '';

    void take(String tag, String value) {
      if (turn.unsafe) {
        return;
      }
      final continued = tag == lastTag && tag != 'SAY';
      lastTag = tag;
      switch (tag) {
        case 'HEARD':
          turn.heard = continued ? '${turn.heard} $value' : value;
          final check = filter.checkInput(turn.heard);
          if (check.distress || check.inappropriate) {
            turn.unsafe = true;
            _flag(check.distress ? 'distress' : 'inappropriate_input');
          }
        case 'FIX':
          turn.fix = BiChat.fixSentence(value, filter, level);
          turn.fixSeen = true;
        case 'BI':
          if (continued || turn.biReady.isCompleted) {
            return;
          }
          final english = BiChat.speakableEnglish(value, filter, level);
          if (english == null && filter.unsafeText(ContentFilter.cleanModelText(value))) {
            turn.unsafe = true;
            _flag('filtered_output');
          }
          turn.bi = english;
          turn.biReady.complete();
        case 'VI':
          if (continued || turn.viReady.isCompleted) {
            return;
          }
          turn.vi = BiChat.showableVietnamese(value, filter);
          turn.viReady.complete();
        case 'EASY':
          final easy = BiChat.speakableEnglish(value, filter, level);
          turn.easy = easy != null && easy.contains('?') ? easy : null;
        case 'SAY':
          final s = BiChat.suggestion(value, filter, level);
          if (s != null && turn.says.length < 3 && !turn.says.any((o) => o.en == s.en)) {
            turn.says.add(s);
          }
        case 'NOTE':
          turn.note = BiNotes.parseLine(value);
        case 'TEACH':
          turn.teach = BiChat.fixSentence(value, filter, level + 1);
        case 'TEACHVI':
          turn.teachVi = BiChat.showableVietnamese(value, filter);
      }
      if (turn.unsafe) {
        turn.finish();
        unawaited(_services.llm.cancel());
      }
    }

    late final StreamSubscription<String> sub;
    sub = _services.llm
        .send(prompt, audioPath: hearsAudio ? audioPath : null)
        .timeout(const Duration(seconds: AppConfig.biReplyTimeoutSeconds))
        .listen(
      (chunk) {
        turn.raw.write(chunk);
        for (final (tag, value) in parser.feed(chunk)) {
          take(tag, value);
        }
      },
      onError: (Object _) {
        _flag('model_error');
        turn.finish();
      },
      onDone: () {
        for (final (tag, value) in parser.close()) {
          take(tag, value);
        }
        turn.finish();
      },
      cancelOnError: true,
    );

    // A quick echo while Bi thinks ("Noodles!"), every other turn.
    if (!teach && text.isNotEmpty) {
      final word = BiChat.echoWord(text, _vocabulary);
      if (word != null && _echoTurn.isEven) {
        await _services.speech
            .sayEn(BiChat.echoLine(word, _echoTurn ~/ 2), voice: _voice, speed: _speed)
            .catchError((Object _) {});
      }
      _echoTurn++;
    }

    try {
      // HEARD and FIX come first in every reply.
      await Future.any([turn.biReady.future, _waitFor(() => turn.fixSeen || turn.unsafe || turn.done.isCompleted)])
          .timeout(const Duration(seconds: AppConfig.biReplyTimeoutSeconds + 2), onTimeout: () {});
      if (!mounted || run != _run) {
        return;
      }
      _showHeard(kid, text, turn.heard, hearsAudio);
      if (turn.unsafe) {
        await sub.cancel();
        await _biSays(ContentFilter.redirectReplyEn, 'Mình nói chuyện khác nhé! Cậu thích màu gì nhất?');
        _afterBi();
        return;
      }

      if (teach) {
        await turn.biReady.future;
        await _finishTeach(turn);
        return;
      }

      // The child said a word or two: say the whole sentence together first.
      final fix = turn.fix;
      if (fix != null && !_practisedLast && BiChat.shouldPractise(turn.heard.isEmpty ? text : turn.heard, fix)) {
        _practisedLast = true;
        await _practise(fix, '');
      } else {
        _practisedLast = false;
      }

      await turn.biReady.future.timeout(const Duration(seconds: AppConfig.biReplyTimeoutSeconds), onTimeout: () {});
      if (!mounted || run != _run) {
        return;
      }
      _showHeard(kid, text, turn.heard, hearsAudio);
      final bi = turn.bi;
      if (bi == null || turn.unsafe) {
        await sub.cancel();
        await _fallback(turn.unsafe);
        if (!turn.unsafe) {
          await _keepNote(BiNotes.fromChild(text));
        }
        return;
      }
      await turn.viReady.future.timeout(const Duration(seconds: 4), onTimeout: () {});
      _easy = null;
      await _biSays(bi, turn.vi ?? '');
      await turn.done.future.timeout(const Duration(seconds: 12), onTimeout: () {});
      if (!mounted || run != _run) {
        return;
      }
      _easy = turn.easy;
      if (turn.says.isNotEmpty) {
        setState(() {
          _suggestions = List.of(turn.says);
          _highlight = -1;
        });
      }
      // Only what the child really said goes into the notebook.
      await _keepNote(BiNotes.choose(turn.note, '$text ${turn.heard} ${turn.fix ?? ''}'));
      _remember(turn);
      _afterBi();
    } finally {
      unawaited(sub.cancel());
      if (!turn.done.isCompleted) {
        // Never two replies at once: stop what the model is still writing.
        turn.finish();
        unawaited(_services.llm.cancel());
      }
    }
  }

  /// Completes once [ready] becomes true (checked every 50 ms).
  Future<void> _waitFor(bool Function() ready) async {
    while (!ready()) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) {
        return;
      }
    }
  }

  /// Shows what Bi heard when it understood the recording better than the
  /// English recogniser (the child spoke Vietnamese, or very softly).
  void _showHeard(_Msg kid, String whisper, String heard, bool audio) {
    final h = heard.trim();
    if (!audio || h.isEmpty || h == kid.en) {
      return;
    }
    final vietnamese = RegExp('[ăâđêôơưáàảãạấầẩẫậắằẳẵặéèẻẽẹếềểễệíìỉĩịóòỏõọốồổỗộớờởỡợúùủũụứừửữựýỳỷỹỵ]', caseSensitive: false)
        .hasMatch(h);
    if (vietnamese || wordTokens(whisper).length < 2) {
      if (!_services.contentFilter.unsafeText(h)) {
        setState(() => kid.en = h);
      }
    }
  }

  /// Bi invites the child to say [sentence] once (scored, never failed).
  Future<void> _practise(String sentence, String vi) async {
    final profile = _profile;
    if (!_alive || profile == null) {
      return;
    }
    _add(_Msg(_MsgKind.note, '${S.chatSayFull} $sentence'));
    await _services.speech.sayEn('You can say: $sentence', voice: _voice, speed: _speed).catchError((Object _) {});
    if (_vietnamese) {
      await _biSaysVi(S.chatSayFullSpoken(vi));
    }
    if (!_alive) {
      return;
    }
    setState(() => _listening = true);
    _setStatus(S.chatListening, BiMood.listening);
    SttResult? result;
    try {
      result = await _services.stt.listenOnce(
        timeout: const Duration(seconds: AppConfig.listenTimeoutSentenceSeconds),
        patienceMs: 600,
        onLevel: (level) {
          if (mounted && _listening) {
            setState(() => _level = level);
          }
        },
      );
    } catch (_) {
      // Silence: Bi goes on with the chat.
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _listening = false;
      _level = 0;
    });
    final heard = result?.text.trim() ?? '';
    if (heard.isEmpty) {
      return;
    }
    _add(_Msg(_MsgKind.kid, heard));
    final score = PronunciationScorer(difficulty: ref.read(parentSettingsProvider).speechDifficulty)
        .score(sentence, heard)
        .similarity;
    await _services.speech
        .sayEn(score >= 0.5 ? 'Great job!' : 'Good try!', voice: _voice, speed: _speed)
        .catchError((Object _) {});
  }

  Future<void> _fallback(bool unsafe) async {
    const questions = [
      ('What do you like to do?', 'Cậu thích làm gì?'),
      ("What's your favourite colour?", 'Cậu thích màu gì nhất?'),
      ('Do you like animals?', 'Cậu có thích con vật không?'),
      ('What did you eat today?', 'Hôm nay cậu ăn gì?'),
    ];
    final q = questions[_turns % questions.length];
    await _biSays(
      unsafe ? "Let's talk about something fun! ${q.$1}" : 'Hmm! ${q.$1}',
      unsafe ? 'Mình nói chuyện vui khác nhé! ${q.$2}' : 'Ừm! ${q.$2}',
      suggestions: const [
        BiSuggestion('🎨', 'I like drawing.', 'Tớ thích vẽ.'),
        BiSuggestion('🐶', 'I like dogs.', 'Tớ thích chó.'),
        BiSuggestion('⚽', 'I like football.', 'Tớ thích đá bóng.'),
      ],
    );
    _afterBi();
  }

  Future<void> _keepNote((String, String)? note) async {
    final profile = _profile;
    if (note == null || !_notesOn || profile == null) {
      return;
    }
    if (_services.contentFilter.unsafeText(note.$2)) {
      return;
    }
    if (_notes.put(note.$1, note.$2, BiWorld.dayNumber(DateTime.now()))) {
      await _services.db.settingsRepo
          .write(BiNotes.key, _notes.encode(), profileId: profile.id)
          .catchError((Object _) {});
      _add(_Msg(_MsgKind.note, S.chatNoteSaved));
    }
  }

  /// Keeps the exchange for the next conversation and restarts the
  /// conversation before the model's memory fills up.
  void _remember(_Turn turn) {
    final raw = turn.raw.toString().trim();
    if (raw.isNotEmpty) {
      _recent.add((turn.prompt, raw.length > 700 ? raw.substring(0, 700) : raw));
      if (_recent.length > 4) {
        _recent.removeAt(0);
      }
    }
    _turns++;
    if (_turns >= BiChat.turnsPerConversation) {
      _restarting = _newConversation().catchError((Object _) {}).whenComplete(() => _restarting = null);
    }
  }

  /// A conversation restart in progress (the next turn waits for it).
  Future<void>? _restarting;

  // ------------------------------------------------- "Bi ơi, nói thế nào?"

  Future<void> _startTeach() async {
    if (!_alive) {
      return;
    }
    if (!_services.llm.hearsAudio) {
      // The model cannot hear Vietnamese: a parent can type it.
      setState(() {
        _busy = false;
        _typing = true;
      });
      _typedTeach = true;
      _setStatus(S.chatHowSayTyping, BiMood.happy);
      return;
    }
    setState(() => _busy = true);
    await _biSaysVi(S.chatHowSaySpoken);
    if (!_alive) {
      return;
    }
    setState(() => _busy = false);
    await _listen(teach: true);
  }

  bool _typedTeach = false;

  Future<void> _finishTeach(_Turn turn) async {
    final profile = _profile;
    final sentence = turn.teach;
    if (sentence == null || profile == null) {
      await _fallback(false);
      return;
    }
    final vi = turn.teachVi ?? '';
    await _biSays('You can say: $sentence', vi.isEmpty ? '' : S.chatYouCanSayVi(vi), remember: false);
    await _practise(sentence, '');
    await MyPhrases.add(_services, profile.id, sentence, vi).catchError((Object _) {});
    _add(_Msg(_MsgKind.note, S.chatPhraseSaved));
    await turn.done.future.timeout(const Duration(seconds: 8), onTimeout: () {});
    _remember(turn);
    if (_lastBi.isNotEmpty && mounted) {
      // Back to where the chat was.
      await _biSays(_lastBi, _lastBiVi);
    }
    _afterBi();
  }

  // ------------------------------------------------------------- inputs

  Future<void> _tapMic() async {
    if (_listening || _busy || !_alive) {
      return;
    }
    _silence = 0;
    await _services.speech.stop();
    await _listen();
  }

  Future<void> _sendTyped() async {
    final text = _typed.text.trim();
    if (text.isEmpty || _busy || !_alive) {
      return;
    }
    _typed.clear();
    final teach = _typedTeach;
    _typedTeach = false;
    setState(() => _typing = false);
    FocusScope.of(context).unfocus();
    _silence = 0;
    await _childSaid(text, teach: teach);
  }

  Future<void> _hearSuggestion(int i) async {
    setState(() => _highlight = i);
    await _services.speech.sayEn(_suggestions[i].en, voice: _voice, speed: _speed).catchError((Object _) {});
  }

  Future<void> _sendSuggestion(String en) async {
    if (_busy || _listening || !_alive) {
      return;
    }
    _silence = 0;
    await _services.speech.stop();
    await _childSaid(en);
  }

  Future<void> _askBi(BiQuestion q) async {
    if (_busy || _listening || !_alive) {
      return;
    }
    _silence = 0;
    await _services.speech.stop();
    await _childSaid(q.en);
  }

  Future<void> _timeUp() async {
    if (!mounted || _phase != _Phase.ready) {
      return;
    }
    _run++;
    setState(() {
      _phase = _Phase.ended;
      _mood = BiMood.cheering;
      _busy = false;
      _listening = false;
    });
    await _services.llm.cancel();
    await _services.speech.sayEn(S.talkTimeUpEn, voice: _voice).catchError((Object _) {});
    await _services.speech.sayVi(S.chatEndSpoken).catchError((Object _) {});
    await _services.llm.unload();
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final level = ref.watch(activeProfileProvider).value?.level ?? 0;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _topBar(level),
            Expanded(child: _body(level)),
            if (_phase == _Phase.ready) _bottomPanel(),
          ],
        ),
      ),
    );
  }

  Widget _topBar(int level) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          RoundIconButton(icon: Icons.close_rounded, semanticLabel: S.close, onPressed: () => context.pop()),
          const SizedBox(width: 10),
          BiMascot(mood: _mood, size: 54, level: level),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.topic == null ? S.chatTitle : '${widget.topic!.emoji} ${widget.topic!.vi}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _status,
                    key: ValueKey(_status),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.inkSoft),
                  ),
                ),
              ],
            ),
          ),
          if (_phase == _Phase.ready)
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

  Widget _body(int level) {
    switch (_phase) {
      case _Phase.loading:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BiMascot(mood: BiMood.thinking, size: 200, level: level),
              const SizedBox(height: 16),
              const Text(S.chatWaking, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              const SizedBox(width: 180, child: LinearProgressIndicator(minHeight: 8)),
            ],
          ),
        );
      case _Phase.noBrain:
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: SoftCard(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BiMascot(mood: BiMood.sleeping, size: 140, level: level),
                  const SizedBox(height: 10),
                  const Text(S.chatNeedBrain,
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text(S.chatNeedBrainBody,
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: AppColors.inkSoft)),
                  const SizedBox(height: 16),
                  PillButton(label: S.talkOther, icon: Icons.arrow_forward_rounded, onPressed: () => context.pop()),
                ],
              ),
            ),
          ),
        );
      case _Phase.ready:
      case _Phase.ended:
        return ListView.builder(
          controller: _scroll,
          reverse: true,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          itemCount: _messages.length + (_phase == _Phase.ended ? 1 : 0),
          itemBuilder: (context, i) {
            final count = _messages.length + (_phase == _Phase.ended ? 1 : 0);
            final index = count - 1 - i;
            return index < _messages.length ? _bubble(_messages[index]) : _endCard();
          },
        );
    }
  }

  Widget _bubble(_Msg m) {
    if (m.kind == _MsgKind.note) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: AppColors.honeySoft, borderRadius: BorderRadius.circular(999)),
            child: Text(m.en,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
          ),
        ),
      );
    }
    final bi = m.kind == _MsgKind.bi;
    final hideText = ref.watch(hideEnglishTextProvider);
    final card = Flexible(
      child: GestureDetector(
        onTap: bi
            ? () async {
                await _services.speech.sayEn(m.en, voice: _voice, speed: _speed).catchError((Object _) {});
                if (m.vi.isNotEmpty && _vietnamese) {
                  await _services.speech.sayVi(m.vi).catchError((Object _) {});
                }
              }
            : null,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: bi ? AppColors.white : AppColors.honey,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(22),
              topRight: const Radius.circular(22),
              bottomLeft: Radius.circular(bi ? 6 : 22),
              bottomRight: Radius.circular(bi ? 22 : 6),
            ),
            boxShadow: AppShadows.soft,
          ),
          child: hideText && bi
              ? const Icon(Icons.volume_up_rounded, size: 30)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (bi)
                      SpokenText(m.en, fontSize: 21, alignment: WrapAlignment.start, voice: _voice)
                    else
                      Text(m.en, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    if (m.vi.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(m.vi,
                          style: const TextStyle(fontSize: 15, color: AppColors.inkSoft, fontStyle: FontStyle.italic)),
                    ],
                  ],
                ),
        ),
      ),
    );
    final avatar = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: EmojiText(bi ? '🐝' : '🧒', size: 30),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: bi ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: bi ? [avatar, card, const SizedBox(width: 30)] : [const SizedBox(width: 30), card, avatar],
    );
  }

  Widget _bottomPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: AppShadows.sheet,
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_suggestions.isNotEmpty && !_showAsk) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 6, bottom: 4),
                child: Text(S.chatSuggest,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.inkSoft)),
              ),
            ),
            SizedBox(
              height: 74,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _suggestions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => _chip(
                  _suggestions[i].emoji,
                  _suggestions[i].en,
                  _suggestions[i].vi,
                  highlighted: i == _highlight,
                  onHear: () => _hearSuggestion(i),
                  onSend: () => _sendSuggestion(_suggestions[i].en),
                ),
              ),
            ),
          ],
          if (_showAsk)
            SizedBox(
              height: 74,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: BiWorld.questions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final q = BiWorld.questions[i];
                  return _chip(
                    q.emoji,
                    q.en,
                    q.vi,
                    onHear: () => _services.speech.sayEn(q.en, voice: _voice, speed: _speed).catchError((Object _) {}),
                    onSend: () => _askBi(q),
                  );
                },
              ),
            ),
          if (_typing)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _typed,
                      autofocus: true,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendTyped(),
                      decoration: InputDecoration(
                        hintText: _typedTeach ? S.chatHowSayTyping : S.chatTypeHint,
                        filled: true,
                        fillColor: AppColors.cream,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: const BorderSide(color: AppColors.line),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  RoundIconButton(
                    icon: Icons.send_rounded,
                    semanticLabel: S.chatSend,
                    color: AppColors.honey,
                    onPressed: _sendTyped,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              _tool(Icons.keyboard_rounded, S.chatType, () {
                setState(() {
                  _typing = !_typing;
                  _typedTeach = false;
                });
              }, active: _typing),
              _tool(Icons.translate_rounded, S.chatHowSay, _busy || _listening ? null : _startTeach),
              Expanded(child: Center(child: _micButton())),
              _tool(Icons.help_outline_rounded, S.chatAskBi, () => setState(() => _showAsk = !_showAsk),
                  active: _showAsk),
              _tool(Icons.slow_motion_video_rounded, 'Nói chậm', () => setState(() => _slow = !_slow), active: _slow),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String emoji, String en, String vi,
      {required VoidCallback onHear, required VoidCallback onSend, bool highlighted = false}) {
    return Container(
      decoration: BoxDecoration(
        color: highlighted ? AppColors.honeySoft : AppColors.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: highlighted ? AppColors.honeyDeep : AppColors.line, width: highlighted ? 2.5 : 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onHear,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  EmojiText(emoji, size: 26),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(en,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                        if (vi.isNotEmpty)
                          Text(vi,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: AppColors.honey,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onSend,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.arrow_upward_rounded, size: 22, semanticLabel: S.chatSayThis(en)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tool(IconData icon, String label, VoidCallback? onTap, {bool active = false}) {
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: active ? AppColors.honeySoft : AppColors.cream,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 24, color: AppColors.ink),
              ),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _micButton() {
    final size = 84 + (_listening ? (_level * 160).clamp(0.0, 22.0) : 0.0);
    return Semantics(
      button: true,
      label: S.micLabel,
      child: GestureDetector(
        onTap: _tapMic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: _listening ? null : AppGradients.honey,
            color: _listening ? AppColors.berry : null,
            shape: BoxShape.circle,
            boxShadow: AppShadows.glow(_listening ? AppColors.berry : AppColors.honeyDeep),
          ),
          child: Icon(
            _listening ? Icons.hearing_rounded : (_busy ? Icons.more_horiz_rounded : Icons.mic_rounded),
            size: 44,
            color: _listening ? AppColors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }

  Widget _endCard() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SoftCard(
        child: Column(
          children: [
            const Text(S.talkDoneTitle, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const StarRow(stars: 3, size: 36),
            const SizedBox(height: 12),
            PillButton(label: S.talkOther, icon: Icons.arrow_forward_rounded, onPressed: () => context.pop()),
          ],
        ),
      ),
    );
  }
}
