// lib/features/talk_with_bi/bi_brain.dart
//
// The conversation logic of "Talk with Bi", independent of Flutter so it can
// be tested with a fake model. Safety does not depend on the model behaving:
// every child utterance and every model sentence passes deterministic checks
// before anything is spoken.
import 'dart:async';
import 'dart:math';

import '../../core/config/app_config.dart';
import '../../core/services/content_filter.dart';
import '../../curriculum/basic_words.dart';
import '../../curriculum/scorers/text_normalizer.dart';
import 'bi_scenarios.dart';

enum BiMode { chat, rolePlay, story }

/// Anything that can hold a conversation: the real Gemma bridge or a fake.
abstract class ChatModel {
  Future<void> start(String systemPrompt);

  Stream<String> send(String text);

  Future<void> cancel();
}

class BiContext {
  const BiContext({
    required this.level,
    required this.childName,
    required this.knownWords,
    required this.learningWords,
    required this.topicEn,
    required this.topicWords,
    required this.mode,
    this.scenario,
    this.story,
    this.support = VietnameseSupport.normal,
  });

  final int level;
  final String childName;

  /// Every English word the child has met (lower case).
  final Set<String> knownWords;

  /// Words of the current unit.
  final List<String> learningWords;
  final String topicEn;

  /// Concrete, picturable words of the topic, used for hints and fallbacks.
  final List<String> topicWords;
  final BiMode mode;
  final BiScenario? scenario;
  final BiStory? story;
  final VietnameseSupport support;

  bool get lowLevel => level <= 1;
}

/// A hint button: what the child can say.
class BiHint {
  const BiHint(this.text, {this.emoji = '💬'});

  final String text;
  final String emoji;
}

sealed class BiEvent {
  const BiEvent();
}

/// One English sentence to speak now.
class BiSay extends BiEvent {
  const BiSay(this.text, {this.fromModel = true});

  final String text;
  final bool fromModel;
}

/// A Vietnamese support line to speak (hints, comfort).
class BiSayVi extends BiEvent {
  const BiSayVi(this.text);

  final String text;
}

/// Hint buttons to show.
class BiHints extends BiEvent {
  const BiHints(this.hints);

  final List<BiHint> hints;
}

/// A safety rule fired. The turn is logged as flagged for parents.
class BiFlag extends BiEvent {
  const BiFlag(this.reason);

  /// distress | inappropriate_input | filtered_output | too_hard | model_error
  final String reason;
}

/// End of Bi's turn.
class BiDone extends BiEvent {
  const BiDone();
}

class BiPromptBuilder {
  const BiPromptBuilder();

  static const List<String> _cefr = ['Pre-A1 (beginner)', 'Pre-A1', 'A1', 'A2', 'A2+', 'B1'];

  String build(BiContext c) {
    final words = <String>{
      ...c.learningWords,
      ...c.topicWords,
      ...c.knownWords,
    }.take(AppConfig.biPromptKnownWordsMax).join(', ');
    final maxWords = c.lowLevel ? AppConfig.biMaxWordsPerSentenceLow : AppConfig.biMaxWordsPerSentenceHigh;
    final buffer = StringBuffer()
      ..writeln(
        'You are Bi, a cheerful and patient 7-year-old bee. You talk with ${c.childName}, '
        'a Vietnamese child who is learning English (level ${_cefr[c.level.clamp(0, 5)]}).',
      )
      ..writeln('Rules you always follow:')
      ..writeln(
        '- Answer in simple English only, with at most ${AppConfig.biMaxSentencesPerTurn} short sentences '
        'and at most $maxWords words in each sentence.',
      )
      ..writeln(
        '- Use only words the child knows: $words, and very common little words. '
        'You may use at most ${AppConfig.biMaxNewWordsPerTurn} new word; if you do, explain it with easy words.',
      )
      ..writeln('- End every answer with exactly one easy question the child can answer in a few words.')
      ..writeln(
        '- If the child makes a mistake, never say it is wrong. Just use the correct words naturally in your answer.',
      )
      ..writeln(
        '- Talk only about happy, safe things for children aged 6 to 10: animals, food, colours, toys, '
        'family, school, games, nature and stories.',
      )
      ..writeln(
        '- Never ask for or talk about addresses, school names, phone numbers, passwords, photos, money '
        'or meeting anyone. Never pretend to be a real person. Never ask the child to keep a secret from parents.',
      )
      ..writeln(
        '- If the child seems sad, scared or hurt, be kind and tell them to talk to Mum, Dad or a teacher.',
      )
      ..writeln('- Do not use emoji, lists or special symbols.');
    switch (c.mode) {
      case BiMode.chat:
        buffer.writeln('Today you chat about "${c.topicEn}". Useful words: ${c.topicWords.join(', ')}.');
      case BiMode.rolePlay:
        final s = c.scenario;
        if (s != null) {
          buffer.writeln(
            'Role play: you are ${s.biRole} at ${s.place}. The child is ${s.kidRole}. '
            'Stay in the role and move the situation forward one small step at a time.',
          );
        }
      case BiMode.story:
        final s = c.story;
        if (s != null) {
          buffer.writeln(
            'Story time: tell a very short story about ${s.seed}. Tell it one small part at a time, '
            'then ask the child a question about what happens next. Use the child\'s ideas.',
          );
        }
    }
    return buffer.toString();
  }
}

class BiBrain {
  BiBrain({
    required this.model,
    required this.context,
    this.filter = const ContentFilter(),
    Random? random,
  }) : _random = random ?? Random();

  final ChatModel model;
  final BiContext context;
  final ContentFilter filter;
  final Random _random;

  int _silentTurns = 0;
  bool _started = false;
  String _lastQuestion = '';

  static final RegExp _sentenceEnd = RegExp(r'[.!?]+(?=\s|$)');

  String get lastQuestion => _lastQuestion;

  Future<void> start() async {
    await model.start(const BiPromptBuilder().build(context));
    _started = true;
  }

  /// Bi's fixed first line for the chosen mode (no model call, no waiting).
  List<BiEvent> opener() {
    final String line;
    switch (context.mode) {
      case BiMode.rolePlay:
        line = context.scenario?.opener ?? 'Hello! Shall we play?';
      case BiMode.story:
        line = context.story?.opener ?? "Let's make a story together! Who is in our story?";
      case BiMode.chat:
        final word = _topicWord();
        line = word == null
            ? 'Hi ${context.childName}! How are you today?'
            : 'Hi ${context.childName}! Do you like $word?';
    }
    _lastQuestion = line;
    return [BiSay(line, fromModel: false), BiHints(hintsFor(line)), const BiDone()];
  }

  String? _topicWord() {
    if (context.topicWords.isEmpty) {
      return null;
    }
    return context.topicWords[_random.nextInt(context.topicWords.length)];
  }

  /// English words of the child's utterance that are in [vocabulary].
  static List<String> usedWords(String childText, Iterable<String> vocabulary) {
    final tokens = TextNormalizer.tokens(childText).toSet();
    final out = <String>[];
    for (final word in vocabulary) {
      final w = word.toLowerCase();
      if (!w.contains(' ') && (tokens.contains(w) || wordVariants(w).any(tokens.contains))) {
        out.add(word);
      }
    }
    return out;
  }

  /// Unknown-word count of a sentence for this child.
  int unknownWords(String sentence) {
    var count = 0;
    final skip = {context.childName.toLowerCase()};
    for (final word in wordTokens(sentence)) {
      if (skip.contains(word)) {
        continue;
      }
      if (!isKnownWord(word, context.knownWords)) {
        count++;
      }
    }
    return count;
  }

  /// Handles one child turn and yields what Bi says.
  Stream<BiEvent> respond(String childText, {int speechMs = 1000}) async* {
    final text = childText.trim();

    // Silence or noise.
    if (text.isEmpty || speechMs < AppConfig.minAnswerSpeechMs) {
      _silentTurns++;
      yield* _encourage();
      return;
    }

    final check = filter.checkInput(text);
    if (check.distress) {
      _silentTurns = 0;
      yield const BiFlag('distress');
      yield const BiSay(ContentFilter.distressReplyEn, fromModel: false);
      yield const BiSayVi(ContentFilter.distressReplyVi);
      yield const BiDone();
      return;
    }
    if (check.inappropriate) {
      _silentTurns = 0;
      yield const BiFlag('inappropriate_input');
      yield const BiSay(ContentFilter.redirectReplyEn, fromModel: false);
      _lastQuestion = ContentFilter.redirectReplyEn;
      yield BiHints(hintsFor(ContentFilter.redirectReplyEn));
      yield const BiDone();
      return;
    }

    // Probably Vietnamese or unclear: almost no known English words.
    final tokens = wordTokens(text);
    final knownCount = tokens.where((w) => isKnownWord(w, context.knownWords)).length;
    if (tokens.isNotEmpty && knownCount == 0) {
      _silentTurns++;
      yield* _encourage();
      return;
    }
    _silentTurns = 0;

    if (!_started) {
      try {
        await start();
      } catch (_) {
        yield const BiFlag('model_error');
        yield* _fallbackTurn();
        return;
      }
    }

    yield* _modelTurn(text);
  }

  Stream<BiEvent> _encourage() async* {
    final threshold = switch (context.support) {
      VietnameseSupport.high => 1,
      VietnameseSupport.normal => AppConfig.biSilentTurnsBeforeHint,
      VietnameseSupport.low => AppConfig.biSilentTurnsBeforeHint + 1,
    };
    final hints = hintsFor(_lastQuestion);
    final useVietnamese =
        _silentTurns >= threshold && (context.level <= 4 || context.support == VietnameseSupport.high);
    if (useVietnamese) {
      yield BiSayVi(_vietnameseHint(hints.isNotEmpty ? hints.first.text : ''));
    } else {
      yield BiSay(context.lowLevel ? 'Take your time!' : 'Take your time. You can do it!', fromModel: false);
      if (_lastQuestion.isNotEmpty) {
        yield BiSay(_lastQuestion, fromModel: false);
      }
    }
    yield BiHints(hints);
    yield const BiDone();
  }

  String _vietnameseHint(String example) {
    if (context.level <= 1) {
      return example.isEmpty
          ? 'Cậu bấm vào một hình gợi ý để nghe, rồi nói theo tớ nhé!'
          : 'Cậu thử nói: "$example" nhé! Bấm vào hình gợi ý để nghe lại.';
    }
    if (context.level <= 3) {
      return 'Cậu có thể bấm hình gợi ý để nghe câu mẫu rồi nói theo.';
    }
    return 'Gợi ý ở các nút bên dưới nhé.';
  }

  Stream<BiEvent> _fallbackTurn() async* {
    final question = _fallbackQuestion();
    _lastQuestion = question;
    yield BiSay(_randomPraise(), fromModel: false);
    yield BiSay(question, fromModel: false);
    yield BiHints(hintsFor(question));
    yield const BiDone();
  }

  String _randomPraise() {
    const praise = ['Great!', 'Cool!', 'Nice!', 'I see!', 'Oh, wow!'];
    return praise[_random.nextInt(praise.length)];
  }

  String _fallbackQuestion() {
    final word = _topicWord();
    final options = <String>[
      if (word != null) 'Do you like $word?',
      "What's your favourite colour?",
      'Do you like animals?',
      'What do you like to eat?',
    ];
    return options[_random.nextInt(options.length)];
  }

  Stream<BiEvent> _modelTurn(String text) async* {
    final spoken = <String>[];
    var buffer = '';
    var flagged = false;

    Future<void> stopModel() async {
      try {
        await model.cancel();
      } catch (_) {
        // Already stopped.
      }
    }

    final sentences = StreamController<String>();
    late final StreamSubscription<String> sub;
    sub = model.send(text).timeout(const Duration(seconds: AppConfig.biReplyTimeoutSeconds)).listen(
      (chunk) {
        if (sentences.isClosed) {
          return;
        }
        buffer += chunk;
        while (true) {
          final match = _sentenceEnd.firstMatch(buffer);
          if (match == null) {
            break;
          }
          final sentence = buffer.substring(0, match.end);
          buffer = buffer.substring(match.end);
          sentences.add(sentence);
        }
      },
      onError: (Object _) {
        if (!sentences.isClosed) {
          sentences.addError(const _ModelFailure());
          sentences.close();
        }
      },
      onDone: () {
        // After an error the stream is already closed: drop the half sentence.
        if (sentences.isClosed) {
          return;
        }
        if (buffer.trim().isNotEmpty) {
          sentences.add(buffer);
        }
        buffer = '';
        sentences.close();
      },
    );

    try {
      await for (final raw in sentences.stream) {
        final sentence = ContentFilter.cleanModelText(raw);
        if (sentence.isEmpty) {
          continue;
        }
        final isLast = spoken.length == AppConfig.biMaxSentencesPerTurn - 1;
        final safety = filter.checkSentence(sentence, level: context.level);
        if (safety.blocked) {
          if (!flagged) {
            flagged = true;
            yield BiFlag(safety.reason == FilterReason.tooLong ? 'too_hard' : 'filtered_output');
          }
          await stopModel();
          break;
        }
        if (unknownWords(sentence) > AppConfig.biUnknownWordsTolerance[context.level.clamp(0, 5)]) {
          if (!flagged) {
            flagged = true;
            yield const BiFlag('too_hard');
          }
          await stopModel();
          break;
        }
        final isQuestion = sentence.endsWith('?');
        if (isLast && !isQuestion) {
          // The last allowed sentence must be the question.
          await stopModel();
          break;
        }
        spoken.add(sentence);
        yield BiSay(sentence);
        if (isQuestion || spoken.length >= AppConfig.biMaxSentencesPerTurn) {
          _lastQuestion = sentence;
          await stopModel();
          break;
        }
      }
    } on _ModelFailure {
      if (!flagged) {
        yield const BiFlag('model_error');
      }
    } finally {
      await sub.cancel();
      if (!sentences.isClosed) {
        unawaited(sentences.close());
      }
    }

    // Make sure the turn ends with exactly one easy question.
    if (spoken.isEmpty) {
      final question = _fallbackQuestion();
      _lastQuestion = question;
      yield BiSay(flagged ? "Let's talk about something fun!" : _randomPraise(), fromModel: false);
      yield BiSay(question, fromModel: false);
    } else if (!spoken.last.endsWith('?')) {
      final question = _fallbackQuestion();
      _lastQuestion = question;
      yield BiSay(question, fromModel: false);
    }
    yield BiHints(hintsFor(_lastQuestion));
    yield const BiDone();
  }

  /// Deterministic reply suggestions for Bi's last question.
  List<BiHint> hintsFor(String question) {
    final q = question.toLowerCase();
    final word = _topicWord();
    final hints = <BiHint>[];
    if (RegExp(r'^(do|does|can|is|are|did|was|were|have|would|will|shall)\b').hasMatch(q) ||
        q.contains(' do you ') ||
        q.contains(' can you ') ||
        q.contains(' are you ')) {
      hints.add(const BiHint('Yes, I do!', emoji: '👍'));
      hints.add(const BiHint("No, I don't.", emoji: '👎'));
      if (q.contains('can you')) {
        hints
          ..clear()
          ..add(const BiHint('Yes, I can!', emoji: '👍'))
          ..add(const BiHint("No, I can't.", emoji: '👎'));
      } else if (q.contains('are you') || q.startsWith('is ')) {
        hints
          ..clear()
          ..add(const BiHint('Yes!', emoji: '👍'))
          ..add(const BiHint('No.', emoji: '👎'));
      }
    }
    if (q.contains('colour') || q.contains('color')) {
      hints.add(const BiHint('I like blue.', emoji: '🔵'));
      hints.add(const BiHint('Red!', emoji: '🔴'));
    }
    if (q.contains('how many') || q.contains('how old')) {
      hints.add(BiHint(q.contains('old') ? "I'm six." : 'Three!', emoji: '🔢'));
    }
    if (q.contains('how are you') || q.contains('feeling')) {
      hints.add(const BiHint("I'm fine, thank you!", emoji: '😊'));
      hints.add(const BiHint("I'm happy!", emoji: '😄'));
    }
    if (q.contains('eat') || q.contains('food') || q.contains('hungry')) {
      hints.add(const BiHint('I like rice.', emoji: '🍚'));
    }
    final scenario = context.scenario;
    if (context.mode == BiMode.rolePlay && scenario != null) {
      for (final h in scenario.hints) {
        hints.add(BiHint(h, emoji: scenario.emoji));
      }
    }
    if (word != null) {
      hints.add(BiHint('I like $word.', emoji: '❤️'));
    }
    if (hints.isEmpty) {
      hints.add(const BiHint('Yes!', emoji: '👍'));
      hints.add(const BiHint('I like it.', emoji: '❤️'));
    }
    final unique = <String, BiHint>{};
    for (final h in hints) {
      unique.putIfAbsent(h.text, () => h);
    }
    return unique.values.take(AppConfig.biHintButtons).toList();
  }
}

class _ModelFailure implements Exception {
  const _ModelFailure();
}
