// lib/core/db/app_database.dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../config/app_config.dart';
import 'repositories.dart';
import 'schema.dart';

/// SQLite through drift, using drift's raw-SQL API so no generated code is
/// needed. Schema and migrations live in [DbSchema].
class AppDatabase extends GeneratedDatabase {
  AppDatabase() : super(driftDatabase(name: AppConfig.databaseName));

  /// For tests: pass any drift executor.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => DbSchema.version;

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          for (final statement in DbSchema.createV1) {
            await customStatement(statement);
          }
          await customInsert(
            'INSERT INTO profiles (name, created_at) VALUES (?, ?)',
            variables: [
              Variable.withString(AppConfig.defaultProfileName),
              Variable.withInt(DateTime.now().millisecondsSinceEpoch),
            ],
          );
        },
        onUpgrade: (m, from, to) async {
          for (var version = from; version < to; version++) {
            for (final statement in DbSchema.upgrades[version] ?? const <String>[]) {
              await customStatement(statement);
            }
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  late final SettingsRepo settingsRepo = SettingsRepo(this);
  late final ProfileRepo profileRepo = ProfileRepo(this);
  late final ProgressRepo progressRepo = ProgressRepo(this);
  late final StudyRepo studyRepo = StudyRepo(this);
  late final TestRepo testRepo = TestRepo(this);
  late final MediaRepo mediaRepo = MediaRepo(this);
  late final ChatLogRepo chatLogRepo = ChatLogRepo(this);
  late final ModelRepo modelRepo = ModelRepo(this);
  late final RewardRepo rewardRepo = RewardRepo(this);

  /// Every row of a table as plain maps, for backups.
  Future<List<Map<String, Object?>>> dumpTable(String table) async {
    final rows = await customSelect('SELECT * FROM $table').get();
    return [for (final row in rows) Map<String, Object?>.from(row.data)];
  }

  /// Replaces the learning data with a backup, inside one transaction.
  Future<void> restoreTables(Map<String, List<Map<String, Object?>>> tables) {
    return transaction(() async {
      for (final table in DbSchema.backupTables.reversed) {
        await customStatement('DELETE FROM $table');
      }
      for (final table in DbSchema.backupTables) {
        for (final row in tables[table] ?? const <Map<String, Object?>>[]) {
          if (row.isEmpty) {
            continue;
          }
          final columns = row.keys.toList();
          final placeholders = List.filled(columns.length, '?').join(', ');
          await customInsert(
            'INSERT INTO $table (${columns.join(', ')}) VALUES ($placeholders)',
            variables: [for (final c in columns) _variable(row[c])],
          );
        }
      }
    });
  }

  static Variable<Object> _variable(Object? value) {
    if (value == null) {
      return const Variable<Object>(null);
    }
    if (value is int) {
      return Variable<Object>(value);
    }
    if (value is double) {
      return Variable<Object>(value);
    }
    if (value is bool) {
      return Variable<Object>(value ? 1 : 0);
    }
    return Variable<Object>(value.toString());
  }
}
