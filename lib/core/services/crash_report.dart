// lib/core/services/crash_report.dart
import 'package:flutter/services.dart';

/// Report of the previous unexpected stop (see CrashReporter.kt).
class CrashReport {
  const CrashReport({required this.text, required this.savedTo});

  final String text;

  /// Where a copy was saved, e.g. "Download/OngBiEnglish/bao-loi-....txt".
  final String savedTo;
}

/// Talks to CrashReporter.kt. Reports never leave the phone.
class CrashReportPlatform {
  const CrashReportPlatform();

  static const MethodChannel _channel = MethodChannel('ongbi/crash');

  /// The report of the last crash, once; null when the app stopped normally.
  /// With [force], recent Dart errors alone also make a report.
  Future<CrashReport?> takePendingReport({bool force = false}) async {
    try {
      final map = await _channel.invokeMapMethod<String, String>('takePendingReport', {'force': force});
      if (map == null || (map['text'] ?? '').isEmpty) {
        return null;
      }
      return CrashReport(text: map['text']!, savedTo: map['savedTo'] ?? '');
    } catch (_) {
      return null;
    }
  }

  static int _recorded = 0;

  /// Keeps a Dart error as context for the next crash report.
  Future<void> recordError(Object error, StackTrace? stack, {String context = ''}) async {
    // A repeating error must not flood the log; the first ones matter most.
    if (_recorded >= 30) {
      return;
    }
    _recorded++;
    try {
      final text = StringBuffer()
        ..writeln('Dart error ${context.isEmpty ? '' : '($context) '}at ${DateTime.now().toIso8601String()}')
        ..writeln(error)
        ..writeln(stack ?? '');
      await _channel.invokeMethod<void>('recordDartError', {'text': text.toString()});
    } catch (_) {
      // Reporting must never cause a second failure.
    }
  }
}
