// test/bi_chat_test.dart
//
// Safety and format suite for the chat with Bi. The model is not needed:
// these tests feed replies (safe, unsafe, broken, streamed in pieces)
// through the same parser and checks the chat screen uses, so whatever the
// model writes, the child only sees and hears child-safe text.
import 'package:flutter_test/flutter_test.dart';
import 'package:ong_bi_english/core/services/content_filter.dart';
import 'package:ong_bi_english/curriculum/bi_notes.dart';
import 'package:ong_bi_english/curriculum/bi_world.dart';
import 'package:ong_bi_english/features/talk_with_bi/bi_chat.dart';

const filter = ContentFilter();

BiChatContext ctx({int level = 1, BiNotes? notes}) => BiChatContext(
      childName: 'Mai',
      level: level,
      notes: notes ?? BiNotes.decode(null),
      news: BiWorld.news.first,
      topicEn: 'Pets',
      topicWords: const ['cat', 'dog'],
    );

List<(String, String)> parseAll(List<String> chunks) {
  final parser = BiTurnParser();
  final out = <(String, String)>[];
  for (final c in chunks) {
    out.addAll(parser.feed(c));
  }
  out.addAll(parser.close());
  return out;
}

void main() {
  group('streamed replies are split into tagged lines', () {
    test('lines split across chunks come out whole', () {
      final items = parseAll(const ['HEARD: i like ca', 't\nFIX: I like ', 'cats.\nBI: Cats are cute! Do you ', 'have a cat?\nVI: Mèo dễ thương!']);
      expect(items, [
        ('HEARD', 'i like cat'),
        ('FIX', 'I like cats.'),
        ('BI', 'Cats are cute! Do you have a cat?'),
        ('VI', 'Mèo dễ thương!'),
      ]);
    });

    test('several tags on one line are separated', () {
      final items = parseAll(const ['HEARD: hi BI: Hello! How are you? VI: Xin chào!']);
      expect(items.map((e) => e.$1), ['HEARD', 'BI', 'VI']);
      expect(items[1].$2, 'Hello! How are you?');
    });

    test('"You can say:" inside a reply is not a SAY line', () {
      final items = parseAll(const ['BI: You can say: "I like cats." Can you say it?\n']);
      expect(items, [('BI', 'You can say: "I like cats." Can you say it?')]);
    });

    test('a line without a tag continues the item before it', () {
      final items = parseAll(const ['BI: Cats are cute!\nDo you have a cat?\n']);
      expect(items, [('BI', 'Cats are cute!'), ('BI', 'Do you have a cat?')]);
    });
  });

  group('what Bi says is always safe', () {
    const unsafeReplies = <String>[
      'Visit www.games-for-kids.com to play! Do you like games?',
      'Go to https://example.org now. Do you like it?',
      'Call me on 0912 345 678. Do you like cats?',
      'Where do you live? I want to visit you.',
      'What is your phone number?',
      'Which school do you go to?',
      "Let's keep this our secret. Don't tell your mum!",
      'I live at 12 Oak Street. Do you like it?',
      'You are stupid. Do you like dogs?',
      'Zombies kill people. Are you scared?',
      'Send me a photo of you. Do you have a camera?',
      'Can you tell me your password?',
    ];
    for (final reply in unsafeReplies) {
      test('refuses: $reply', () {
        expect(BiChat.speakableEnglish(reply, filter, 3), isNull);
        expect(filter.unsafeText(reply), isTrue);
      });
    }

    test('emoji, markdown and stage directions are never read aloud', () {
      final text = BiChat.speakableEnglish('*waves* **Hello!** 🐝 (laughs) Do you like cats?', filter, 1)!;
      expect(text, 'Hello! Do you like cats?');
    });

    test('sentences far too long for the level are dropped, short ones kept', () {
      final text = BiChat.speakableEnglish(
        'Cats are wonderful animals that love to sleep in warm sunny places all day long. Do you like cats?',
        filter,
        0,
      );
      expect(text, 'Do you like cats?');
    });

    test('unsafe Vietnamese meanings are not shown', () {
      expect(BiChat.showableVietnamese('Nhà cậu ở đâu?', filter), isNull);
      expect(BiChat.showableVietnamese('Số điện thoại của cậu là gì?', filter), isNull);
      expect(BiChat.showableVietnamese('Mèo dễ thương quá! 🐱', filter), 'Mèo dễ thương quá!');
    });

    test('suggested answers are parsed, cleaned and checked', () {
      final s = BiChat.suggestion('👍 | Yes, I do! | Có, tớ thích!', filter, 1)!;
      expect((s.emoji, s.en, s.vi), ('👍', 'Yes, I do!', 'Có, tớ thích!'));
      expect(BiChat.suggestion('😈 | You are stupid. | Đồ ngốc.', filter, 1), isNull);
      expect(BiChat.suggestion('Yes | Có', filter, 1)!.emoji, '💬');
      expect(BiChat.suggestion('nothing here', filter, 1), isNull);
    });

    test('a FIX sentence is kept only when it is short and safe', () {
      expect(BiChat.fixSentence('I like cats.', filter, 1), 'I like cats.');
      expect(BiChat.fixSentence('-', filter, 1), isNull);
      expect(BiChat.fixSentence('Tell me your address.', filter, 1), isNull);
    });
  });

  group('helping the child', () {
    test('a word or two (or a different sentence) is practised, a good sentence is not', () {
      expect(BiChat.shouldPractise('cat', 'I like cats.'), isTrue);
      expect(BiChat.shouldPractise('i like cats', 'I like cats.'), isFalse);
      expect(BiChat.shouldPractise('me go park yesterday fun', 'I went to the park yesterday.'), isTrue);
    });

    test('rescue phrases are recognised', () {
      expect(BiChat.rescue('Say it again, please.'), BiRescue.again);
      expect(BiChat.rescue("I don't know."), BiRescue.dontKnow);
      expect(BiChat.rescue('Slowly, please.'), BiRescue.slowly);
      expect(BiChat.rescue('How do you say this in English?'), BiRescue.howSay);
      expect(BiChat.rescue('I like cats.'), BiRescue.none);
    });

    test('Bi echoes a word it knows from what the child said', () {
      expect(BiChat.echoWord('I like noodles', {'noodle', 'cat'}), 'noodles');
      expect(BiChat.echoWord('I like it', {'noodle'}), isNull);
      expect(BiChat.echoLine('noodles', 0), 'Oh, noodles!');
      expect(BiChat.echoLine('noodles', 1), 'Noodles! Nice!');
    });

    test('the last question of a reply is found for the easier retry', () {
      expect(BiChat.lastQuestion('Cats are cute! Do you have a cat?'), 'Do you have a cat?');
      expect(BiChat.lastQuestion('Cats are cute!'), isNull);
    });
  });

  group("Bi's notebook", () {
    test('keeps safe short facts, never digits, places or long text', () {
      expect(BiNotes.validate('animal', 'cats'), 'cats');
      expect(BiNotes.validate('pet_name', 'mimi'), 'Mimi');
      expect(BiNotes.validate('address', 'Hanoi'), isNull);
      expect(BiNotes.validate('food', 'pho 24'), isNull);
      expect(BiNotes.validate('colour', 'a very very long colour name here'), isNull);
      expect(BiNotes.validate('pet_name', 'Mimi Nguyen'), isNull);
    });

    test('model lines are read in either form and round-trip through storage', () {
      expect(BiNotes.parseLine('animal=cats'), ('animal', 'cats'));
      expect(BiNotes.parseLine('favourite color: blue'), ('colour', 'blue'));
      expect(BiNotes.parseLine('-'), isNull);
      final notes = BiNotes.decode(null)..put('animal', 'cats', 3);
      final again = BiNotes.decode(notes.encode());
      expect(again['animal'], 'cats');
      expect(again.describeEn(), 'favourite animal: cats');
    });
  });

  group('instructions for the model', () {
    test('state the safety rules, the child, the format and what Bi remembers', () {
      final notes = BiNotes.decode(null)..put('animal', 'cats', 1);
      final prompt = BiChat.systemPrompt(ctx(notes: notes));
      for (final rule in ['addresses', 'phone numbers', 'secret', 'Mum, Dad or a teacher', 'robot bee']) {
        expect(prompt.contains(rule), isTrue, reason: rule);
      }
      expect(prompt.contains('Mai'), isTrue);
      expect(prompt.contains('favourite animal: cats'), isTrue);
      for (final tag in ['HEARD:', 'FIX:', 'BI:', 'VI:', 'EASY:', 'SAY:', 'NOTE:', 'TEACH:', 'TEACHVI:']) {
        expect(prompt.contains(tag), isTrue, reason: tag);
      }
    });

    test('every example reply parses into safe, complete parts', () {
      for (final example in BiChat.examples(ctx())) {
        final items = parseAll([example['model']!]);
        final tags = items.map((e) => e.$1).toSet();
        expect(tags.containsAll({'HEARD', 'BI', 'VI'}), isTrue, reason: example['model']);
        for (final (tag, value) in items) {
          if (tag == 'BI') {
            expect(BiChat.speakableEnglish(value, filter, 0), isNotNull, reason: value);
          }
          if (tag == 'SAY') {
            expect(BiChat.suggestion(value, filter, 0), isNotNull, reason: value);
          }
          if (tag == 'NOTE') {
            final note = BiNotes.parseLine(value)!;
            expect(BiNotes.validate(note.$1, note.$2), isNotNull);
          }
        }
      }
    });

    test('child turns say whether Bi also hears the recording', () {
      expect(BiChat.userTurn('i like cat'), 'Child: i like cat');
      expect(BiChat.userTurn('i like "cat"', audio: true), 'Child (audio). Speech recognizer guess: "i like \'cat\'"');
      expect(BiChat.teachTurn('con muon', audio: true).startsWith('TEACH (audio)'), isTrue);
    });
  });

  group('sentence filter', () {
    test('cleans model text before it is spoken', () {
      expect(ContentFilter.cleanModelText('*jumps* Hello!! 🐝 [laughs]'), 'Hello!!');
      expect(ContentFilter.cleanModelText('I like **cats**.'), 'I like cats.');
    });

    test('checks one sentence without counting sentences', () {
      expect(filter.checkSentence('Do you like cats?', level: 0).blocked, isFalse);
      expect(filter.checkSentence('Go to kids.com', level: 0).reason, FilterReason.url);
      expect(filter.checkSentence('', level: 0).reason, FilterReason.empty);
    });
  });
}
