// lib/core/services/model_catalog.dart
//
// Every downloadable model pack. Sizes and SHA-256 values for the
// sherpa-onnx packs were measured on 2026-11-10 (see docs/STACK.md).
import 'device_profile.dart';

enum PackKind { tarBz2, singleFile }

class ModelPack {
  const ModelPack({
    required this.id,
    required this.titleVi,
    required this.purposeVi,
    required this.url,
    required this.fileName,
    required this.bytes,
    required this.kind,
    required this.requiredFiles,
    required this.license,
    this.sha256,
    this.sizeIsApproximate = false,
    this.optional = false,
    this.pruneAfterInstall = const <String>[],
    this.manualPageUrl = '',
  });

  final String id;
  final String titleVi;
  final String purposeVi;
  final String url;

  /// Name of the downloaded file; also what a parent picks for manual import.
  final String fileName;
  final int bytes;
  final bool sizeIsApproximate;
  final PackKind kind;

  /// Paths relative to the pack directory that must exist after install.
  final List<String> requiredFiles;

  /// Paths removed after install to save storage (unused fp32 weights, samples).
  final List<String> pruneAfterInstall;
  final String license;

  /// Pinned SHA-256, when known. Hugging Face packs use the hash the host
  /// publishes (x-linked-etag) instead.
  final String? sha256;

  /// Optional packs are not needed for the core lessons.
  final bool optional;

  /// Page a parent opens on a computer for manual download.
  final String manualPageUrl;

  bool get isHuggingFace => url.startsWith('https://huggingface.co/');
}

class ModelCatalog {
  const ModelCatalog._();

  static const String _gh = 'https://github.com/k2-fsa/sherpa-onnx/releases/download';
  static const String _hf = 'https://huggingface.co/litert-community';

  static const ModelPack vad = ModelPack(
    id: 'vad',
    titleVi: 'Nhận biết lúc bé nói',
    purposeVi: 'Tự dừng ghi âm khi bé nói xong',
    url: '$_gh/asr-models/silero_vad.onnx',
    fileName: 'silero_vad.onnx',
    bytes: 643854,
    sha256: '9e2449e1087496d8d4caba907f23e0bd3f78d91fa552479bb9c23ac09cbb1fd6',
    kind: PackKind.singleFile,
    requiredFiles: ['silero_vad.onnx'],
    license: 'MIT (Silero VAD)',
    manualPageUrl: 'https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models',
  );

  static const ModelPack whisperBase = ModelPack(
    id: 'whisper_base',
    titleVi: 'Nghe bé nói tiếng Anh',
    purposeVi: 'Chấm điểm phát âm (bản chính xác)',
    url: '$_gh/asr-models/sherpa-onnx-whisper-base.en.tar.bz2',
    fileName: 'sherpa-onnx-whisper-base.en.tar.bz2',
    bytes: 208576005,
    sha256: '475bc7052ce299c007f6d5d5407ba8601f819a2867f6eecee510ed17df581542',
    kind: PackKind.tarBz2,
    requiredFiles: [
      'sherpa-onnx-whisper-base.en/base.en-encoder.int8.onnx',
      'sherpa-onnx-whisper-base.en/base.en-decoder.int8.onnx',
      'sherpa-onnx-whisper-base.en/base.en-tokens.txt',
    ],
    pruneAfterInstall: [
      'sherpa-onnx-whisper-base.en/base.en-encoder.onnx',
      'sherpa-onnx-whisper-base.en/base.en-decoder.onnx',
      'sherpa-onnx-whisper-base.en/test_wavs',
    ],
    license: 'MIT (OpenAI Whisper)',
    manualPageUrl: 'https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models',
  );

  static const ModelPack whisperTiny = ModelPack(
    id: 'whisper_tiny',
    titleVi: 'Nghe bé nói tiếng Anh',
    purposeVi: 'Chấm điểm phát âm (bản nhẹ cho máy yếu)',
    url: '$_gh/asr-models/sherpa-onnx-whisper-tiny.en.tar.bz2',
    fileName: 'sherpa-onnx-whisper-tiny.en.tar.bz2',
    bytes: 118071777,
    sha256: '2bd6cf965c8bb3e068ef9fa2191387ee63a9dfa2a4e37582a8109641c20005dd',
    kind: PackKind.tarBz2,
    requiredFiles: [
      'sherpa-onnx-whisper-tiny.en/tiny.en-encoder.int8.onnx',
      'sherpa-onnx-whisper-tiny.en/tiny.en-decoder.int8.onnx',
      'sherpa-onnx-whisper-tiny.en/tiny.en-tokens.txt',
    ],
    pruneAfterInstall: [
      'sherpa-onnx-whisper-tiny.en/tiny.en-encoder.onnx',
      'sherpa-onnx-whisper-tiny.en/tiny.en-decoder.onnx',
      'sherpa-onnx-whisper-tiny.en/test_wavs',
    ],
    license: 'MIT (OpenAI Whisper)',
    manualPageUrl: 'https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models',
  );

  static const ModelPack kokoro = ModelPack(
    id: 'kokoro',
    titleVi: 'Giọng đọc tiếng Anh',
    purposeVi: 'Giọng Mỹ và giọng Anh, nam và nữ',
    url: '$_gh/tts-models/kokoro-multi-lang-v1_0.tar.bz2',
    fileName: 'kokoro-multi-lang-v1_0.tar.bz2',
    bytes: 349886476,
    sha256: '60703707bc05ccd48d60e1eb723f38b07d6e474795a0b6a588d7220400e0f7a4',
    kind: PackKind.tarBz2,
    requiredFiles: [
      'kokoro-multi-lang-v1_0/model.onnx',
      'kokoro-multi-lang-v1_0/voices.bin',
      'kokoro-multi-lang-v1_0/tokens.txt',
      'kokoro-multi-lang-v1_0/lexicon-us-en.txt',
      'kokoro-multi-lang-v1_0/lexicon-gb-en.txt',
      'kokoro-multi-lang-v1_0/lexicon-zh.txt',
      'kokoro-multi-lang-v1_0/espeak-ng-data/phontab',
    ],
    license: 'Apache-2.0 (Kokoro-82M); espeak-ng-data GPL-3.0',
    manualPageUrl: 'https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models',
  );

  static const ModelPack piperVi = ModelPack(
    id: 'piper_vi',
    titleVi: 'Giọng đọc tiếng Việt',
    purposeVi: 'Bi đọc hướng dẫn bằng tiếng Việt',
    url: '$_gh/tts-models/vits-piper-vi_VN-vais1000-medium.tar.bz2',
    fileName: 'vits-piper-vi_VN-vais1000-medium.tar.bz2',
    bytes: 67154040,
    sha256: 'fa1367710767d36ed5cf13b4a449e20c35ffd12791c2e47c2e64142bfa55551a',
    kind: PackKind.tarBz2,
    requiredFiles: [
      'vits-piper-vi_VN-vais1000-medium/vi_VN-vais1000-medium.onnx',
      'vits-piper-vi_VN-vais1000-medium/tokens.txt',
      'vits-piper-vi_VN-vais1000-medium/espeak-ng-data/phontab',
    ],
    license: 'MIT (Piper); giọng VAIS-1000 CC BY 4.0; espeak-ng-data GPL-3.0',
    manualPageUrl: 'https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models',
  );

  /// Fallback English voice, used only when the Kokoro pack is missing.
  static const ModelPack piperEn = ModelPack(
    id: 'piper_en',
    titleVi: 'Giọng tiếng Anh dự phòng',
    purposeVi: 'Chỉ cần khi không tải được giọng chính',
    url: '$_gh/tts-models/vits-piper-en_US-amy-low.tar.bz2',
    fileName: 'vits-piper-en_US-amy-low.tar.bz2',
    bytes: 67095344,
    sha256: 'c70f5284a09a7fd4ed203b39b2ff51cac1432b422b852eb647b481dade3cf639',
    kind: PackKind.tarBz2,
    requiredFiles: [
      'vits-piper-en_US-amy-low/en_US-amy-low.onnx',
      'vits-piper-en_US-amy-low/tokens.txt',
      'vits-piper-en_US-amy-low/espeak-ng-data/phontab',
    ],
    license: 'MIT (Piper); espeak-ng-data GPL-3.0',
    optional: true,
    manualPageUrl: 'https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models',
  );

  static const ModelPack gemmaE2b = ModelPack(
    id: 'gemma_e2b',
    titleVi: 'Bộ não của Bi (Gemma 4 E2B)',
    purposeVi: 'Chỉ dùng cho "Nói chuyện với Bi"',
    url: '$_hf/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
    fileName: 'gemma-4-E2B-it.litertlm',
    bytes: 2708000000,
    sizeIsApproximate: true,
    kind: PackKind.singleFile,
    requiredFiles: ['gemma-4-E2B-it.litertlm'],
    license: 'Apache-2.0 (Gemma 4, Google)',
    optional: true,
    manualPageUrl: 'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/tree/main',
  );

  static const ModelPack gemmaE4b = ModelPack(
    id: 'gemma_e4b',
    titleVi: 'Bộ não của Bi (Gemma 4 E4B)',
    purposeVi: 'Chỉ dùng cho "Nói chuyện với Bi"',
    url: '$_hf/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm',
    fileName: 'gemma-4-E4B-it.litertlm',
    bytes: 3827000000,
    sizeIsApproximate: true,
    kind: PackKind.singleFile,
    requiredFiles: ['gemma-4-E4B-it.litertlm'],
    license: 'Apache-2.0 (Gemma 4, Google)',
    optional: true,
    manualPageUrl: 'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/tree/main',
  );

  static const List<ModelPack> all = [
    vad,
    whisperBase,
    whisperTiny,
    kokoro,
    piperVi,
    piperEn,
    gemmaE2b,
    gemmaE4b,
  ];

  static ModelPack whisperFor(DeviceProfile profile) =>
      profile.whisper == WhisperVariant.baseEn ? whisperBase : whisperTiny;

  static ModelPack? gemmaFor(DeviceProfile profile) {
    switch (profile.llm) {
      case LlmVariant.gemmaE4b:
        return gemmaE4b;
      case LlmVariant.gemmaE2b:
        return gemmaE2b;
      case LlmVariant.none:
        return null;
    }
  }

  /// Packs offered on this device, required ones first.
  static List<ModelPack> packsFor(DeviceProfile profile) {
    final gemma = gemmaFor(profile);
    return [
      vad,
      whisperFor(profile),
      kokoro,
      piperVi,
      ?gemma,
    ];
  }

  static int totalBytes(Iterable<ModelPack> packs) {
    var total = 0;
    for (final pack in packs) {
      total += pack.bytes;
    }
    return total;
  }

  static ModelPack? byId(String id) {
    for (final pack in all) {
      if (pack.id == id) {
        return pack;
      }
    }
    return null;
  }
}
