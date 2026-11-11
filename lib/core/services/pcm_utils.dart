// lib/core/services/pcm_utils.dart
import 'dart:math' as math;
import 'dart:typed_data';

/// Helpers for raw 16-bit little-endian PCM. Pure Dart, unit-tested.
class PcmUtils {
  const PcmUtils._();

  /// Converts PCM16 LE bytes to floats in [-1, 1]. A trailing odd byte is ignored.
  static Float32List pcm16ToFloat32(Uint8List bytes) {
    final count = bytes.lengthInBytes ~/ 2;
    final data = ByteData.sublistView(bytes, 0, count * 2);
    final out = Float32List(count);
    for (var i = 0; i < count; i++) {
      out[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }

  /// Root-mean-square level in [0, 1].
  static double rms(Float32List samples) {
    if (samples.isEmpty) {
      return 0;
    }
    var sum = 0.0;
    for (final s in samples) {
      sum += s * s;
    }
    return math.sqrt(sum / samples.length);
  }

  static Float32List concat(List<Float32List> parts) {
    var length = 0;
    for (final part in parts) {
      length += part.length;
    }
    final out = Float32List(length);
    var offset = 0;
    for (final part in parts) {
      out.setAll(offset, part);
      offset += part.length;
    }
    return out;
  }
}
