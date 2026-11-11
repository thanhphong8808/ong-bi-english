// lib/core/services/speech_output.dart
import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'audio_cache.dart';
import 'audio_request.dart';
import 'english_voice.dart';
import 'tts_vi_service.dart';

/// Speaks English and Vietnamese sentences through the audio cache.
/// Every call waits until playback has finished.
class SpeechOutput {
  SpeechOutput({required this.cache, required this.ttsVi});

  final AudioCache cache;
  final TtsViService ttsVi;

  final AudioPlayer _player = AudioPlayer();
  int _token = 0;

  /// Bi's Vietnamese instructions.
  Future<void> sayVi(String text, {double speed = 1.0}) async {
    final token = ++_token;
    await _stopCurrent();
    final String? path;
    try {
      path = await cache.fileFor(AudioRequest.vi(text, speed: speed));
    } catch (_) {
      if (token == _token) {
        await ttsVi.speakWithSystemVoice(text, speed: speed);
      }
      return;
    }
    if (token != _token) {
      return; // a newer request replaced this one
    }
    if (path == null) {
      await ttsVi.speakWithSystemVoice(text, speed: speed);
      return;
    }
    await _play(path);
  }

  Future<void> sayEn(
    String text, {
    EnglishVoice voice = EnglishVoice.usFemale,
    double speed = 1.0,
  }) async {
    final token = ++_token;
    await _stopCurrent();
    final path = await cache.fileFor(AudioRequest.en(text, voice: voice, speed: speed));
    if (token != _token || path == null) {
      return;
    }
    await _play(path);
  }

  /// Plays any WAV file, for example the child's own recording.
  Future<void> playFile(String path) async {
    ++_token;
    await _stopCurrent();
    await _play(path);
  }

  Future<void> _play(String path) async {
    await _player.setFilePath(path);
    await _player.play();
  }

  Future<void> _stopCurrent() async {
    await ttsVi.stopSystemVoice();
    if (_player.playing) {
      await _player.stop();
    }
  }

  Future<void> stop() async {
    ++_token;
    await _stopCurrent();
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
