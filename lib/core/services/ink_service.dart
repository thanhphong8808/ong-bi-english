// lib/core/services/ink_service.dart
import 'dart:ui' show Offset;

import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart';

/// One sampled point of a handwriting stroke.
class InkPoint {
  const InkPoint(this.position, this.timeMs, {this.pressure = 1.0});

  final Offset position;
  final int timeMs;

  /// 0..1 from the S Pen; 1.0 for finger input.
  final double pressure;
}

/// Handwriting recognition for free-written letters and words (level 1+).
/// Letter tracing at level 0 is scored geometrically and never uses this.
class InkService {
  static const String languageCode = 'en-US';

  final DigitalInkRecognizerModelManager _manager = DigitalInkRecognizerModelManager();
  DigitalInkRecognizer? _recognizer;

  Future<bool> isModelReady() => _manager.isModelDownloaded(languageCode);

  /// Downloads the en-US model once (about 20 MB). Needs a network connection,
  /// so it is only called from the parent-triggered first-time setup.
  Future<bool> downloadModel() => _manager.downloadModel(languageCode);

  Future<bool> deleteModel() => _manager.deleteModel(languageCode);

  /// Returns candidate texts, best first. Empty when nothing was recognised.
  Future<List<String>> recognize(List<List<InkPoint>> strokes) async {
    if (strokes.isEmpty) {
      return const <String>[];
    }
    final ink = Ink();
    ink.strokes = [
      for (final stroke in strokes)
        Stroke()
          ..points = [
            for (final point in stroke)
              StrokePoint(x: point.position.dx, y: point.position.dy, t: point.timeMs),
          ],
    ];
    final recognizer = _recognizer ??= DigitalInkRecognizer(languageCode: languageCode);
    final candidates = await recognizer.recognize(ink);
    return [for (final candidate in candidates) candidate.text];
  }

  Future<void> dispose() async {
    await _recognizer?.close();
    _recognizer = null;
  }
}
