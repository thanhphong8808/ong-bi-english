// lib/core/services/stt_service.dart
import 'dart:async';

import 'package:record/record.dart';

import '../config/app_config.dart';
import 'device_profile.dart';
import 'model_catalog.dart';
import 'native_guard.dart';
import 'sherpa_worker.dart';
import 'speech_configs.dart';

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

  /// Whisper (and saving the recording) after the child stopped speaking,
  /// measured inside the speech worker.
  final int decodeMs;

  /// What the child waits for between the last sound and the stars: the
  /// silence the voice detector needs to know the child has finished, plus
  /// [decodeMs]. The target is under [AppConfig.scoreLatencyTargetMs].
  int get scoreLatencyMs => (AppConfig.vadMinSilenceSeconds * 1000).round() + decodeMs;
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
    await worker.call('stt.init', SttConfigs.init(modelsRoot, whisper, profile.sttThreads));
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
    // VAD and Whisper run inside the worker's audio messages, not only its
    // calls, so the whole listening turn is marked busy for the crash guard.
    worker.guard.begin(NativeGuard.stt);

    final done = Completer<SttResult>();
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
              done.complete(
                SttResult(
                  text: (event['text'] as String?) ?? '',
                  speechMs: (event['speechMs'] as num?)?.toInt() ?? 0,
                  wavPath: event['wavPath'] as String?,
                  timedOut: (event['timedOut'] as bool?) ?? false,
                  decodeMs: (event['workMs'] as num?)?.toInt() ?? 0,
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
      worker.guard.end(NativeGuard.stt);
    }
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
