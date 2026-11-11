// lib/core/services/speech_configs.dart
import 'package:path/path.dart' as p;

import '../config/app_config.dart';
import 'english_voice.dart';
import 'model_catalog.dart';

/// The exact sherpa-onnx settings of every built-in voice.
///
/// (Speech recognition settings: [SttConfigs] below.)
///
/// Pure Dart on purpose: tool/dump_tts_configs.dart hands the same settings
/// to the CI voice check (tool/ci/tts_check.py), which synthesises every
/// voice with sherpa-onnx before a build is published. sherpa-onnx turns a
/// bad setting into a C++ exception, and inside the app that aborts the
/// whole process, so these settings must never drift from what is tested.
abstract final class TtsConfigs {
  static const String kokoroFolder = 'kokoro-multi-lang-v1_0';
  static const String piperViFolder = 'vits-piper-vi_VN-vais1000-medium';
  static const String piperEnFolder = 'vits-piper-en_US-amy-low';

  static String kokoroDir(String modelsRoot) => p.join(modelsRoot, ModelCatalog.kokoro.id, kokoroFolder);

  static String piperViDir(String modelsRoot) => p.join(modelsRoot, ModelCatalog.piperVi.id, piperViFolder);

  static String piperEnDir(String modelsRoot) => p.join(modelsRoot, ModelCatalog.piperEn.id, piperEnFolder);

  /// Kokoro v1.0 for one accent. The lexicon decides the accent.
  ///
  /// `lang` must stay empty. A non-empty `lang` makes sherpa-onnx skip the
  /// lexicon and call eSpeak with that voice name for every word, and eSpeak
  /// has no voice called "en-gb": British voices aborted the app with
  /// "Failed to set eSpeak-ng voice". With `lang` empty, words missing from
  /// the lexicon fall back to eSpeak's "en-us" voice from the model metadata.
  static Map<String, Object?> kokoro(String modelsRoot, EnglishVoice voice, int threads) {
    final dir = kokoroDir(modelsRoot);
    final lexicon = voice.british ? 'lexicon-gb-en.txt' : 'lexicon-us-en.txt';
    return {
      'kind': 'kokoro',
      'model': p.join(dir, 'model.onnx'),
      'voices': p.join(dir, 'voices.bin'),
      'tokens': p.join(dir, 'tokens.txt'),
      'dataDir': p.join(dir, 'espeak-ng-data'),
      'dictDir': p.join(dir, 'dict'),
      'lexicon': '${p.join(dir, lexicon)},${p.join(dir, 'lexicon-zh.txt')}',
      'lang': '',
      'threads': threads,
    };
  }

  /// Piper Vietnamese (VAIS-1000). eSpeak voice "vi" comes from the model.
  static Map<String, Object?> piperVi(String modelsRoot, int threads) {
    final dir = piperViDir(modelsRoot);
    return {
      'kind': 'vits',
      'model': p.join(dir, 'vi_VN-vais1000-medium.onnx'),
      'tokens': p.join(dir, 'tokens.txt'),
      'dataDir': p.join(dir, 'espeak-ng-data'),
      'threads': threads,
    };
  }

  /// Piper English fallback (Amy, low), used only without Kokoro.
  static Map<String, Object?> piperEn(String modelsRoot, int threads) {
    final dir = piperEnDir(modelsRoot);
    return {
      'kind': 'vits',
      'model': p.join(dir, 'en_US-amy-low.onnx'),
      'tokens': p.join(dir, 'tokens.txt'),
      'dataDir': p.join(dir, 'espeak-ng-data'),
      'threads': threads,
    };
  }
}

/// The exact sherpa-onnx settings of speech recognition (Whisper + Silero
/// VAD), shared with the CI check like [TtsConfigs].
abstract final class SttConfigs {
  static Map<String, Object?> init(String modelsRoot, ModelPack whisper, int threads) {
    final dir = p.join(modelsRoot, whisper.id);
    return {
      'encoder': p.join(dir, whisper.requiredFiles[0]),
      'decoder': p.join(dir, whisper.requiredFiles[1]),
      'tokens': p.join(dir, whisper.requiredFiles[2]),
      'threads': threads,
      'vadModel': p.join(modelsRoot, ModelCatalog.vad.id, ModelCatalog.vad.fileName),
      'vadThreshold': AppConfig.vadThreshold,
      'vadMinSilence': AppConfig.vadMinSilenceSeconds,
      'vadMinSpeech': AppConfig.vadMinSpeechSeconds,
      'vadMaxSpeech': AppConfig.vadMaxSpeechSeconds,
      'vadWindow': AppConfig.vadWindowSize,
      'sampleRate': AppConfig.sttSampleRate,
    };
  }
}
