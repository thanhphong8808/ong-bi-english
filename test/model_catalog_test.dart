// test/model_catalog_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ong_bi_english/core/services/device_profile.dart';
import 'package:ong_bi_english/core/services/model_catalog.dart';

DeviceProfile profileFor(int ramMb) {
  return DeviceProfile.select(
    DeviceInfo(
      totalRamMb: ramMb,
      availRamMb: ramMb ~/ 2,
      socManufacturer: '',
      socModel: '',
      hardware: '',
      model: '',
      sdkInt: 34,
      cpuCores: 8,
      cpuMaxFreqsKhz: const [],
      hasOpenCl: true,
    ),
  );
}

void main() {
  test('pack ids and file names are unique', () {
    final ids = ModelCatalog.all.map((p) => p.id).toSet();
    final names = ModelCatalog.all.map((p) => p.fileName).toSet();
    expect(ids.length, ModelCatalog.all.length);
    expect(names.length, ModelCatalog.all.length);
  });

  test('every pack is HTTPS, has required files and a licence', () {
    for (final pack in ModelCatalog.all) {
      expect(pack.url, startsWith('https://'), reason: pack.id);
      expect(pack.requiredFiles, isNotEmpty, reason: pack.id);
      expect(pack.license, isNotEmpty, reason: pack.id);
      expect(pack.bytes, greaterThan(0), reason: pack.id);
      expect(pack.manualPageUrl, startsWith('https://'), reason: pack.id);
    }
  });

  test('pinned hashes are well-formed SHA-256 values', () {
    for (final pack in ModelCatalog.all) {
      final hash = pack.sha256;
      if (hash != null) {
        expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hash), isTrue, reason: pack.id);
      }
    }
  });

  test('only official Gemma instruct builds are listed', () {
    for (final pack in ModelCatalog.all.where((p) => p.id.startsWith('gemma'))) {
      expect(pack.url, contains('huggingface.co/litert-community/'));
      expect(pack.fileName, contains('-it'));
      expect(pack.url.toLowerCase(), isNot(contains('uncensored')));
      expect(pack.url.toLowerCase(), isNot(contains('abliterated')));
      expect(pack.optional, isTrue, reason: 'core lessons must not need the LLM');
    }
  });

  test('core lessons never require an optional pack', () {
    final packs = ModelCatalog.packsFor(profileFor(11300));
    final required = packs.where((p) => !p.optional).map((p) => p.id).toList();
    expect(required, ['vad', 'whisper_base', 'kokoro', 'piper_vi']);
    expect(packs.last.id, 'gemma_e4b');
  });

  test('low-RAM devices are offered the light packs and no LLM', () {
    final ids = ModelCatalog.packsFor(profileFor(3700)).map((p) => p.id).toList();
    expect(ids, ['vad', 'whisper_tiny', 'kokoro', 'piper_vi']);
  });

  test('total size is the sum of the packs', () {
    expect(
      ModelCatalog.totalBytes([ModelCatalog.vad, ModelCatalog.piperVi]),
      ModelCatalog.vad.bytes + ModelCatalog.piperVi.bytes,
    );
  });
}
