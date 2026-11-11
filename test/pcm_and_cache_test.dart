// test/pcm_and_cache_test.dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ong_bi_english/core/config/app_config.dart';
import 'package:ong_bi_english/core/services/audio_request.dart';
import 'package:ong_bi_english/core/services/pcm_utils.dart';

void main() {
  test('PCM16 little-endian converts to floats', () {
    // 0, 16384 (0.5), -32768 (-1.0)
    final bytes = Uint8List.fromList([0x00, 0x00, 0x00, 0x40, 0x00, 0x80]);
    final floats = PcmUtils.pcm16ToFloat32(bytes);
    expect(floats.length, 3);
    expect(floats[0], 0);
    expect(floats[1], closeTo(0.5, 1e-6));
    expect(floats[2], closeTo(-1.0, 1e-6));
  });

  test('a trailing odd byte is ignored', () {
    final floats = PcmUtils.pcm16ToFloat32(Uint8List.fromList([0x00, 0x40, 0x7f]));
    expect(floats.length, 1);
  });

  test('rms of silence is zero and of a constant is its magnitude', () {
    expect(PcmUtils.rms(Float32List(0)), 0);
    expect(PcmUtils.rms(Float32List.fromList([0.5, -0.5, 0.5, -0.5])), closeTo(0.5, 1e-6));
  });

  test('concat keeps order', () {
    final joined = PcmUtils.concat([
      Float32List.fromList([1, 2]),
      Float32List(0),
      Float32List.fromList([3]),
    ]);
    expect(joined, [1, 2, 3]);
  });

  test('audio cache key is stable and separates voice, speed and text', () {
    final a = audioCacheKey('kokoro-v1_0:af_heart', 1.0, 'This is my mum.');
    expect(audioCacheKey('kokoro-v1_0:af_heart', 1.0, '  This is  my mum. '), a);
    expect(audioCacheKey('kokoro-v1_0:am_michael', 1.0, 'This is my mum.'), isNot(a));
    expect(audioCacheKey('kokoro-v1_0:af_heart', 0.7, 'This is my mum.'), isNot(a));
    expect(audioCacheKey('kokoro-v1_0:af_heart', 1.0, 'This is my dad.'), isNot(a));
    expect(a.length, 40);
  });

  test('configuration matches the specification', () {
    expect(AppConfig.leitnerIntervalsDays, [0, 1, 2, 4, 7, 14, 30]);
    expect(AppConfig.unitTestPassRatio, 0.80);
    expect(AppConfig.levelTestPassRatio, 0.75);
    expect(AppConfig.levelTestSectionFloor, 0.60);
    expect(AppConfig.traceCoverageMin, 0.75);
    expect(AppConfig.biMaxSentencesPerTurn, 2);
    expect(AppConfig.biMaxWordsPerSentenceLow, 8);
    expect(AppConfig.giantButtonMinSize, greaterThanOrEqualTo(120));
    expect(AppConfig.slowSpeechRate, 0.7);
  });
}
