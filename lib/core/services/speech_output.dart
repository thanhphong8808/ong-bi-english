// lib/core/services/speech_output.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_cache.dart';
import 'audio_request.dart';
import 'english_voice.dart';
import 'tts_vi_service.dart';

/// What Bi is saying right now, for the word-by-word highlight.
class SpeechProgress {
  const SpeechProgress(this.text, this.fraction, {this.active = true});

  static const SpeechProgress idle = SpeechProgress('', 0, active: false);

  final String text;

  /// 0..1 of the audio played.
  final double fraction;
  final bool active;
}

/// Speaks English and Vietnamese sentences through the audio cache.
/// Every call waits until playback has finished.
class SpeechOutput {
  SpeechOutput({required this.cache, required this.ttsVi});

  final AudioCache cache;
  final TtsViService ttsVi;

  final AudioPlayer _player = AudioPlayer();
  int _token = 0;

  /// Updated about 20 times a second while an English sentence plays.
  final ValueNotifier<SpeechProgress> progress = ValueNotifier<SpeechProgress>(SpeechProgress.idle);

  /// Bi's Vietnamese instructions.
  Future<void> sayVi(String text, {double speed = 1.0}) async {
    final token = ++_token;
    progress.value = SpeechProgress.idle;
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
    progress.value = SpeechProgress.idle;
    await _stopCurrent();
    String? path;
    try {
      path = await cache.fileFor(AudioRequest.en(text, voice: voice, speed: speed));
    } catch (_) {
      // No built-in English voice (not installed, or switched off after a
      // crash): the phone's own English voice below is better than silence.
      path = null;
    }
    if (token != _token) {
      return; // a newer request replaced this one
    }
    if (path == null) {
      // No timings from the phone's voice: highlight the whole sentence.
      progress.value = SpeechProgress(text, 1);
      await ttsVi.speakWithSystemVoice(text, speed: speed, language: voice.british ? 'en-GB' : 'en-US');
      if (token == _token) {
        progress.value = SpeechProgress.idle;
      }
      return;
    }
    await _play(path, text: text, token: token);
  }

  /// Plays any WAV file, for example the child's own recording.
  Future<void> playFile(String path) async {
    ++_token;
    progress.value = SpeechProgress.idle;
    await _stopCurrent();
    await _play(path);
  }

  Future<void> _play(String path, {String? text, int? token}) async {
    final duration = await _player.setFilePath(path);
    var ms = duration?.inMilliseconds ?? 0;
    if (ms <= 0 && text != null) {
      ms = await wavMilliseconds(path);
    }
    StreamSubscription<Duration>? sub;
    var updates = 0;
    var last = 0.0;
    if (text != null && ms > 0) {
      progress.value = SpeechProgress(text, 0);
      sub = _player
          .createPositionStream(
            steps: 1000,
            minPeriod: const Duration(milliseconds: 40),
            maxPeriod: const Duration(milliseconds: 80),
          )
          .listen((position) {
        if (token == _token) {
          last = (position.inMilliseconds / ms).clamp(0.0, 1.0).toDouble();
          updates++;
          progress.value = SpeechProgress(text, last);
        }
      });
    }
    try {
      // play() returns when the sentence ends or is stopped. A watchdog
      // makes sure a stuck player can never freeze a lesson or a talk.
      final limit = ms > 0 ? Duration(milliseconds: ms * 2 + 5000) : const Duration(seconds: 60);
      await _player.play().timeout(limit, onTimeout: () async {
        debugPrint('speech: playback watchdog after ${limit.inMilliseconds} ms');
        await _player.stop();
      });
    } finally {
      await sub?.cancel();
      if (text != null && token == _token) {
        progress.value = SpeechProgress.idle;
        // Counts only (no lesson text): the CI smoke test checks the
        // word highlight really follows the audio on a device.
        debugPrint('speech progress: ms=$ms updates=$updates last=${last.toStringAsFixed(2)}');
      }
    }
  }

  /// Length of a PCM WAV file from its header, or 0.
  static Future<int> wavMilliseconds(String path) async {
    try {
      final file = File(path);
      final raf = await file.open();
      final header = await raf.read(44);
      final length = await raf.length();
      await raf.close();
      return wavMillisecondsOf(header, length);
    } catch (_) {
      return 0;
    }
  }

  static int wavMillisecondsOf(List<int> header, int fileLength) {
    if (header.length < 44 || String.fromCharCodes(header.sublist(0, 4)) != 'RIFF') {
      return 0;
    }
    int u16(int o) => header[o] | (header[o + 1] << 8);
    int u32(int o) => u16(o) | (u16(o + 2) << 16);
    final channels = u16(22);
    final rate = u32(24);
    final bits = u16(34);
    final bytesPerSecond = rate * channels * bits ~/ 8;
    if (bytesPerSecond <= 0) {
      return 0;
    }
    return ((fileLength - 44) * 1000 / bytesPerSecond).round();
  }

  Future<void> _stopCurrent() async {
    await ttsVi.stopSystemVoice();
    if (_player.playing) {
      await _player.stop();
    }
  }

  Future<void> stop() async {
    ++_token;
    progress.value = SpeechProgress.idle;
    await _stopCurrent();
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
