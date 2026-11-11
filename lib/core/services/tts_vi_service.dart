// lib/core/services/tts_vi_service.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as p;

import 'native_guard.dart';
import 'speech_configs.dart';
import 'sherpa_worker.dart';

/// Vietnamese speech: Piper vi_VN through sherpa-onnx, with the Android
/// system TTS engine as a fallback when the Piper pack is not installed.
class TtsViService {
  TtsViService({
    required this.worker,
    required this.modelsRoot,
    required this.threads,
  });

  final SherpaWorker worker;
  final String modelsRoot;
  final int threads;

  static const String _engineId = 'vi';
  static const String cacheTag = 'piper-vi_VN-vais1000-medium';

  bool _loaded = false;
  FlutterTts? _system;
  Future<void> _queue = Future<void>.value();

  String get _dir => TtsConfigs.piperViDir(modelsRoot);

  Future<bool> get piperAvailable async =>
      !worker.guard.isDisabled(NativeGuard.tts) &&
      await File(p.join(_dir, 'vi_VN-vais1000-medium.onnx')).exists();

  Future<T> _serial<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await task());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  /// Synthesises into [outPath]. Returns false when Piper is unavailable and
  /// the caller should use [speakWithSystemVoice] instead.
  Future<bool> synthToFile({
    required String text,
    required double speed,
    required String outPath,
  }) {
    return _serial(() async {
      if (!await piperAvailable) {
        return false;
      }
      if (!_loaded) {
        await worker.call('tts.init', {
          'engine': _engineId,
          ...TtsConfigs.piperVi(modelsRoot, threads),
        });
        _loaded = true;
      }
      await worker.call('tts.synth', {
        'engine': _engineId,
        'text': text,
        'sid': 0,
        'speed': speed,
        'outPath': outPath,
      });
      return true;
    });
  }

  /// Speaks with the Android system voice and waits until it finishes.
  /// Returns false when no system voice for [language] is installed.
  Future<bool> speakWithSystemVoice(String text, {double speed = 1.0, String language = 'vi-VN'}) async {
    try {
      final tts = _system ??= FlutterTts();
      await tts.awaitSpeakCompletion(true);
      await tts.setLanguage(language);
      // flutter_tts uses 0.5 as the normal Android speaking rate.
      await tts.setSpeechRate(0.5 * speed);
      await tts.speak(text);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stopSystemVoice() async {
    try {
      await _system?.stop();
    } catch (_) {
      // Nothing was playing.
    }
  }
}
