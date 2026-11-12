// test/karaoke_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ong_bi_english/curriculum/karaoke.dart';

void main() {
  test('syllables', () {
    expect(syllableCount('cat'), 1);
    expect(syllableCount('apple'), 2);
    expect(syllableCount('cake'), 1);
    expect(syllableCount('banana!'), 3);
    expect(syllableCount('tree'), 1);
    expect(syllableCount('12'), 4);
    expect(syllableCount('?'), 1);
  });

  test('word starts grow and longer words take longer', () {
    final starts = wordStarts(['I', 'like', 'bananas', 'too.']);
    expect(starts.first, 0);
    expect(starts, orderedEquals([...starts]..sort()));
    expect(starts[3] - starts[2], greaterThan(starts[2] - starts[1]));
    expect(wordStarts(const []), isEmpty);
  });

  test('a comma or full stop adds a pause before the next word', () {
    final plain = wordStarts(['Hi', 'Bi', 'how', 'are', 'you']);
    final pause = wordStarts(['Hi,', 'Bi.', 'How', 'are', 'you?']);
    expect(pause[2], greaterThan(plain[2]));
  });

  test('words reached follow the audio', () {
    final starts = wordStarts(['one', 'two', 'three', 'four']);
    expect(wordsReached(starts, 0), 0);
    expect(wordsReached(starts, 0.02), 0);
    expect(wordsReached(starts, 0.06), 1);
    expect(wordsReached(starts, 0.5), inInclusiveRange(2, 3));
    expect(wordsReached(starts, 0.99), 4);
    expect(wordsReached(starts, 1), 4);
  });

  test('the same sentence matches however it is punctuated', () {
    expect(karaokeKey('Hello, Bi!'), karaokeKey('hello bi'));
    expect(karaokeKey("It’s red."), karaokeKey("it's red"));
    expect(karaokeKey('Hello'), isNot(karaokeKey('Hello Bi')));
  });
}
