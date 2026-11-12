// lib/core/services/sherpa_worker.dart
//
// sherpa-onnx calls are synchronous FFI and can take seconds (Kokoro on a
// phone CPU), so they run in a long-lived background isolate. The app starts
// two workers: one for speech recognition and one for speech synthesis, so a
// background audio pre-render never delays scoring the child's answer.
import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'native_guard.dart';
import 'pcm_utils.dart';

class SherpaWorkerException implements Exception {
  const SherpaWorkerException(this.message);
  final String message;

  @override
  String toString() => 'SherpaWorkerException($message)';
}

/// Main-isolate handle to one worker isolate.
class SherpaWorker {
  SherpaWorker(this.debugName, {NativeGuard? guard, this.guardEngine = ''})
      : guard = guard ?? NativeGuard.disabled();

  final String debugName;

  /// Marks this engine busy during each native call (see [NativeGuard]).
  final NativeGuard guard;
  final String guardEngine;

  Isolate? _isolate;
  SendPort? _toWorker;
  ReceivePort? _fromWorker;
  Future<void>? _starting;
  int _nextId = 1;
  final Map<int, Completer<Object?>> _pending = <int, Completer<Object?>>{};
  final StreamController<Map<String, Object?>> _events =
      StreamController<Map<String, Object?>>.broadcast();

  /// Unsolicited events (speech level, speech start, final transcript).
  Stream<Map<String, Object?>> get events => _events.stream;

  Future<void> start() {
    return _starting ??= _start();
  }

  Future<void> _start() async {
    final port = ReceivePort();
    _fromWorker = port;
    final ready = Completer<void>();
    port.listen((message) {
      if (message is SendPort) {
        _toWorker = message;
        if (!ready.isCompleted) {
          ready.complete();
        }
        return;
      }
      if (message is! Map) {
        return;
      }
      final map = Map<String, Object?>.from(message);
      final id = map['id'] as int?;
      if (id == null) {
        _events.add(map);
        return;
      }
      final completer = _pending.remove(id);
      if (completer == null) {
        return;
      }
      final error = map['error'] as String?;
      if (error != null) {
        completer.completeError(SherpaWorkerException(error));
      } else {
        completer.complete(map['result']);
      }
    });
    _isolate = await Isolate.spawn<SendPort>(
      _sherpaWorkerMain,
      port.sendPort,
      debugName: debugName,
      errorsAreFatal: false,
    );
    await ready.future;
  }

  /// Sends a command and waits for its reply.
  Future<Object?> call(String op, [Map<String, Object?> args = const {}]) async {
    await start();
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    if (guardEngine.isNotEmpty) {
      guard.begin(guardEngine);
    }
    _toWorker!.send(<String, Object?>{'id': id, 'op': op, ...args});
    try {
      return await completer.future;
    } finally {
      if (guardEngine.isNotEmpty) {
        guard.end(guardEngine);
      }
    }
  }

  /// Sends a command without waiting (used for audio chunks).
  void post(String op, [Map<String, Object?> args = const {}]) {
    final port = _toWorker;
    if (port == null) {
      return;
    }
    port.send(<String, Object?>{'op': op, ...args});
  }

  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _fromWorker?.close();
    _toWorker = null;
    _starting = null;
    for (final completer in _pending.values) {
      completer.completeError(const SherpaWorkerException('worker disposed'));
    }
    _pending.clear();
  }
}

// ---------------------------------------------------------------------------
// Worker isolate
// ---------------------------------------------------------------------------

void _sherpaWorkerMain(SendPort toMain) {
  sherpa.initBindings();
  final state = _WorkerState(toMain);
  final port = ReceivePort();
  toMain.send(port.sendPort);
  port.listen((message) {
    if (message is! Map) {
      return;
    }
    final map = Map<String, Object?>.from(message);
    final id = map['id'] as int?;
    try {
      final result = state.handle(map);
      if (id != null) {
        toMain.send(<String, Object?>{'id': id, 'result': result});
      }
    } catch (e) {
      if (id != null) {
        toMain.send(<String, Object?>{'id': id, 'error': e.toString()});
      } else {
        toMain.send(<String, Object?>{'type': 'error', 'message': e.toString()});
      }
    }
  });
}

class _WorkerState {
  _WorkerState(this.toMain);

  final SendPort toMain;

  // Speech recognition
  sherpa.OfflineRecognizer? recognizer;
  sherpa.VoiceActivityDetector? vad;
  int vadWindow = 512;
  bool listening = false;
  bool speechStarted = false;
  String? savePath;
  Float32List carry = Float32List(0);
  final List<Float32List> segments = <Float32List>[];

  // Speech synthesis, keyed by engine id ("en", "vi")
  final Map<String, sherpa.OfflineTts> ttsEngines = <String, sherpa.OfflineTts>{};

  Object? handle(Map<String, Object?> m) {
    switch (m['op'] as String?) {
      case 'stt.init':
        return sttInit(m);
      case 'stt.begin':
        return sttBegin(m);
      case 'stt.chunk':
        sttChunk(m['pcm'] as Uint8List);
        return null;
      case 'stt.end':
        sttFinish(timedOut: true);
        return null;
      case 'stt.transcribeSamples':
        return transcribe(m['samples'] as Float32List);
      case 'tts.init':
        return ttsInit(m);
      case 'tts.release':
        ttsEngines.remove(m['engine'] as String)?.free();
        return true;
      case 'tts.synth':
        return ttsSynth(m);
      case 'ping':
        return true;
      default:
        throw ArgumentError('unknown op ${m['op']}');
    }
  }

  bool sttInit(Map<String, Object?> m) {
    recognizer?.free();
    vad?.free();
    final threads = m['threads'] as int;
    recognizer = sherpa.OfflineRecognizer(
      sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          whisper: sherpa.OfflineWhisperModelConfig(
            encoder: m['encoder'] as String,
            decoder: m['decoder'] as String,
            language: 'en',
            task: 'transcribe',
          ),
          tokens: m['tokens'] as String,
          modelType: 'whisper',
          numThreads: threads,
          debug: false,
          provider: 'cpu',
        ),
      ),
    );
    vadWindow = m['vadWindow'] as int;
    vad = sherpa.VoiceActivityDetector(
      config: sherpa.VadModelConfig(
        sileroVad: sherpa.SileroVadModelConfig(
          model: m['vadModel'] as String,
          threshold: m['vadThreshold'] as double,
          minSilenceDuration: m['vadMinSilence'] as double,
          minSpeechDuration: m['vadMinSpeech'] as double,
          maxSpeechDuration: m['vadMaxSpeech'] as double,
          windowSize: vadWindow,
        ),
        sampleRate: m['sampleRate'] as int,
        numThreads: 1,
        debug: false,
      ),
      bufferSizeInSeconds: 30,
    );
    return true;
  }

  bool sttBegin(Map<String, Object?> m) {
    final detector = vad;
    if (detector == null || recognizer == null) {
      throw StateError('speech recognition is not initialised');
    }
    detector.clear();
    detector.reset();
    segments.clear();
    carry = Float32List(0);
    speechStarted = false;
    savePath = m['savePath'] as String?;
    listening = true;
    return true;
  }

  void sttChunk(Uint8List pcm) {
    final detector = vad;
    if (!listening || detector == null) {
      return;
    }
    final fresh = PcmUtils.pcm16ToFloat32(pcm);
    toMain.send(<String, Object?>{'type': 'level', 'rms': PcmUtils.rms(fresh)});

    final buffer = carry.isEmpty ? fresh : PcmUtils.concat([carry, fresh]);
    var offset = 0;
    while (offset + vadWindow <= buffer.length) {
      detector.acceptWaveform(Float32List.sublistView(buffer, offset, offset + vadWindow));
      offset += vadWindow;
      if (!speechStarted && detector.isDetected()) {
        speechStarted = true;
        toMain.send(<String, Object?>{'type': 'speechStart'});
      }
    }
    carry = Float32List.fromList(Float32List.sublistView(buffer, offset));

    // A segment appears once the trailing silence is long enough:
    // the child has finished speaking.
    if (!detector.isEmpty()) {
      sttFinish(timedOut: false);
    }
  }

  void sttFinish({required bool timedOut}) {
    final detector = vad;
    if (!listening || detector == null) {
      return;
    }
    listening = false;
    if (timedOut) {
      detector.flush();
    }
    while (!detector.isEmpty()) {
      segments.add(detector.front().samples);
      detector.pop();
    }
    final speech = PcmUtils.concat(segments);
    segments.clear();

    final work = Stopwatch()..start();
    var text = '';
    String? wav;
    if (speech.isNotEmpty) {
      text = transcribe(speech);
      final path = savePath;
      if (path != null) {
        final ok = sherpa.writeWave(filename: path, samples: speech, sampleRate: 16000);
        wav = ok ? path : null;
      }
    }
    toMain.send(<String, Object?>{
      'type': 'final',
      'text': text,
      'speechMs': (speech.length / 16).round(),
      'wavPath': wav,
      'timedOut': timedOut,
      'workMs': work.elapsedMilliseconds,
    });
  }

  String transcribe(Float32List samples) {
    final engine = recognizer;
    if (engine == null) {
      throw StateError('speech recognition is not initialised');
    }
    final stream = engine.createStream();
    try {
      stream.acceptWaveform(samples: samples, sampleRate: 16000);
      engine.decode(stream);
      return engine.getResult(stream).text.trim();
    } finally {
      stream.free();
    }
  }

  bool ttsInit(Map<String, Object?> m) {
    final engineId = m['engine'] as String;
    ttsEngines.remove(engineId)?.free();
    final kind = m['kind'] as String;
    final threads = m['threads'] as int;
    final sherpa.OfflineTtsModelConfig model;
    if (kind == 'kokoro') {
      model = sherpa.OfflineTtsModelConfig(
        kokoro: sherpa.OfflineTtsKokoroModelConfig(
          model: m['model'] as String,
          voices: m['voices'] as String,
          tokens: m['tokens'] as String,
          dataDir: m['dataDir'] as String,
          dictDir: (m['dictDir'] as String?) ?? '',
          lexicon: (m['lexicon'] as String?) ?? '',
          lang: (m['lang'] as String?) ?? '',
        ),
        numThreads: threads,
        debug: false,
        provider: 'cpu',
      );
    } else {
      model = sherpa.OfflineTtsModelConfig(
        vits: sherpa.OfflineTtsVitsModelConfig(
          model: m['model'] as String,
          tokens: m['tokens'] as String,
          dataDir: m['dataDir'] as String,
        ),
        numThreads: threads,
        debug: false,
        provider: 'cpu',
      );
    }
    ttsEngines[engineId] = sherpa.OfflineTts(sherpa.OfflineTtsConfig(model: model));
    return true;
  }

  Map<String, Object?> ttsSynth(Map<String, Object?> m) {
    final engine = ttsEngines[m['engine'] as String];
    if (engine == null) {
      throw StateError('voice ${m['engine']} is not initialised');
    }
    final watch = Stopwatch()..start();
    final audio = engine.generate(
      text: m['text'] as String,
      sid: m['sid'] as int,
      speed: m['speed'] as double,
    );
    if (audio.samples.isEmpty || audio.sampleRate <= 0) {
      throw StateError('synthesis returned no audio');
    }
    final path = m['outPath'] as String;
    final ok = sherpa.writeWave(
      filename: path,
      samples: audio.samples,
      sampleRate: audio.sampleRate,
    );
    if (!ok) {
      throw StateError('could not write $path');
    }
    return <String, Object?>{
      'path': path,
      'sampleRate': audio.sampleRate,
      'samples': audio.samples.length,
      'elapsedMs': watch.elapsedMilliseconds,
    };
  }
}
