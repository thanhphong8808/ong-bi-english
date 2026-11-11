// test/device_profile_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ong_bi_english/core/services/device_profile.dart';
import 'package:ong_bi_english/core/services/model_catalog.dart';

DeviceInfo device({
  required int ramMb,
  int cores = 8,
  List<int> freqs = const [1785600, 1785600, 1785600, 1785600, 2496000, 2496000, 2496000, 2995200],
  bool openCl = true,
}) {
  return DeviceInfo(
    totalRamMb: ramMb,
    availRamMb: ramMb ~/ 2,
    socManufacturer: 'QTI',
    socModel: 'SM8450',
    hardware: 'qcom',
    model: 'SM-S908E',
    sdkInt: 34,
    cpuCores: cores,
    cpuMaxFreqsKhz: freqs,
    hasOpenCl: openCl,
  );
}

void main() {
  test('12 GB S22 Ultra gets Gemma E4B and Whisper base', () {
    final profile = DeviceProfile.select(device(ramMb: 11300));
    expect(profile.llm, LlmVariant.gemmaE4b);
    expect(profile.whisper, WhisperVariant.baseEn);
    expect(profile.preferGpu, isTrue);
  });

  test('8 GB S22 Ultra gets Gemma E2B', () {
    final profile = DeviceProfile.select(device(ramMb: 7400));
    expect(profile.llm, LlmVariant.gemmaE2b);
    expect(profile.whisper, WhisperVariant.baseEn);
  });

  test('6 GB phone still gets E2B and does not crash the selection', () {
    final profile = DeviceProfile.select(device(ramMb: 5600));
    expect(profile.llm, LlmVariant.gemmaE2b);
  });

  test('4 GB phone gets no LLM and the light Whisper', () {
    final profile = DeviceProfile.select(device(ramMb: 3700, cores: 8));
    expect(profile.llm, LlmVariant.none);
    expect(profile.whisper, WhisperVariant.tinyEn);
    expect(ModelCatalog.gemmaFor(profile), isNull);
  });

  test('thread count uses the fast cores and stays within limits', () {
    // 1 prime + 3 gold cores are within 25% of the top frequency.
    expect(DeviceProfile.select(device(ramMb: 11300)).sttThreads, 4);
    // Unknown frequencies: half of the cores, clamped.
    expect(DeviceProfile.select(device(ramMb: 11300, freqs: const [])).sttThreads, 4);
    expect(DeviceProfile.select(device(ramMb: 3700, cores: 2, freqs: const [])).sttThreads, 2);
  });

  test('no OpenCL means CPU is used for the LLM', () {
    expect(DeviceProfile.select(device(ramMb: 11300, openCl: false)).preferGpu, isFalse);
  });

  test('DeviceInfo.fromMap tolerates missing fields', () {
    final info = DeviceInfo.fromMap(const <String, Object?>{'totalRamMb': 8000});
    expect(info.totalRamMb, 8000);
    expect(info.cpuCores, 4);
    expect(info.bigCores, 2);
  });
}
