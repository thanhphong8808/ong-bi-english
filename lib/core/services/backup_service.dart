// lib/core/services/backup_service.dart
import 'dart:convert';
import 'dart:typed_data';

import '../db/app_database.dart';
import '../db/repositories.dart';
import '../db/schema.dart';
import 'platform_bridge.dart';

class BackupException implements Exception {
  const BackupException(this.code);

  /// cancelled | invalid | newer_version
  final String code;
}

/// Exports learning progress to a JSON file in Download and restores it on
/// another phone. Recordings and the audio cache are not included.
class BackupService {
  BackupService({required this.db, required this.files});

  final AppDatabase db;
  final FilesPlatform files;

  static const String format = 'ong-bi-english-backup';

  Future<Map<String, Object?>> buildBackup() async {
    final tables = <String, Object?>{};
    for (final table in DbSchema.backupTables) {
      tables[table] = await db.dumpTable(table);
    }
    return {
      'format': format,
      'schema': DbSchema.version,
      'exported_at': DateTime.now().toIso8601String(),
      'tables': tables,
    };
  }

  /// Returns the path shown to the parent, e.g. Download/OngBiEnglish/...
  Future<String> exportToDownloads() async {
    final data = await buildBackup();
    final bytes = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent(' ').convert(data)));
    final name = 'ongbi-backup-${StudyRepo.dayKey(DateTime.now())}.json';
    return files.saveToDownloads(name: name, mime: 'application/json', bytes: bytes);
  }

  /// Parses and checks a backup; throws [BackupException] when unusable.
  static Map<String, List<Map<String, Object?>>> parse(String text) {
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const BackupException('invalid');
    }
    if (decoded is! Map<String, dynamic> || decoded['format'] != format) {
      throw const BackupException('invalid');
    }
    final schema = decoded['schema'];
    if (schema is! int) {
      throw const BackupException('invalid');
    }
    if (schema > DbSchema.version) {
      throw const BackupException('newer_version');
    }
    final rawTables = decoded['tables'];
    if (rawTables is! Map<String, dynamic>) {
      throw const BackupException('invalid');
    }
    final out = <String, List<Map<String, Object?>>>{};
    for (final table in DbSchema.backupTables) {
      final rows = rawTables[table];
      if (rows is! List) {
        continue;
      }
      out[table] = [
        for (final row in rows)
          if (row is Map<String, dynamic>) Map<String, Object?>.from(row),
      ];
    }
    if ((out['profiles'] ?? const []).isEmpty) {
      throw const BackupException('invalid');
    }
    return out;
  }

  /// Picks a backup file and replaces the current progress with it.
  Future<void> restoreFromPicker() async {
    final text = await files.pickText();
    if (text == null) {
      throw const BackupException('cancelled');
    }
    await db.restoreTables(parse(text));
  }
}
