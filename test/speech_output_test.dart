// test/speech_output_test.dart (flutter test)
import 'package:flutter_test/flutter_test.dart';
import 'package:ong_bi_english/core/services/speech_output.dart';

List<int> _wavHeader({required int rate, required int channels, required int bits}) {
  List<int> u16(int v) => [v & 0xff, (v >> 8) & 0xff];
  List<int> u32(int v) => [...u16(v & 0xffff), ...u16((v >> 16) & 0xffff)];
  return [
    ...'RIFF'.codeUnits, ...u32(0), ...'WAVE'.codeUnits, ...'fmt '.codeUnits, ...u32(16),
    ...u16(1), ...u16(channels), ...u32(rate), ...u32(rate * channels * bits ~/ 8),
    ...u16(channels * bits ~/ 8), ...u16(bits), ...'data'.codeUnits, ...u32(0),
  ];
}

void main() {
  test('WAV length from the header (fallback when the player gives none)', () {
    final kokoro = _wavHeader(rate: 24000, channels: 1, bits: 16);
    expect(kokoro.length, 44);
    expect(SpeechOutput.wavMillisecondsOf(kokoro, 44 + 48000), 1000);
    final piper = _wavHeader(rate: 22050, channels: 1, bits: 16);
    expect(SpeechOutput.wavMillisecondsOf(piper, 44 + 22050), 500);
    expect(SpeechOutput.wavMillisecondsOf(const [1, 2, 3], 1000), 0);
    expect(SpeechOutput.wavMillisecondsOf(List<int>.filled(44, 0), 1000), 0);
  });
}
