// lib/core/services/audio_cache.dart
import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../db/repositories.dart';
import 'audio_request.dart';
import 'tts_en_service.dart';
import 'tts_vi_service.dart';

/// Synthesises each fixed sentence once and keeps the WAV on disk.
///
/// Kokoro is slow on a phone CPU, so lessons never wait for it: upcoming
/// lessons are pre-rendered in the background through [prewarm].
class AudioCache {
  AudioCache({
    required this.cacheRoot,
    required this.mediaRepo,
    required this.ttsEn,
    required this.ttsVi,
  });

  final String cacheRoot;
  final MediaRepo mediaRepo;
  final TtsEnService ttsEn;
  final TtsViService ttsVi;

  final Map<String, Future<String?>> _inFlight = <String, Future<String?>>{};
  final Queue<AudioRequest> _prewarmQueue = Queue<AudioRequest>();
  bool _prewarming = false;
  int _generation = 0;

  Future<String> _engineTag(AudioRequest request) async {
    if (request.lang == AudioLang.vi) {
      return TtsViService.cacheTag;
    }
    return ttsEn.cacheTag(request.voice);
  }

  String _pathFor(String key) => p.join(cacheRoot, key.substring(0, 2), '$key.wav');

  /// Returns the WAV path, synthesising it on a miss.
  /// Returns null only for Vietnamese when the Piper voice is not installed;
  /// the caller then speaks with the system voice.
  Future<String?> fileFor(AudioRequest request) async {
    final tag = await _engineTag(request);
    final key = audioCacheKey(tag, request.speed, request.text);

    final entry = await mediaRepo.cacheEntry(key);
    if (entry != null) {
      if (await File(entry.filePath).exists()) {
        return entry.filePath;
      }
      await mediaRepo.removeCacheEntry(key);
    }

    final running = _inFlight[key];
    if (running != null) {
      return running;
    }
    final future = _synthesise(request, key, tag);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<String?> _synthesise(AudioRequest request, String key, String tag) async {
    final path = _pathFor(key);
    await Directory(p.dirname(path)).create(recursive: true);
    final temp = '$path.tmp';

    if (request.lang == AudioLang.vi) {
      final ok = await ttsVi.synthToFile(text: request.text, speed: request.speed, outPath: temp);
      if (!ok) {
        return null;
      }
    } else {
      await ttsEn.synthToFile(
        text: request.text,
        voice: request.voice,
        speed: request.speed,
        outPath: temp,
      );
    }

    final file = await File(temp).rename(path);
    await mediaRepo.putCacheEntry(
      key: key,
      filePath: path,
      engine: tag,
      bytes: await file.length(),
    );
    return path;
  }

  /// Queues sentences for background synthesis. Returns immediately.
  void prewarm(Iterable<AudioRequest> requests) {
    _prewarmQueue.addAll(requests);
    if (!_prewarming) {
      _prewarming = true;
      unawaited(_drain(_generation));
    }
  }

  Future<void> _drain(int generation) async {
    try {
      while (_prewarmQueue.isNotEmpty && generation == _generation) {
        final request = _prewarmQueue.removeFirst();
        try {
          await fileFor(request);
        } catch (_) {
          // A failed pre-render is retried on demand when the lesson needs it.
        }
      }
    } finally {
      _prewarming = false;
    }
  }

  int get pendingPrewarm => _prewarmQueue.length;

  Future<int> sizeBytes() => mediaRepo.cacheBytes();

  /// Deletes every cached file (parent action "clear audio cache").
  Future<void> clear() async {
    _generation++;
    _prewarmQueue.clear();
    final dir = Directory(cacheRoot);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await mediaRepo.clearCacheEntries();
  }
}
