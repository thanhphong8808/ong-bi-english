// lib/core/services/device_profile.dart
import 'dart:math' as math;

import '../config/app_config.dart';

enum LlmVariant { none, gemmaE2b, gemmaE4b }

enum WhisperVariant { tinyEn, baseEn }

/// Raw hardware facts reported by the Kotlin DeviceBridge.
class DeviceInfo {
  const DeviceInfo({
    required this.totalRamMb,
    required this.availRamMb,
    required this.socManufacturer,
    required this.socModel,
    required this.hardware,
    required this.model,
    required this.sdkInt,
    required this.cpuCores,
    required this.cpuMaxFreqsKhz,
    required this.hasOpenCl,
  });

  factory DeviceInfo.fromMap(Map<String, Object?> map) {
    final freqs = (map['cpuMaxFreqsKhz'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        const <int>[];
    return DeviceInfo(
      totalRamMb: (map['totalRamMb'] as num?)?.toInt() ?? 0,
      availRamMb: (map['availRamMb'] as num?)?.toInt() ?? 0,
      socManufacturer: (map['socManufacturer'] as String?) ?? '',
      socModel: (map['socModel'] as String?) ?? '',
      hardware: (map['hardware'] as String?) ?? '',
      model: (map['model'] as String?) ?? '',
      sdkInt: (map['sdkInt'] as num?)?.toInt() ?? 0,
      cpuCores: (map['cpuCores'] as num?)?.toInt() ?? 4,
      cpuMaxFreqsKhz: freqs,
      hasOpenCl: (map['hasOpenCl'] as bool?) ?? false,
    );
  }

  final int totalRamMb;
  final int availRamMb;
  final String socManufacturer;
  final String socModel;
  final String hardware;
  final String model;
  final int sdkInt;
  final int cpuCores;
  final List<int> cpuMaxFreqsKhz;
  final bool hasOpenCl;

  /// Cores whose top frequency is within 25% of the fastest core.
  /// Falls back to half of all cores when frequencies are unreadable.
  int get bigCores {
    final known = cpuMaxFreqsKhz.where((f) => f > 0).toList();
    if (known.isEmpty) {
      return math.max(1, cpuCores ~/ 2);
    }
    final top = known.reduce(math.max);
    return known.where((f) => f >= top * 0.75).length;
  }

  String get chipLabel {
    final parts = [socManufacturer, socModel].where((p) => p.isNotEmpty).join(' ');
    return parts.isNotEmpty ? parts : hardware;
  }
}

/// Decisions derived from [DeviceInfo]. Pure logic, unit-tested.
class DeviceProfile {
  const DeviceProfile({
    required this.info,
    required this.llm,
    required this.whisper,
    required this.sttThreads,
    required this.ttsThreads,
    required this.preferGpu,
  });

  factory DeviceProfile.select(DeviceInfo info) {
    final LlmVariant llm;
    if (info.totalRamMb >= AppConfig.ramMbForGemmaE4b) {
      llm = LlmVariant.gemmaE4b;
    } else if (info.totalRamMb >= AppConfig.ramMbForGemmaE2b) {
      llm = LlmVariant.gemmaE2b;
    } else {
      llm = LlmVariant.none;
    }

    final whisper = info.totalRamMb >= AppConfig.ramMbForWhisperBase && info.cpuCores >= 6
        ? WhisperVariant.baseEn
        : WhisperVariant.tinyEn;

    // Mid/big cores only: adding little cores slows ONNX Runtime down.
    final threads = info.bigCores
        .clamp(AppConfig.minInferenceThreads, AppConfig.maxInferenceThreads)
        .toInt();

    return DeviceProfile(
      info: info,
      llm: llm,
      whisper: whisper,
      sttThreads: threads,
      ttsThreads: threads,
      preferGpu: info.hasOpenCl,
    );
  }

  final DeviceInfo info;
  final LlmVariant llm;
  final WhisperVariant whisper;
  final int sttThreads;
  final int ttsThreads;

  /// GPU is tried first when OpenCL is present; LlmService falls back to CPU.
  final bool preferGpu;

}
