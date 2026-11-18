// lib/core/services/tts_vi_service.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as p;

import 'native_guard.dart';
import 'speech_configs.dart';
import 'sherpa_worker.dart';

/// Vietnamese speech. By default the phone's own Vietnamese voice (Google
/// TTS, on the device) when one is installed: it sounds more natural and
/// warmer than Piper. Otherwise, or when a parent picks it, Piper vi_VN
/// through sherpa-onnx. [preference] is ParentSettings.viVoice:
/// [autoVoice], [piperVoice] or the name of one system voice.
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

  static const String autoVoice = 'auto';
  static const String piperVoice = 'piper';

  /// Voices tried first in auto mode (Google's on-device Vietnamese voices).
  static const List<String> preferredVoices = [
    'vi-vn-x-gft-local',
    'vi-vn-x-vic-local',
    'vi-vn-x-vif-local',
    'vi-vn-x-vie-local',
    'vi-vn-x-vid-local',
  ];

  /// Slightly brighter than the default, friendlier for a child.
  static const double systemPitch = 1.08;

  String _preference = autoVoice;
  List<String>? _voices;
  String? _currentVoice;

  bool _loaded = false;
  FlutterTts? _system;

  String get preference => _preference;

  set preference(String value) {
    _preference = value.isEmpty ? autoVoice : value;
  }

  /// The phone's Vietnamese voices that work offline (cached).
  Future<List<String>> systemVoices({bool refresh = false}) async {
    if (_voices != null && !refresh) {
      return _voices!;
    }
    final out = <String>[];
    try {
      final tts = _system ??= FlutterTts();
      final raw = await tts.getVoices;
      if (raw is List) {
        for (final v in raw) {
          if (v is! Map) {
            continue;
          }
          final name = '${v['name']}';
          final locale = '${v['locale']}'.toLowerCase();
          final network = '${v['network_required']}';
          final features = '${v['features']}';
          if (locale.startsWith('vi') &&
              network != '1' &&
              network != 'true' &&
              !name.contains('network') &&
              !features.contains('notInstalled')) {
            out.add(name);
          }
        }
      }
    } catch (_) {
      // No TTS engine, or it cannot list voices: Piper only.
    }
    out.sort();
    return _voices = out;
  }

  /// The system voice to use now, or null for Piper.
  static String? chooseVoice(String preference, List<String> voices) {
    if (preference == piperVoice || voices.isEmpty) {
      return null;
    }
    if (preference != autoVoice && voices.contains(preference)) {
      return preference;
    }
    for (final name in preferredVoices) {
      for (final v in voices) {
        if (v.toLowerCase() == name) {
          return v;
        }
      }
    }
    return voices.first;
  }

  /// Whether Vietnamese is spoken with the phone's voice right now.
  Future<bool> get usesSystemVoice async => chooseVoice(_preference, await systemVoices()) != null;
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
      if (await usesSystemVoice || !await piperAvailable) {
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
      final vietnamese = language.toLowerCase().startsWith('vi');
      final voice = vietnamese ? chooseVoice(_preference == piperVoice ? autoVoice : _preference, await systemVoices()) : null;
      if (voice != null) {
        if (_currentVoice != voice) {
          await tts.setLanguage(language);
          await tts.setVoice({'name': voice, 'locale': language});
          _currentVoice = voice;
        }
      } else {
        await tts.setLanguage(language);
        _currentVoice = null;
      }
      await tts.setPitch(vietnamese ? systemPitch : 1.0);
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
