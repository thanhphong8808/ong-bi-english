// lib/core/services/stt_service.dart
import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:record/record.dart';

import '../config/app_config.dart';
import 'device_profile.dart';
import 'model_catalog.dart';
import 'sherpa_worker.dart';

class SttResult {
  const SttResult({
    required this.text,
    required this.speechMs,
    required this.wavPath,
    required this.timedOut,
    required this.decodeMs,
  });

  /// What Whisper heard; empty when the child stayed silent.
  final String text;
  final int speechMs;

  /// The child's recording, when a save path was requested.
  final String? wavPath;
  final bool timedOut;

  /// Time from "child stopped speaking" to "transcript ready".
  final int decodeMs;
}

class SttException implements Exception {
  const SttException(this.code);

  /// mic_permission | not_ready | busy | failed
  final String code;

  @override
  String toString() => 'SttException($code)';
}

/// Microphone -> Silero VAD -> Whisper, fully on-device.
class SttService {
  SttService({required this.worker, required this.modelsRoot});

  final SherpaWorker worker;
  final String modelsRoot;

  final AudioRecorder _recorder = AudioRecorder();
  bool _ready = false;
  bool _listening = false;

  bool get isReady => _ready;
  bool get isListening => _listening;

  /// Loads Whisper and the VAD into the worker isolate.
  Future<void> ensureReady(DeviceProfile profile) async {
    if (_ready) {
      return;
    }
    final whisper = ModelCatalog.whisperFor(profile);
    final dir = p.join(modelsRoot, whisper.id);
    await worker.call('stt.init', {
      'encoder': p.join(dir, whisper.requiredFiles[0]),
      'decoder': p.join(dir, whisper.requiredFiles[1]),
      'tokens': p.join(dir, whisper.requiredFiles[2]),
      'threads': profile.sttThreads,
      'vadModel': p.join(modelsRoot, ModelCatalog.vad.id, ModelCatalog.vad.fileName),
      'vadThreshold': AppConfig.vadThreshold,
      'vadMinSilence': AppConfig.vadMinSilenceSeconds,
      'vadMinSpeech': AppConfig.vadMinSpeechSeconds,
      'vadMaxSpeech': AppConfig.vadMaxSpeechSeconds,
      'vadWindow': AppConfig.vadWindowSize,
      'sampleRate': AppConfig.sttSampleRate,
    });
    _ready = true;
  }

  Future<bool> hasMicPermission() => _recorder.hasPermission();

  /// Listens until the child stops speaking (VAD) or [timeout] passes.
  Future<SttResult> listenOnce({
    Duration timeout = const Duration(seconds: AppConfig.listenTimeoutSeconds),
    String? saveWavPath,
    void Function(double level)? onLevel,
    void Function()? onSpeechStart,
  }) async {
    if (!_ready) {
      throw const SttException('not_ready');
    }
    if (_listening) {
      throw const SttException('busy');
    }
    if (!await _recorder.hasPermission()) {
      throw const SttException('mic_permission');
    }
    _listening = true;

    final done = Completer<SttResult>();
    DateTime? lastAudioAt;
    StreamSubscription<Map<String, Object?>>? eventSub;
    StreamSubscription<List<int>>? audioSub;
    Timer? timer;

    try {
      await worker.call('stt.begin', {'savePath': saveWavPath});

      eventSub = worker.events.listen((event) {
        switch (event['type']) {
          case 'level':
            onLevel?.call((event['rms'] as num).toDouble());
          case 'speechStart':
            onSpeechStart?.call();
          case 'final':
            if (!done.isCompleted) {
              final stoppedAt = lastAudioAt ?? DateTime.now();
              done.complete(
                SttResult(
                  text: (event['text'] as String?) ?? '',
                  speechMs: (event['speechMs'] as num?)?.toInt() ?? 0,
                  wavPath: event['wavPath'] as String?,
                  timedOut: (event['timedOut'] as bool?) ?? false,
                  decodeMs: DateTime.now().difference(stoppedAt).inMilliseconds,
                ),
              );
            }
          case 'error':
            if (!done.isCompleted) {
              done.completeError(const SttException('failed'));
            }
        }
      });

      final audio = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: AppConfig.sttSampleRate,
          numChannels: 1,
          autoGain: true,
          noiseSuppress: true,
        ),
      );
      audioSub = audio.listen((chunk) {
        if (done.isCompleted) {
          return;
        }
        lastAudioAt = DateTime.now();
        worker.post('stt.chunk', {'pcm': chunk});
      });

      timer = Timer(timeout, () => worker.post('stt.end'));

      return await done.future.timeout(
        timeout + const Duration(seconds: 15),
        onTimeout: () => throw const SttException('failed'),
      );
    } finally {
      timer?.cancel();
      await audioSub?.cancel();
      try {
        await _recorder.stop();
      } catch (_) {
        // Recorder was never started (permission or begin failure).
      }
      await eventSub?.cancel();
      _listening = false;
    }
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
