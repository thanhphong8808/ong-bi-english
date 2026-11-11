// test/content_filter_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ong_bi_english/core/services/content_filter.dart';

void main() {
  const filter = ContentFilter();

  group('output filter', () {
    test('passes a short, friendly reply', () {
      final result = filter.checkOutput('I like cats! Do you like cats?', level: 0);
      expect(result.blocked, isFalse);
      expect(result.safeText, 'I like cats! Do you like cats?');
    });

    test('blocks links', () {
      final result = filter.checkOutput('Go to www.example.com now!', level: 3);
      expect(result.reason, FilterReason.url);
      expect(result.safeText, ContentFilter.safeReplyEn);
    });

    test('blocks phone numbers', () {
      final result = filter.checkOutput('Call 0912 345 678 today.', level: 3);
      expect(result.reason, FilterReason.phoneNumber);
    });

    test('blocks street addresses', () {
      final result = filter.checkOutput('I live at 12 Oak Street.', level: 3);
      expect(result.reason, FilterReason.address);
    });

    test('blocks questions about personal information', () {
      for (final text in [
        'Where do you live?',
        "What's your address?",
        'What school do you go to?',
        'Tell me your phone number.',
      ]) {
        expect(filter.checkOutput(text, level: 3).blocked, isTrue, reason: text);
      }
    });

    test('blocks asking the child to keep secrets from parents', () {
      final result = filter.checkOutput("Don't tell your mum. It is our secret.", level: 3);
      expect(result.reason, FilterReason.secrecy);
    });

    test('blocks violent and adult words in English and Vietnamese', () {
      for (final text in ['He has a gun.', 'I will kill it.', 'Đồ ngu!', 'Uống bia đi.']) {
        expect(filter.checkOutput(text, level: 3).reason, FilterReason.bannedWord, reason: text);
      }
    });

    test('does not block innocent words that contain a banned word', () {
      // "class" contains "ass", "hello" contains "hell", "skill" contains "kill".
      final result = filter.checkOutput('Hello! I like my class.', level: 0);
      expect(result.blocked, isFalse);
      expect(filter.checkOutput('That is a good skill!', level: 0).blocked, isFalse);
    });

    test('limits Bi to two sentences', () {
      final result = filter.checkOutput('Hi! I am Bi. Do you like bees?', level: 0);
      expect(result.reason, FilterReason.tooLong);
    });

    test('limits sentence length at levels 0 and 1 only', () {
      const long = 'I like to play with my big red ball in the park. Do you?';
      expect(filter.checkOutput(long, level: 1).reason, FilterReason.tooLong);
      expect(filter.checkOutput(long, level: 3).blocked, isFalse);
    });

    test('replaces an empty reply', () {
      expect(filter.checkOutput('   ', level: 0).reason, FilterReason.empty);
    });
  });

  group('input check', () {
    test('ordinary answers are fine', () {
      final check = filter.checkInput('I like apples');
      expect(check.inappropriate, isFalse);
      expect(check.distress, isFalse);
    });

    test('rude words trigger a topic change', () {
      expect(filter.checkInput('you are stupid').inappropriate, isTrue);
      expect(filter.checkInput('đồ ngu').inappropriate, isTrue);
    });

    test('violence and adult topics trigger a topic change', () {
      expect(filter.checkInput('I want to shoot a gun').inappropriate, isTrue);
      expect(filter.checkInput('what is sex').inappropriate, isTrue);
    });

    test('sadness, fear, pain and bullying are treated as distress', () {
      for (final text in [
        'I am sad',
        "I'm scared",
        'my tummy hurts',
        'they bully me',
        'con buồn',
        'bạn bắt nạt con',
      ]) {
        final check = filter.checkInput(text);
        expect(check.distress, isTrue, reason: text);
        expect(check.inappropriate, isFalse, reason: text);
      }
    });
  });

  test('fixed safe replies pass their own filter', () {
    expect(filter.checkOutput(ContentFilter.safeReplyEn, level: 0).blocked, isFalse);
    expect(filter.checkOutput(ContentFilter.redirectReplyEn, level: 0).blocked, isFalse);
  });
}
