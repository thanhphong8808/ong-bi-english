// tool/dump_speech_configs.dart
//
// Prints, as JSON, the exact sherpa-onnx settings the app uses for every
// voice and for speech recognition, plus the model packs they need and the
// fixed Vietnamese lines Bi speaks. tool/ci/tts_check.py runs all of them
// with sherpa-onnx in CI, so a setting that would abort the app (such as an
// eSpeak voice name that does not exist) fails the build instead.
//
// Usage: dart run tool/dump_speech_configs.dart > speech.json
import 'dart:convert';
import 'dart:io';

import 'package:ong_bi_english/core/services/english_voice.dart';
import 'package:ong_bi_english/core/services/model_catalog.dart';
import 'package:ong_bi_english/core/services/speech_configs.dart';
import 'package:ong_bi_english/features/rewards/badges.dart';
import 'package:ong_bi_english/l10n/strings_vi.dart';

const String root = 'MODELS';
const int threads = 2;

Map<String, Object?> pack(ModelPack pack) => {
      'id': pack.id,
      'url': pack.url,
      'fileName': pack.fileName,
      'sha256': pack.sha256,
      'kind': pack.kind.name,
      'requiredFiles': pack.requiredFiles,
      'prune': pack.pruneAfterInstall,
    };

void main() {
  final whispers = <ModelPack>{ModelCatalog.whisperBase, ModelCatalog.whisperTiny};
  final out = {
    'modelsRoot': root,
    'packs': [
      for (final p in [ModelCatalog.piperVi, ModelCatalog.kokoro, ModelCatalog.piperEn, ModelCatalog.vad, ...whispers])
        pack(p),
    ],
    // In the order the app creates them: the Vietnamese voice greets first
    // and stays loaded; the English engine is replaced when the accent changes.
    'tts': [
      {'name': 'piper-vi', 'lang': 'vi', 'sid': 0, 'config': TtsConfigs.piperVi(root, threads)},
      for (final voice in EnglishVoice.values)
        {
          'name': 'kokoro-${voice.name}',
          'lang': 'en',
          'sid': voice.kokoroSid,
          'config': TtsConfigs.kokoro(root, voice, threads),
        },
      {'name': 'piper-en', 'lang': 'en', 'sid': 0, 'config': TtsConfigs.piperEn(root, threads)},
    ],
    'stt': [
      for (final whisper in whispers) {'name': whisper.id, 'config': SttConfigs.init(root, whisper, threads)},
    ],
    'viSpoken': [...S.spokenInstructions, for (final badge in badges) S.badgeSpoken(badge.title)],
  };
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(out));
}
