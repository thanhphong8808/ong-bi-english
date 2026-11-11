// test/parent_gate_test.dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ong_bi_english/core/config/app_config.dart';
import 'package:ong_bi_english/core/services/parent_gate.dart';
import 'package:ong_bi_english/core/services/parent_settings.dart';

void main() {
  test('multiplication factors stay in the hard range', () {
    final random = Random(42);
    for (var i = 0; i < 200; i++) {
      final challenge = GateChallenge.random(random);
      expect(challenge.a, inInclusiveRange(AppConfig.gateFactorMin, AppConfig.gateFactorMax));
      expect(challenge.b, inInclusiveRange(AppConfig.gateFactorMin, AppConfig.gateFactorMax));
    }
  });

  test('only the right product opens the gate', () {
    const challenge = GateChallenge(7, 8);
    expect(challenge.check('56'), isTrue);
    expect(challenge.check(' 56 '), isTrue);
    expect(challenge.check('15'), isFalse);
    expect(challenge.check(''), isFalse);
    expect(challenge.check('abc'), isFalse);
  });

  test('PIN must be exactly four digits', () {
    expect(PinCheck.isValidFormat('1234'), isTrue);
    expect(PinCheck.isValidFormat('123'), isFalse);
    expect(PinCheck.isValidFormat('12345'), isFalse);
    expect(PinCheck.isValidFormat('12a4'), isFalse);
  });

  test('PIN is stored hashed and verified against the hash', () {
    final settings = const ParentSettings().copyWith(pinHash: ParentSettings.hashPin('2468'));
    expect(settings.pinHash, isNot(contains('2468')));
    expect(PinCheck.matches('2468', settings), isTrue);
    expect(PinCheck.matches('1357', settings), isFalse);
    expect(PinCheck.matches('2468', const ParentSettings()), isFalse);
  });

  test('settings survive a save and load round trip', () {
    final original = const ParentSettings().copyWith(
      dailyLimitMinutes: 30,
      slowSpeech: true,
      speechDifficulty: SpeechDifficulty.strict,
      talkWithBiEnabled: false,
      recordingRetentionDays: 3,
      setupDone: true,
    );
    final restored = ParentSettings.fromMap(original.toMap());
    expect(restored.dailyLimitMinutes, 30);
    expect(restored.slowSpeech, isTrue);
    expect(restored.speechDifficulty, SpeechDifficulty.strict);
    expect(restored.talkWithBiEnabled, isFalse);
    expect(restored.recordingRetentionDays, 3);
    expect(restored.setupDone, isTrue);
    expect(restored.speechRate, AppConfig.slowSpeechRate);
  });

  test('defaults follow the specification', () {
    const settings = ParentSettings();
    expect(settings.dailyLimitMinutes, 20);
    expect(settings.sessionMinutes, 12);
    expect(settings.recordingRetentionDays, 7);
    expect(settings.speechDifficulty, SpeechDifficulty.easy);
    expect(settings.delayEnglishReading, isTrue);
    expect(ParentSettings.fromMap(const {}).dailyLimitMinutes, 20);
  });
}
