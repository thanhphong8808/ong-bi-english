// lib/features/talk_with_bi/bi_chat.dart
//
// The thinking part of the chat with Bi, free of Flutter so it can be tested:
// Bi's instructions for Gemma, example turns that show the reply format, the
// line-by-line parser for streamed replies and the small deterministic
// helpers (rescue phrases, the quick echo, suggestion parsing, cleaning).
//
// Every reply comes in tagged lines, so one model turn gives Bi everything
// it needs: what it heard, a correct sentence to repeat when the child said
// only a word or two, its English reply, the Vietnamese meaning, an easier
// question for when the child stays silent, three answers to suggest and one
// safe fact for Bi's notebook.
import '../../core/services/content_filter.dart';
import '../../curriculum/bi_notes.dart';
import '../../curriculum/bi_world.dart';
import '../../curriculum/scorers/text_normalizer.dart';

class BiChatContext {
  const BiChatContext({
    required this.childName,
    required this.level,
    required this.notes,
    required this.news,
    this.topicEn,
    this.topicWords = const [],
    this.recent = const [],
  });

  final String childName;
  final int level;
  final BiNotes notes;
  final BiLine news;
  final String? topicEn;
  final List<String> topicWords;

  /// The last real exchanges (user message, model reply) when a long chat
  /// restarts its conversation to free memory.
  final List<(String, String)> recent;

  bool get lowLevel => level <= 1;
}

class BiSuggestion {
  const BiSuggestion(this.emoji, this.en, this.vi);

  final String emoji;
  final String en;
  final String vi;
}

enum BiRescue { none, again, dontKnow, slowly, howSay }

class BiChat {
  const BiChat._();

  static const List<String> tags = ['HEARD', 'FIX', 'BI', 'VI', 'EASY', 'SAY', 'NOTE', 'TEACH', 'TEACHVI'];

  static const List<String> _cefr = ['Pre-A1 (beginner)', 'Pre-A1', 'A1', 'A2', 'A2+', 'B1'];

  static int maxWords(int level) => level <= 1 ? 8 : (level <= 3 ? 12 : 16);

  /// Bi's first question for a topic chat (no model call, so it is instant),
  /// with three answers the child can tap. Null for an unknown topic.
  static (String en, String vi, List<BiSuggestion> says)? topicOpener(String topicId) =>
      _topicOpeners[topicId];

  static const Map<String, (String, String, List<BiSuggestion>)> _topicOpeners = {
    'daily': ('What do you eat for breakfast?', 'Bữa sáng cậu hay ăn gì?', [
      BiSuggestion('🍜', 'I eat noodles.', 'Tớ ăn mì.'),
      BiSuggestion('🥖', 'I eat bread.', 'Tớ ăn bánh mì.'),
      BiSuggestion('🍚', 'I eat rice.', 'Tớ ăn cơm.'),
    ]),
    'school': ('What do you like to do in class?', 'Ở lớp cậu thích làm gì?', [
      BiSuggestion('🖍️', 'I like to draw.', 'Tớ thích vẽ.'),
      BiSuggestion('📖', 'I like to read.', 'Tớ thích đọc sách.'),
      BiSuggestion('🎵', 'I like to sing.', 'Tớ thích hát.'),
    ]),
    'street': ('Do you like cars or bikes?', 'Cậu thích ô tô hay xe đạp?', [
      BiSuggestion('🚗', 'I like cars.', 'Tớ thích ô tô.'),
      BiSuggestion('🚲', 'I like bikes.', 'Tớ thích xe đạp.'),
      BiSuggestion('🚌', 'I like buses.', 'Tớ thích xe buýt.'),
    ]),
    'play': ('What do you like to play?', 'Cậu thích chơi gì?', [
      BiSuggestion('⚽', 'I like to play ball.', 'Tớ thích chơi bóng.'),
      BiSuggestion('🪁', 'I like to fly a kite.', 'Tớ thích thả diều.'),
      BiSuggestion('🛝', 'I like the slide.', 'Tớ thích cầu trượt.'),
    ]),
    'family': ('Who is in your family?', 'Nhà cậu có những ai?', [
      BiSuggestion('👨‍👩‍👧', 'Mum, Dad and me.', 'Mẹ, bố và tớ.'),
      BiSuggestion('👵', 'My grandma.', 'Bà của tớ.'),
      BiSuggestion('👦', 'My brother.', 'Anh trai tớ.'),
    ]),
    'food': ('What is your favourite food?', 'Món cậu thích nhất là gì?', [
      BiSuggestion('🍜', 'I like noodles.', 'Tớ thích mì.'),
      BiSuggestion('🍚', 'I like rice.', 'Tớ thích cơm.'),
      BiSuggestion('🍰', 'I like cake.', 'Tớ thích bánh ngọt.'),
    ]),
    'shopping': ('What do you want to buy?', 'Cậu muốn mua gì nào?', [
      BiSuggestion('🧸', 'A toy, please!', 'Một món đồ chơi ạ!'),
      BiSuggestion('🍎', 'Some apples.', 'Mấy quả táo.'),
      BiSuggestion('🍦', 'An ice cream!', 'Một cây kem!'),
    ]),
    'health': ('How do you feel today?', 'Hôm nay cậu thấy trong người thế nào?', [
      BiSuggestion('💪', 'I feel good!', 'Tớ thấy khoẻ lắm!'),
      BiSuggestion('😴', "I'm tired.", 'Tớ mệt.'),
      BiSuggestion('🤧', 'I have a cold.', 'Tớ bị cảm.'),
    ]),
    'animals': ('What animal do you like?', 'Cậu thích con vật nào?', [
      BiSuggestion('🐶', 'I like dogs.', 'Tớ thích chó.'),
      BiSuggestion('🐱', 'I like cats.', 'Tớ thích mèo.'),
      BiSuggestion('🐟', 'I like fish.', 'Tớ thích cá.'),
    ]),
    'weather': ('Is it sunny or rainy today?', 'Hôm nay trời nắng hay mưa?', [
      BiSuggestion('☀️', "It's sunny.", 'Trời nắng.'),
      BiSuggestion('🌧️', "It's rainy.", 'Trời mưa.'),
      BiSuggestion('☁️', "It's cloudy.", 'Trời nhiều mây.'),
    ]),
    'feelings': ('Are you happy today?', 'Hôm nay cậu có vui không?', [
      BiSuggestion('😄', "Yes, I'm happy!", 'Có, tớ vui lắm!'),
      BiSuggestion('🙂', "I'm OK.", 'Tớ bình thường.'),
      BiSuggestion('😢', "I'm a little sad.", 'Tớ hơi buồn.'),
    ]),
    'holidays': ('Do you like birthday parties?', 'Cậu có thích tiệc sinh nhật không?', [
      BiSuggestion('🎂', 'Yes, I do!', 'Có, tớ thích!'),
      BiSuggestion('🍰', 'I love cake!', 'Tớ mê bánh kem!'),
      BiSuggestion('🏮', 'I like lanterns.', 'Tớ thích đèn lồng.'),
    ]),
  };

  /// Sampling: warm enough to sound alive, low enough to keep the format.
  static const double temperature = 0.7;
  static const int topK = 40;
  static const double topP = 0.95;
  static const int maxOutputTokens = 230;

  /// Model turns before the conversation is restarted with a short memory.
  static const int turnsPerConversation = 8;

  static String systemPrompt(BiChatContext c) {
    final name = c.childName.isEmpty ? 'the child' : c.childName;
    final out = StringBuffer()
      ..writeln(BiWorld.personaEn)
      ..writeln(
        'You are chatting by voice with $name, a 6-year-old Vietnamese child learning English '
        '(level ${_cefr[c.level.clamp(0, 5)]}).',
      );
    if (c.topicEn != null) {
      out.writeln(
        'Today you like to talk about ${c.topicEn}'
        '${c.topicWords.isEmpty ? '' : ' (words: ${c.topicWords.take(12).join(', ')})'}. '
        'Follow the child if they want to talk about something else that is safe.',
      );
    }
    if (!c.notes.isEmpty) {
      out.writeln('Things $name told you before: ${c.notes.describeEn()}. Talk about them sometimes, '
          'like a friend who remembers ("I remember you like ...!").');
    }
    out
      ..writeln("Today's garden news: ${c.news.en}")
      ..writeln()
      ..writeln('How to talk:')
      ..writeln('- Be warm, curious and playful, like a good friend. React to what the child really said, '
          'then ask one easy question about it. Do not repeat the same question.')
      ..writeln('- BI is 1 or 2 short sentences, at most ${maxWords(c.level)} words each, in simple everyday English '
          'for a young beginner. End BI with one easy question.')
      ..writeln('- Never say the child is wrong. If the child made a mistake or said only one or two words, '
          'write the full correct sentence in FIX. Otherwise FIX is -.')
      ..writeln('- If the child speaks Vietnamese, understand it, answer in simple English, and put the English '
          'way to say it in FIX.')
      ..writeln('- Talk only about happy, safe things for young children. Never ask for or talk about addresses, '
          'schools, phone numbers, full names, photos, money or meeting anyone. Never ask the child to keep a '
          'secret. If the child is sad, scared or hurt, be kind and tell them to talk to Mum, Dad or a teacher.')
      ..writeln('- No emoji in BI, VI, EASY or FIX. No lists, no markdown.')
      ..writeln()
      ..writeln('Always answer in exactly this format, one item per line:')
      ..writeln('HEARD: what the child said, in their own words and language')
      ..writeln('FIX: the correct short English sentence for the child to say, or -')
      ..writeln('BI: your reply in English')
      ..writeln('VI: the same reply in natural Vietnamese for a child (Bi says "tớ", the child is "cậu"), '
          'with every English word translated (cats -> mèo)')
      ..writeln('EASY: a very easy yes/no or either/or question about the same thing')
      ..writeln('SAY: emoji | a short English answer the child could say | its Vietnamese')
      ..writeln('SAY: emoji | another answer | Vietnamese')
      ..writeln('SAY: emoji | another answer | Vietnamese')
      ..writeln('NOTE: key=value for one new safe fact the child just said in this message (keys: colour, animal, '
          'food, fruit, toy, game, place, pet, pet_name, hobby, today, wish), or - when the child told you nothing new')
      ..writeln()
      ..writeln('When the message starts with TEACH, the child asked in Vietnamese how to say something in English. '
          'Then answer in this format:')
      ..writeln('HEARD: what the child said')
      ..writeln('TEACH: the English sentence, short and simple')
      ..writeln('TEACHVI: its Vietnamese meaning')
      ..writeln('BI: You can say: "the English sentence" Can you say it?')
      ..writeln('VI: the same in Vietnamese');
    return out.toString();
  }

  /// Example turns (user, model) that show the format with this child.
  static List<Map<String, String>> examples(BiChatContext c) {
    final shots = <Map<String, String>>[
      {
        'user': userTurn('i like noodle'),
        'model': 'HEARD: i like noodle\n'
            'FIX: I like noodles.\n'
            'BI: Noodles are yummy! Do you like noodles with egg?\n'
            'VI: Mì ngon lắm! Cậu có thích mì với trứng không?\n'
            'EASY: Do you like eggs?\n'
            'SAY: 👍 | Yes, I do! | Có, tớ thích!\n'
            "SAY: 👎 | No, I don't. | Không, tớ không thích.\n"
            'SAY: 🍗 | I like chicken. | Tớ thích thịt gà.\n'
            'NOTE: food=noodles',
      },
      {
        'user': userTurn('con thich con meo', audio: true),
        'model': 'HEARD: con thích con mèo\n'
            'FIX: I like cats.\n'
            'BI: Cats are so cute! What colour is your cat?\n'
            'VI: Mèo dễ thương quá! Con mèo của cậu màu gì?\n'
            'EASY: Is it white or black?\n'
            "SAY: 🤍 | It's white. | Nó màu trắng.\n"
            "SAY: 🖤 | It's black. | Nó màu đen.\n"
            "SAY: 🧡 | It's orange. | Nó màu cam.\n"
            'NOTE: animal=cats',
      },
      {
        'user': teachTurn('con muon uong nuoc', audio: true),
        'model': 'HEARD: con muốn uống nước\n'
            'TEACH: Can I have some water, please?\n'
            'TEACHVI: Cho con xin ít nước được không ạ?\n'
            'BI: You can say: "Can I have some water, please?" Can you say it?\n'
            'VI: Cậu có thể nói: "Can I have some water, please?" Cậu nói thử nhé?',
      },
    ];
    for (final (user, model) in c.recent) {
      shots.add({'user': user, 'model': model});
    }
    return shots;
  }

  /// One child turn for the model.
  static String userTurn(String heard, {bool audio = false}) {
    final text = heard.trim();
    if (audio) {
      return 'Child (audio). Speech recognizer guess: "${text.replaceAll('"', "'")}"';
    }
    return 'Child: $text';
  }

  /// "Bi ơi, nói thế nào?": the child asks in Vietnamese.
  static String teachTurn(String heard, {bool audio = false}) {
    final text = heard.trim();
    if (audio) {
      return 'TEACH (audio). Speech recognizer guess: "${text.replaceAll('"', "'")}"';
    }
    return 'TEACH: $text';
  }

  // ------------------------------------------------------------- helpers

  // Upper case only: "You can say:" inside a reply is not a SAY line.
  static final RegExp _tagAt = RegExp(r'(?:^|\s)(HEARD|FIX|BI|VI|EASY|SAY|NOTE|TEACH|TEACHVI)\s*:');

  /// Splits one output line into (tag, value) pairs; a line without a tag
  /// continues the previous item (tag '').
  static List<(String, String)> splitLine(String line) {
    final text = line.trim().replaceAll(RegExp(r'^\*+|\*+$'), '');
    if (text.isEmpty) {
      return const [];
    }
    final matches = _tagAt.allMatches(text).toList();
    if (matches.isEmpty) {
      return [('', text)];
    }
    final out = <(String, String)>[];
    if (matches.first.start > 0) {
      final head = text.substring(0, matches.first.start).trim();
      if (head.isNotEmpty) {
        out.add(('', head));
      }
    }
    for (var i = 0; i < matches.length; i++) {
      final m = matches[i];
      final end = i + 1 < matches.length ? matches[i + 1].start : text.length;
      out.add((m.group(1)!, text.substring(m.end, end).trim()));
    }
    return out;
  }

  /// English to speak: cleaned, unsafe text refused (null), sentences much
  /// too long for the level dropped.
  static String? speakableEnglish(String raw, ContentFilter filter, int level) {
    // The whole reply first: splitting at dots would cut a web address into
    // harmless-looking pieces.
    if (filter.unsafeText(raw) || filter.unsafeText(ContentFilter.cleanModelText(raw))) {
      return null;
    }
    final pieces = RegExp(r'[^.!?…]+[.!?…]*').allMatches(raw).map((m) => m.group(0)!);
    final keep = <String>[];
    final limit = (maxWords(level) * 1.5).round();
    for (final piece in pieces) {
      final sentence = ContentFilter.cleanModelText(piece);
      if (sentence.isEmpty) {
        continue;
      }
      if (filter.unsafeText(sentence)) {
        return null;
      }
      if (ContentFilter.wordCount(sentence) > limit) {
        continue;
      }
      keep.add(sentence);
      if (keep.length >= 3) {
        break;
      }
    }
    return keep.isEmpty ? null : keep.join(' ');
  }

  /// Vietnamese meaning to show: emoji and markdown removed, unsafe refused.
  static String? showableVietnamese(String raw, ContentFilter filter) {
    final text = raw
        .replaceAll(RegExp(r'[*_#`]'), '')
        .replaceAll(RegExp(r'[\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.isEmpty || text == '-' || text.length > 220 || filter.unsafeText(text)) {
      return null;
    }
    return text;
  }

  /// "emoji | English | Vietnamese" -> a suggestion, or null.
  static BiSuggestion? suggestion(String raw, ContentFilter filter, int level) {
    final parts = raw.split('|').map((s) => s.trim()).toList();
    if (parts.length < 2) {
      return null;
    }
    String emoji;
    String en;
    String vi;
    if (parts.length >= 3) {
      emoji = parts[0];
      en = parts[1];
      vi = parts[2];
    } else {
      emoji = '💬';
      en = parts[0];
      vi = parts[1];
    }
    if (emoji.isEmpty || emoji.length > 12 || RegExp(r'[A-Za-z]').hasMatch(emoji)) {
      emoji = '💬';
    }
    final english = ContentFilter.cleanModelText(en);
    if (english.isEmpty ||
        ContentFilter.wordCount(english) > maxWords(level) + 2 ||
        filter.unsafeText(english)) {
      return null;
    }
    final meaning = showableVietnamese(vi, filter) ?? '';
    return BiSuggestion(emoji, english, meaning);
  }

  /// The correct sentence for the child to repeat, or null for "-".
  static String? fixSentence(String raw, ContentFilter filter, int level) {
    final t = raw.trim();
    if (t.isEmpty || t == '-' || t.toLowerCase() == 'none') {
      return null;
    }
    final english = ContentFilter.cleanModelText(t);
    if (english.isEmpty ||
        ContentFilter.wordCount(english) > maxWords(level) + 2 ||
        filter.unsafeText(english)) {
      return null;
    }
    return english;
  }

  /// True when Bi should invite the child to repeat [fix]: the child said
  /// only a word or two, or something clearly different from it.
  static bool shouldPractise(String heard, String fix) {
    final said = TextNormalizer.tokens(heard);
    final target = TextNormalizer.tokens(fix);
    if (target.isEmpty || said.join(' ') == target.join(' ')) {
      return false;
    }
    if (said.length <= 2) {
      return true;
    }
    final shared = said.toSet().intersection(target.toSet()).length;
    return shared < target.length * 0.6;
  }

  static BiRescue rescue(String text) {
    final n = ' ${TextNormalizer.tokens(text).join(' ')} ';
    if (n.trim().isEmpty) {
      return BiRescue.none;
    }
    if (n.contains(' how do you say ') || n.contains(' how to say ') || n.contains(' in english ')) {
      return BiRescue.howSay;
    }
    if (n.contains(' again ') || n.contains(' repeat ') || n.contains(' pardon ') || n.contains(' what did you say ')) {
      return BiRescue.again;
    }
    if (n.contains(' slowly ') || n.contains(' slow down ')) {
      return BiRescue.slowly;
    }
    if (n.contains(' dont know ') || n.contains(' do not know ') || n.contains(' no idea ') || n.contains(" don't know ")) {
      return BiRescue.dontKnow;
    }
    return BiRescue.none;
  }

  static const Set<String> _stop = {
    'i', 'a', 'an', 'the', 'is', 'am', 'are', 'it', 'yes', 'no', 'and', 'or', 'to', 'do', 'like', 'my', 'you',
    'me', 'have', 'has', 'want', 'can', 'what', 'this', 'that', 'he', 'she', 'we', 'they', 'too', 'very', 'so',
    'of', 'in', 'on', 'at', 'with', 'for', 'not', 'dont', 'im', 'its', 'love', 'go', 'play', 'eat', 'see',
  };

  /// A word from what the child said that Bi can echo at once ("Noodles!")
  /// while it thinks, or null.
  static String? echoWord(String heard, Set<String> vocabulary) {
    String? best;
    for (final token in TextNormalizer.tokens(heard)) {
      if (token.length < 3 || _stop.contains(token)) {
        continue;
      }
      final known = vocabulary.contains(token) ||
          (token.endsWith('s') && vocabulary.contains(token.substring(0, token.length - 1)));
      if (known && (best == null || token.length > best.length)) {
        best = token;
      }
    }
    return best;
  }

  static const List<String> _echoes = ['Oh, %!', '%! Nice!', 'Mmm, %!', '%? Cool!'];

  static String echoLine(String word, int turn) {
    final w = word[0].toUpperCase() + word.substring(1);
    final template = _echoes[turn % _echoes.length];
    return template.startsWith('%') ? template.replaceFirst('%', w) : template.replaceFirst('%', word);
  }

  /// The last question in [bi], for when the model gave no EASY line.
  static String? lastQuestion(String bi) {
    final pieces = RegExp(r'[^.!?…]+[?]').allMatches(bi).map((m) => m.group(0)!.trim()).toList();
    return pieces.isEmpty ? null : pieces.last;
  }
}

/// Collects streamed text into complete tagged lines.
class BiTurnParser {
  final StringBuffer _buffer = StringBuffer();
  String _lastTag = '';

  /// Feeds a chunk; returns the items completed by it.
  List<(String, String)> feed(String chunk) {
    _buffer.write(chunk);
    final text = _buffer.toString();
    final cut = text.lastIndexOf('\n');
    if (cut < 0) {
      return const [];
    }
    _buffer
      ..clear()
      ..write(text.substring(cut + 1));
    return _lines(text.substring(0, cut));
  }

  /// The rest of the reply at the end of the stream.
  List<(String, String)> close() {
    final text = _buffer.toString();
    _buffer.clear();
    return _lines(text);
  }

  List<(String, String)> _lines(String text) {
    final out = <(String, String)>[];
    for (final line in text.split('\n')) {
      for (final (tag, value) in BiChat.splitLine(line)) {
        if (tag.isEmpty) {
          // A continued line belongs to the item before it.
          out.add((_lastTag, value));
        } else {
          _lastTag = tag;
          out.add((tag, value));
        }
      }
    }
    return out;
  }
}
