// test/pronunciation_scorer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ong_bi_english/core/config/app_config.dart';
import 'package:ong_bi_english/curriculum/scorers/pronunciation_scorer.dart';
import 'package:ong_bi_english/curriculum/scorers/spelling_scorer.dart';
import 'package:ong_bi_english/curriculum/scorers/text_normalizer.dart';

void main() {
  const easy = PronunciationScorer();
  const strict = PronunciationScorer(difficulty: SpeechDifficulty.strict);

  group('pronunciation', () {
    test('a perfect answer gets three stars', () {
      final s = easy.score('I like cats.', 'i like cats');
      expect(s.similarity, closeTo(1, 1e-9));
      expect(s.stars, 3);
      expect(s.passed, isTrue);
    });

    test('case, punctuation and filler words are ignored', () {
      expect(easy.score('Hello!', 'um, hello').stars, 3);
      expect(easy.score('What is your name?', 'What is your name').stars, 3);
    });

    test('contractions and digits count as the same words', () {
      expect(easy.score("I'm happy.", 'I am happy').stars, 3);
      expect(easy.score('I have three dogs.', 'I have 3 dogs').stars, 3);
    });

    test('a close but imperfect try still passes on the easy setting', () {
      final s = easy.score('elephant', 'elefant');
      expect(s.passed, isTrue);
      expect(s.stars, lessThan(4));
    });

    test('an unrelated answer gets no stars', () {
      final s = easy.score('banana', 'computer');
      expect(s.stars, 0);
      expect(s.passed, isFalse);
    });

    test('silence gets no stars', () {
      expect(easy.score('cat', '').stars, 0);
      expect(easy.score('cat', '   ').stars, 0);
    });

    test('half a sentence scores lower than the whole sentence', () {
      final half = easy.score('I like to play football with my friends.', 'I like to play');
      final full = easy.score('I like to play football with my friends.', 'I like to play football with my friends');
      expect(half.similarity, lessThan(full.similarity));
    });

    test('accepted alternatives are used when they match better', () {
      final s = easy.score('Yes, I do.', 'yes', alternatives: const ['Yes.']);
      expect(s.stars, 3);
    });

    test('the target word is found inside a longer utterance', () {
      final s = easy.score('dog', 'it is a dog');
      expect(s.passed, isTrue);
    });

    test('per-word scores line up with the target words', () {
      final s = easy.score('red apple', 'red apple');
      expect(s.wordScores.length, 2);
      expect(s.wordScores.every((w) => w > 0.99), isTrue);
    });

    test('stricter settings never give more stars', () {
      for (final pair in const [
        ['banana', 'banana'],
        ['banana', 'banan'],
        ['I like cats', 'I like cat'],
        ['elephant', 'elefant'],
        ['red', 'bed'],
      ]) {
        expect(strict.score(pair[0], pair[1]).stars, lessThanOrEqualTo(easy.score(pair[0], pair[1]).stars));
      }
    });

    test('star thresholds rise with similarity', () {
      var last = 0;
      for (var i = 0; i <= 100; i++) {
        final stars = easy.starsFor(i / 100);
        expect(stars, greaterThanOrEqualTo(last));
        last = stars;
      }
      expect(easy.starsFor(1), 3);
      expect(easy.starsFor(0), 0);
    });
  });

  group('text normalizer', () {
    test('numbers become words', () {
      expect(TextNormalizer.numberToWords(7), 'seven');
      expect(TextNormalizer.numberToWords(21), 'twenty one');
    });

    test('tokens are lower case without punctuation', () {
      expect(TextNormalizer.tokens('Hello, Bi!'), ['hello', 'bi']);
    });
  });

  group('spelling', () {
    const speller = SpellingScorer();

    test('case, spaces and final punctuation do not matter', () {
      expect(speller.score('Cat', ' cat. ').correct, isTrue);
      expect(speller.score('ice cream', 'ice  cream').correct, isTrue);
    });

    test('a misspelled word is wrong but shows which letters were right', () {
      final r = speller.score('apple', 'aple');
      expect(r.correct, isFalse);
      expect(r.letterOk.first, isTrue);
      expect(r.score, greaterThan(0.5));
    });

    test('the best recognition candidate is chosen', () {
      final r = speller.bestOf('dog', const ['clog', 'dog', 'bog']);
      expect(r.correct, isTrue);
    });

    test('no candidates means a wrong answer', () {
      expect(speller.bestOf('dog', const []).correct, isFalse);
    });
  });
}
