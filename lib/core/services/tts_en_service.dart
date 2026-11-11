// lib/core/services/tts_en_service.dart
import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'english_voice.dart';
import 'model_catalog.dart';
import 'native_guard.dart';
import 'sherpa_worker.dart';

class TtsUnavailableException implements Exception {
  const TtsUnavailableException(this.engine);
  final String engine;

  @override
  String toString() => 'TtsUnavailableException($engine)';
}

/// English speech synthesis: Kokoro-82M, with Piper en_US as a fallback.
class TtsEnService {
  TtsEnService({
    required this.worker,
    required this.modelsRoot,
    required this.threads,
  });

  final SherpaWorker worker;

  NativeGuard get _guard => worker.guard;
  final String modelsRoot;
  final int threads;

  static const String _engineId = 'en';

  String? _loadedMode;
  Future<void> _queue = Future<void>.value();

  String get _kokoroDir =>
      p.join(modelsRoot, ModelCatalog.kokoro.id, 'kokoro-multi-lang-v1_0');

  String get _piperDir =>
      p.join(modelsRoot, ModelCatalog.piperEn.id, 'vits-piper-en_US-amy-low');

  // A voice engine switched off by the crash guard counts as not installed:
  // the phone's own English voice is used instead.
  Future<bool> _kokoroInstalled() async =>
      !_guard.isDisabled(NativeGuard.tts) && await File(p.join(_kokoroDir, 'model.onnx')).exists();

  Future<bool> _piperInstalled() async =>
      !_guard.isDisabled(NativeGuard.tts) &&
      await File(p.join(_piperDir, 'en_US-amy-low.onnx')).exists();

  Future<bool> get available async => await _kokoroInstalled() || await _piperInstalled();

  /// Identifies engine + accent + voice for cache keys.
  Future<String> cacheTag(EnglishVoice voice) async {
    if (await _kokoroInstalled()) {
      return 'kokoro-v1_0:${voice.kokoroName}';
    }
    return 'piper-en_US-amy-low';
  }

  /// Runs [task] after every previously queued task has finished.
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

  Future<int> _ensureLoaded(EnglishVoice voice) async {
    if (await _kokoroInstalled()) {
      // The lexicon decides the accent, so switching between American and
      // British voices reloads the engine. Parents pick one accent, so this
      // happens rarely.
      final mode = voice.british ? 'kokoro-gb' : 'kokoro-us';
      if (_loadedMode != mode) {
        final lexicon = voice.british ? 'lexicon-gb-en.txt' : 'lexicon-us-en.txt';
        await worker.call('tts.init', {
          'engine': _engineId,
          'kind': 'kokoro',
          'model': p.join(_kokoroDir, 'model.onnx'),
          'voices': p.join(_kokoroDir, 'voices.bin'),
          'tokens': p.join(_kokoroDir, 'tokens.txt'),
          'dataDir': p.join(_kokoroDir, 'espeak-ng-data'),
          'dictDir': p.join(_kokoroDir, 'dict'),
          'lexicon': '${p.join(_kokoroDir, lexicon)},${p.join(_kokoroDir, 'lexicon-zh.txt')}',
          'lang': voice.british ? 'en-gb' : 'en-us',
          'threads': threads,
        });
        _loadedMode = mode;
      }
      return voice.kokoroSid;
    }
    if (await _piperInstalled()) {
      if (_loadedMode != 'piper') {
        await worker.call('tts.init', {
          'engine': _engineId,
          'kind': 'vits',
          'model': p.join(_piperDir, 'en_US-amy-low.onnx'),
          'tokens': p.join(_piperDir, 'tokens.txt'),
          'dataDir': p.join(_piperDir, 'espeak-ng-data'),
          'threads': threads,
        });
        _loadedMode = 'piper';
      }
      return 0;
    }
    throw const TtsUnavailableException('en');
  }

  /// Synthesises [text] into a WAV file and returns the elapsed milliseconds.
  Future<int> synthToFile({
    required String text,
    required EnglishVoice voice,
    required double speed,
    required String outPath,
  }) {
    return _serial(() async {
      final sid = await _ensureLoaded(voice);
      final result = await worker.call('tts.synth', {
        'engine': _engineId,
        'text': text,
        'sid': sid,
        'speed': speed,
        'outPath': outPath,
      });
      final map = Map<String, Object?>.from(result! as Map);
      return (map['elapsedMs'] as num).toInt();
    });
  }

  /// Frees the engine (about 350 MB of RAM for Kokoro).
  Future<void> release() {
    return _serial(() async {
      if (_loadedMode != null) {
        await worker.call('tts.release', {'engine': _engineId});
        _loadedMode = null;
      }
    });
  }
}
