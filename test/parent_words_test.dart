// test/parent_words_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ong_bi_english/curriculum/models.dart';
import 'package:ong_bi_english/curriculum/parent_words.dart';

void main() {
  test('words and short phrases are cleaned; anything else is refused', () {
    expect(cleanParentWord('  pencil   case '), 'pencil case');
    expect(cleanParentWord("don't"), "don't");
    expect(cleanParentWord('ice-cream'), 'ice-cream');
    expect(cleanParentWord(''), isNull);
    expect(cleanParentWord('bút chì'), isNull, reason: 'Vietnamese letters are not English');
    expect(cleanParentWord('3 cats'), isNull);
    expect(cleanParentWord('a' * 41), isNull);
  });

  test('example sentences are optional and plain English', () {
    expect(cleanParentExample(''), '');
    expect(cleanParentExample('This is my  pencil case.'), 'This is my pencil case.');
    expect(cleanParentExample('Đây là hộp bút.'), isNull);
  });

  test('a picked emoji becomes the item picture', () {
    expect(ItemImage.fromEmoji('🐶').emoji, '🐶');
    expect(ItemImage.fromEmoji('🧑‍🏫').emoji, '🧑‍🏫');
    expect(ItemImage.fromEmoji('').isEmpty, isTrue);
  });
}
