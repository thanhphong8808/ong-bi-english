// test/trace_scorer_test.dart
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ong_bi_english/curriculum/letter_strokes.dart';
import 'package:ong_bi_english/curriculum/scorers/trace_scorer.dart';

void main() {
  const scorer = TraceScorer();

  List<List<P>> copy(LetterTemplate t, {P offset = const P(0, 0), double jitter = 0, int seed = 1}) {
    final random = math.Random(seed);
    return [
      for (final stroke in t.strokes)
        [
          for (final p in TraceScorer.resample(stroke, 0.04))
            P(
              p.x + offset.x + (random.nextDouble() * 2 - 1) * jitter,
              p.y + offset.y + (random.nextDouble() * 2 - 1) * jitter,
            ),
        ],
    ];
  }

  test('every letter of the alphabet has a template in both cases', () {
    for (final code in List.generate(26, (i) => 65 + i)) {
      final upper = String.fromCharCode(code);
      expect(LetterStrokes.of(upper), isNotNull, reason: upper);
      expect(LetterStrokes.of(upper.toLowerCase()), isNotNull, reason: upper.toLowerCase());
    }
  });

  test('tracing exactly over the template passes with three stars', () {
    for (final letter in LetterStrokes.letters) {
      final template = LetterStrokes.of(letter)!;
      final result = scorer.score(template, copy(template));
      expect(result.passed, isTrue, reason: letter);
      expect(result.stars, 3, reason: letter);
    }
  });

  test('a slightly shaky child hand still passes', () {
    for (final letter in const ['A', 'b', 's', 'O', 'k', 'M']) {
      final template = LetterStrokes.of(letter)!;
      final result = scorer.score(template, copy(template, jitter: 0.08, seed: letter.codeUnitAt(0)));
      expect(result.passed, isTrue, reason: letter);
    }
  });

  test('no ink does not pass', () {
    final result = scorer.score(LetterStrokes.of('A')!, const []);
    expect(result.passed, isFalse);
    expect(result.stars, 0);
  });

  test('drawing only one stroke of A is not enough', () {
    final template = LetterStrokes.of('A')!;
    final result = scorer.score(template, [copy(template).first]);
    expect(result.passed, isFalse);
    expect(result.coverage, lessThan(0.75));
  });

  test('ink far away from the letter does not pass', () {
    final template = LetterStrokes.of('L')!;
    final result = scorer.score(template, copy(template, offset: const P(2.5, 0)));
    expect(result.passed, isFalse);
  });

  test('drawing a stroke backwards is caught', () {
    final template = LetterStrokes.of('L')!;
    final reversed = [for (final s in copy(template)) s.reversed.toList()];
    final result = scorer.score(template, reversed);
    expect(result.directionOk, isFalse);
    expect(result.passed, isFalse);
  });

  test('drawing the strokes in the wrong order is caught', () {
    final template = LetterStrokes.of('T')!;
    expect(template.strokes.length, greaterThanOrEqualTo(2));
    final strokes = copy(template).reversed.toList();
    final result = scorer.score(template, strokes);
    expect(result.orderOk, isFalse);
    expect(result.passed, isFalse);
  });

  test('a mostly complete letter counts as nearly there', () {
    final template = LetterStrokes.of('E')!;
    final strokes = copy(template);
    final result = scorer.score(template, strokes.sublist(0, strokes.length - 1));
    expect(result.nearly, isTrue);
  });
}
