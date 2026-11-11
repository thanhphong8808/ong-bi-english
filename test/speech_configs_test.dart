// test/speech_configs_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ong_bi_english/core/services/english_voice.dart';
import 'package:ong_bi_english/core/services/model_catalog.dart';
import 'package:ong_bi_english/core/services/speech_configs.dart';

void main() {
  const root = '/models';

  bool shipped(ModelPack pack, String path) =>
      pack.requiredFiles.any((f) => path == '$root/${pack.id}/$f');

  test('Kokoro never passes an eSpeak voice name (British voices aborted the app)', () {
    for (final voice in EnglishVoice.values) {
      final config = TtsConfigs.kokoro(root, voice, 2);
      expect(config['lang'], '', reason: '$voice: a non-empty lang bypasses the lexicon');
      final lexicons = (config['lexicon']! as String).split(',');
      expect(lexicons.first.endsWith(voice.british ? 'lexicon-gb-en.txt' : 'lexicon-us-en.txt'), isTrue,
          reason: '$voice uses the wrong accent lexicon');
      for (final lexicon in lexicons) {
        expect(shipped(ModelCatalog.kokoro, lexicon), isTrue, reason: '$lexicon is not a required file');
      }
      expect(shipped(ModelCatalog.kokoro, config['model']! as String), isTrue);
    }
  });

  test('every voice points at files its pack installs', () {
    final vi = TtsConfigs.piperVi(root, 2);
    expect(shipped(ModelCatalog.piperVi, vi['model']! as String), isTrue);
    expect(shipped(ModelCatalog.piperVi, vi['tokens']! as String), isTrue);
    final en = TtsConfigs.piperEn(root, 2);
    expect(shipped(ModelCatalog.piperEn, en['model']! as String), isTrue);
    expect(shipped(ModelCatalog.piperEn, en['tokens']! as String), isTrue);
  });

  test('speech recognition points at the installed Whisper and VAD files', () {
    for (final whisper in [ModelCatalog.whisperBase, ModelCatalog.whisperTiny]) {
      final config = SttConfigs.init(root, whisper, 2);
      for (final key in ['encoder', 'decoder', 'tokens']) {
        expect(shipped(whisper, config[key]! as String), isTrue, reason: '${whisper.id} $key');
      }
      expect(shipped(ModelCatalog.vad, config['vadModel']! as String), isTrue);
    }
  });
}
