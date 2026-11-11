// lib/core/services/recording_janitor.dart
import 'dart:io';

import '../db/repositories.dart';

/// Deletes the child's voice recordings after the retention period.
class RecordingJanitor {
  RecordingJanitor(this.mediaRepo);

  final MediaRepo mediaRepo;

  /// Returns how many recordings were removed. [retentionDays] of 0 removes
  /// everything recorded before this moment.
  Future<int> purge({required int retentionDays, DateTime? now}) async {
    final cutoff = (now ?? DateTime.now()).subtract(Duration(days: retentionDays));
    final old = await mediaRepo.recordingsOlderThan(cutoff);
    for (final recording in old) {
      final file = File(recording.filePath);
      if (await file.exists()) {
        await file.delete();
      }
      await mediaRepo.removeRecording(recording.id);
    }
    return old.length;
  }
}
