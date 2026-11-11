// lib/core/db/repositories.dart
//
// Hand-written data classes and repositories over drift's raw-SQL API.
// Timestamps are stored as milliseconds since the epoch.
import 'package:drift/drift.dart';

import '../config/app_config.dart';

int _ms(DateTime time) => time.millisecondsSinceEpoch;

DateTime _time(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);

Variable<String> _s(String value) => Variable.withString(value);

Variable<int> _i(int value) => Variable.withInt(value);

Variable<double> _d(double value) => Variable.withReal(value);

int _int(QueryRow row, String key) => row.read<int>(key);

String _str(QueryRow row, String key) => row.read<String>(key);

double _dbl(QueryRow row, String key) {
  final value = row.data[key];
  if (value is num) {
    return value.toDouble();
  }
  return 0;
}

bool _bool(QueryRow row, String key) => _int(row, key) != 0;

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.level,
    required this.unitIndex,
    required this.stars,
    required this.placementDone,
    required this.createdAt,
  });

  factory Profile.fromRow(QueryRow row) => Profile(
        id: _int(row, 'id'),
        name: _str(row, 'name'),
        level: _int(row, 'level'),
        unitIndex: _int(row, 'unit_index'),
        stars: _int(row, 'stars'),
        placementDone: _bool(row, 'placement_done'),
        createdAt: _time(_int(row, 'created_at')),
      );

  final int id;
  final String name;
  final int level;

  /// Index of the current unit inside the level's unit list (0-based).
  final int unitIndex;
  final int stars;
  final bool placementDone;
  final DateTime createdAt;
}

class ItemProgressRow {
  const ItemProgressRow({
    required this.itemId,
    required this.unitId,
    required this.skill,
    required this.box,
    required this.dueAt,
    required this.correctCount,
    required this.wrongCount,
    required this.lastSeenAt,
  });

  factory ItemProgressRow.fromRow(QueryRow row) => ItemProgressRow(
        itemId: _str(row, 'item_id'),
        unitId: _str(row, 'unit_id'),
        skill: _str(row, 'skill'),
        box: _int(row, 'box'),
        dueAt: _time(_int(row, 'due_at')),
        correctCount: _int(row, 'correct_count'),
        wrongCount: _int(row, 'wrong_count'),
        lastSeenAt: _time(_int(row, 'last_seen_at')),
      );

  final String itemId;
  final String unitId;
  final String skill;
  final int box;
  final DateTime dueAt;
  final int correctCount;
  final int wrongCount;
  final DateTime lastSeenAt;
}

class AttemptRow {
  const AttemptRow({
    required this.itemId,
    required this.skill,
    required this.correct,
    required this.score,
    required this.at,
  });

  factory AttemptRow.fromRow(QueryRow row) => AttemptRow(
        itemId: _str(row, 'item_id'),
        skill: _str(row, 'skill'),
        correct: _bool(row, 'correct'),
        score: _dbl(row, 'score'),
        at: _time(_int(row, 'at')),
      );

  final String itemId;
  final String skill;
  final bool correct;
  final double score;
  final DateTime at;
}

class UnitProgress {
  const UnitProgress({
    required this.unitId,
    this.lessonsDone = 0,
    this.reviewDone = false,
    this.passed = false,
    this.bestScore = 0,
    this.lastTestAt,
    this.remedialPending = false,
  });

  factory UnitProgress.fromRow(QueryRow row) {
    final last = _int(row, 'last_test_at');
    return UnitProgress(
      unitId: _str(row, 'unit_id'),
      lessonsDone: _int(row, 'lessons_done'),
      reviewDone: _bool(row, 'review_done'),
      passed: _bool(row, 'passed'),
      bestScore: _dbl(row, 'best_score'),
      lastTestAt: last == 0 ? null : _time(last),
      remedialPending: _bool(row, 'remedial_pending'),
    );
  }

  final String unitId;
  final int lessonsDone;
  final bool reviewDone;
  final bool passed;
  final double bestScore;
  final DateTime? lastTestAt;

  /// A failed unit test leaves a remedial lesson to do before the retake.
  final bool remedialPending;

  UnitProgress copyWith({
    int? lessonsDone,
    bool? reviewDone,
    bool? passed,
    double? bestScore,
    DateTime? lastTestAt,
    bool? remedialPending,
  }) {
    return UnitProgress(
      unitId: unitId,
      lessonsDone: lessonsDone ?? this.lessonsDone,
      reviewDone: reviewDone ?? this.reviewDone,
      passed: passed ?? this.passed,
      bestScore: bestScore ?? this.bestScore,
      lastTestAt: lastTestAt ?? this.lastTestAt,
      remedialPending: remedialPending ?? this.remedialPending,
    );
  }
}

class StudyDay {
  const StudyDay({required this.day, required this.seconds, required this.lessonsDone});

  factory StudyDay.fromRow(QueryRow row) => StudyDay(
        day: _str(row, 'day'),
        seconds: _int(row, 'seconds'),
        lessonsDone: _int(row, 'lessons_done'),
      );

  final String day;
  final int seconds;
  final int lessonsDone;
}

class TestResult {
  const TestResult({
    required this.id,
    required this.kind,
    required this.targetId,
    required this.score,
    required this.passed,
    required this.detailJson,
    required this.takenAt,
  });

  factory TestResult.fromRow(QueryRow row) => TestResult(
        id: _int(row, 'id'),
        kind: _str(row, 'kind'),
        targetId: _str(row, 'target_id'),
        score: _dbl(row, 'score'),
        passed: _bool(row, 'passed'),
        detailJson: _str(row, 'detail_json'),
        takenAt: _time(_int(row, 'taken_at')),
      );

  final int id;

  /// placement | unit | level | weekly
  final String kind;
  final String targetId;
  final double score;
  final bool passed;
  final String detailJson;
  final DateTime takenAt;
}

class AudioCacheEntry {
  const AudioCacheEntry({
    required this.cacheKey,
    required this.filePath,
    required this.engine,
    required this.bytes,
  });

  final String cacheKey;
  final String filePath;
  final String engine;
  final int bytes;
}

class Recording {
  const Recording({required this.id, required this.filePath});

  final int id;
  final String filePath;
}

class ChatLog {
  const ChatLog({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.flagged,
    required this.flagReason,
    required this.createdAt,
  });

  factory ChatLog.fromRow(QueryRow row) => ChatLog(
        id: _int(row, 'id'),
        sessionId: _str(row, 'session_id'),
        role: _str(row, 'role'),
        content: _str(row, 'content'),
        flagged: _bool(row, 'flagged'),
        flagReason: _str(row, 'flag_reason'),
        createdAt: _time(_int(row, 'created_at')),
      );

  final int id;
  final String sessionId;

  /// kid | bi
  final String role;
  final String content;
  final bool flagged;
  final String flagReason;
  final DateTime createdAt;
}

class ModelInstall {
  const ModelInstall({
    required this.packId,
    required this.directory,
    required this.bytes,
    required this.sha256,
    required this.checksumVerified,
    required this.source,
  });

  final String packId;
  final String directory;
  final int bytes;
  final String sha256;
  final bool checksumVerified;
  final String source;
}

class Reward {
  const Reward({required this.stickerId, required this.earnedAt});

  final String stickerId;
  final DateTime earnedAt;
}

// ---------------------------------------------------------------------------
// Repositories
// ---------------------------------------------------------------------------

abstract class _Repo {
  const _Repo(this.db);

  final GeneratedDatabase db;
}

class SettingsRepo extends _Repo {
  const SettingsRepo(super.db);

  Future<String?> read(String key, {int profileId = 0}) async {
    final row = await db.customSelect(
      'SELECT setting_value FROM settings WHERE profile_id = ? AND setting_key = ?',
      variables: [_i(profileId), _s(key)],
    ).getSingleOrNull();
    return row == null ? null : _str(row, 'setting_value');
  }

  Future<Map<String, String>> readAll({int profileId = 0}) async {
    final rows = await db.customSelect(
      'SELECT setting_key, setting_value FROM settings WHERE profile_id = ?',
      variables: [_i(profileId)],
    ).get();
    return {for (final row in rows) _str(row, 'setting_key'): _str(row, 'setting_value')};
  }

  Future<void> write(String key, String value, {int profileId = 0}) async {
    await db.customInsert(
      'INSERT OR REPLACE INTO settings (profile_id, setting_key, setting_value) VALUES (?, ?, ?)',
      variables: [_i(profileId), _s(key), _s(value)],
    );
  }

  Future<void> writeAll(Map<String, String> values, {int profileId = 0}) {
    return db.transaction(() async {
      for (final entry in values.entries) {
        await write(entry.key, entry.value, profileId: profileId);
      }
    });
  }
}

class ProfileRepo extends _Repo {
  const ProfileRepo(super.db);

  static const List<String> _perProfileTables = [
    'item_progress',
    'attempts',
    'unit_progress',
    'dialogue_progress',
    'study_days',
    'test_results',
    'recordings',
    'chat_logs',
    'rewards',
  ];

  Future<List<Profile>> all() async {
    final rows = await db.customSelect('SELECT * FROM profiles ORDER BY id').get();
    return rows.map(Profile.fromRow).toList();
  }

  Future<Profile?> byId(int id) async {
    final row = await db.customSelect(
      'SELECT * FROM profiles WHERE id = ?',
      variables: [_i(id)],
    ).getSingleOrNull();
    return row == null ? null : Profile.fromRow(row);
  }

  /// Returns the new id, or null when the profile limit is reached.
  Future<int?> create(String name) async {
    final existing = await all();
    if (existing.length >= AppConfig.maxProfiles) {
      return null;
    }
    return db.customInsert(
      'INSERT INTO profiles (name, created_at) VALUES (?, ?)',
      variables: [_s(name), _i(_ms(DateTime.now()))],
    );
  }

  Future<void> rename(int id, String name) async {
    await db.customUpdate(
      'UPDATE profiles SET name = ? WHERE id = ?',
      variables: [_s(name), _i(id)],
    );
  }

  /// Deletes a profile and all of its learning data. The last profile cannot
  /// be deleted.
  Future<bool> delete(int id) async {
    final existing = await all();
    if (existing.length <= 1) {
      return false;
    }
    await db.transaction(() async {
      for (final table in _perProfileTables) {
        await db.customUpdate('DELETE FROM $table WHERE profile_id = ?', variables: [_i(id)]);
      }
      await db.customUpdate('DELETE FROM settings WHERE profile_id = ?', variables: [_i(id)]);
      await db.customUpdate('DELETE FROM profiles WHERE id = ?', variables: [_i(id)]);
    });
    return true;
  }

  Future<void> addStars(int id, int amount) async {
    await db.customUpdate(
      'UPDATE profiles SET stars = stars + ? WHERE id = ?',
      variables: [_i(amount), _i(id)],
    );
  }

  Future<void> setPosition(int id, {required int level, required int unitIndex}) async {
    await db.customUpdate(
      'UPDATE profiles SET level = ?, unit_index = ? WHERE id = ?',
      variables: [_i(level), _i(unitIndex), _i(id)],
    );
  }

  Future<void> setPlacementDone(int id, bool done) async {
    await db.customUpdate(
      'UPDATE profiles SET placement_done = ? WHERE id = ?',
      variables: [_i(done ? 1 : 0), _i(id)],
    );
  }
}

class ProgressRepo extends _Repo {
  const ProgressRepo(super.db);

  Future<List<ItemProgressRow>> all(int profileId) async {
    final rows = await db.customSelect(
      'SELECT * FROM item_progress WHERE profile_id = ?',
      variables: [_i(profileId)],
    ).get();
    return rows.map(ItemProgressRow.fromRow).toList();
  }

  Future<void> upsert(int profileId, ItemProgressRow row) async {
    await db.customInsert(
      'INSERT OR REPLACE INTO item_progress '
      '(profile_id, item_id, unit_id, skill, box, due_at, correct_count, wrong_count, last_seen_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        _i(profileId),
        _s(row.itemId),
        _s(row.unitId),
        _s(row.skill),
        _i(row.box),
        _i(_ms(row.dueAt)),
        _i(row.correctCount),
        _i(row.wrongCount),
        _i(_ms(row.lastSeenAt)),
      ],
    );
  }

  Future<void> addAttempt(
    int profileId, {
    required String itemId,
    required String skill,
    required bool correct,
    required double score,
    DateTime? at,
  }) async {
    await db.customInsert(
      'INSERT INTO attempts (profile_id, item_id, skill, correct, score, at) VALUES (?, ?, ?, ?, ?, ?)',
      variables: [
        _i(profileId),
        _s(itemId),
        _s(skill),
        _i(correct ? 1 : 0),
        _d(score),
        _i(_ms(at ?? DateTime.now())),
      ],
    );
  }

  Future<List<AttemptRow>> attemptsSince(int profileId, DateTime since) async {
    final rows = await db.customSelect(
      'SELECT * FROM attempts WHERE profile_id = ? AND at >= ? ORDER BY at',
      variables: [_i(profileId), _i(_ms(since))],
    ).get();
    return rows.map(AttemptRow.fromRow).toList();
  }

  Future<List<UnitProgress>> units(int profileId) async {
    final rows = await db.customSelect(
      'SELECT * FROM unit_progress WHERE profile_id = ?',
      variables: [_i(profileId)],
    ).get();
    return rows.map(UnitProgress.fromRow).toList();
  }

  Future<UnitProgress> unit(int profileId, String unitId) async {
    final row = await db.customSelect(
      'SELECT * FROM unit_progress WHERE profile_id = ? AND unit_id = ?',
      variables: [_i(profileId), _s(unitId)],
    ).getSingleOrNull();
    return row == null ? UnitProgress(unitId: unitId) : UnitProgress.fromRow(row);
  }

  Future<void> saveUnit(int profileId, UnitProgress unit) async {
    await db.customInsert(
      'INSERT OR REPLACE INTO unit_progress '
      '(profile_id, unit_id, lessons_done, review_done, passed, best_score, last_test_at, remedial_pending) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        _i(profileId),
        _s(unit.unitId),
        _i(unit.lessonsDone),
        _i(unit.reviewDone ? 1 : 0),
        _i(unit.passed ? 1 : 0),
        _d(unit.bestScore),
        _i(unit.lastTestAt == null ? 0 : _ms(unit.lastTestAt!)),
        _i(unit.remedialPending ? 1 : 0),
      ],
    );
  }

  Future<Map<String, int>> dialogueStages(int profileId) async {
    final rows = await db.customSelect(
      'SELECT dialogue_id, stage FROM dialogue_progress WHERE profile_id = ?',
      variables: [_i(profileId)],
    ).get();
    return {for (final row in rows) _str(row, 'dialogue_id'): _int(row, 'stage')};
  }

  Future<void> setDialogueStage(int profileId, String dialogueId, int stage) async {
    await db.customInsert(
      'INSERT OR REPLACE INTO dialogue_progress (profile_id, dialogue_id, stage, last_at) VALUES (?, ?, ?, ?)',
      variables: [_i(profileId), _s(dialogueId), _i(stage), _i(_ms(DateTime.now()))],
    );
  }
}

class StudyRepo extends _Repo {
  const StudyRepo(super.db);

  static String dayKey(DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)}';
  }

  Future<void> addSeconds(int profileId, DateTime when, int seconds) async {
    await db.customInsert(
      'INSERT OR IGNORE INTO study_days (profile_id, day) VALUES (?, ?)',
      variables: [_i(profileId), _s(dayKey(when))],
    );
    await db.customUpdate(
      'UPDATE study_days SET seconds = seconds + ? WHERE profile_id = ? AND day = ?',
      variables: [_i(seconds), _i(profileId), _s(dayKey(when))],
    );
  }

  Future<void> addLesson(int profileId, DateTime when) async {
    await db.customInsert(
      'INSERT OR IGNORE INTO study_days (profile_id, day) VALUES (?, ?)',
      variables: [_i(profileId), _s(dayKey(when))],
    );
    await db.customUpdate(
      'UPDATE study_days SET lessons_done = lessons_done + 1 WHERE profile_id = ? AND day = ?',
      variables: [_i(profileId), _s(dayKey(when))],
    );
  }

  Future<StudyDay> day(int profileId, DateTime when) async {
    final row = await db.customSelect(
      'SELECT * FROM study_days WHERE profile_id = ? AND day = ?',
      variables: [_i(profileId), _s(dayKey(when))],
    ).getSingleOrNull();
    return row == null
        ? StudyDay(day: dayKey(when), seconds: 0, lessonsDone: 0)
        : StudyDay.fromRow(row);
  }

  Future<List<StudyDay>> recent(int profileId, int days) async {
    final since = dayKey(DateTime.now().subtract(Duration(days: days - 1)));
    final rows = await db.customSelect(
      'SELECT * FROM study_days WHERE profile_id = ? AND day >= ? ORDER BY day',
      variables: [_i(profileId), _s(since)],
    ).get();
    return rows.map(StudyDay.fromRow).toList();
  }
}

class TestRepo extends _Repo {
  const TestRepo(super.db);

  Future<int> add(
    int profileId, {
    required String kind,
    required String targetId,
    required double score,
    required bool passed,
    required String detailJson,
  }) {
    return db.customInsert(
      'INSERT INTO test_results (profile_id, kind, target_id, score, passed, detail_json, taken_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      variables: [
        _i(profileId),
        _s(kind),
        _s(targetId),
        _d(score),
        _i(passed ? 1 : 0),
        _s(detailJson),
        _i(_ms(DateTime.now())),
      ],
    );
  }

  Future<List<TestResult>> forProfile(int profileId) async {
    final rows = await db.customSelect(
      'SELECT * FROM test_results WHERE profile_id = ? ORDER BY taken_at DESC',
      variables: [_i(profileId)],
    ).get();
    return rows.map(TestResult.fromRow).toList();
  }

  Future<TestResult?> latest(int profileId, String kind, String targetId) async {
    final row = await db.customSelect(
      'SELECT * FROM test_results WHERE profile_id = ? AND kind = ? AND target_id = ? '
      'ORDER BY taken_at DESC LIMIT 1',
      variables: [_i(profileId), _s(kind), _s(targetId)],
    ).getSingleOrNull();
    return row == null ? null : TestResult.fromRow(row);
  }
}

class MediaRepo extends _Repo {
  const MediaRepo(super.db);

  Future<AudioCacheEntry?> cacheEntry(String key) async {
    final row = await db.customSelect(
      'SELECT * FROM audio_cache WHERE cache_key = ?',
      variables: [_s(key)],
    ).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return AudioCacheEntry(
      cacheKey: _str(row, 'cache_key'),
      filePath: _str(row, 'file_path'),
      engine: _str(row, 'engine'),
      bytes: _int(row, 'bytes'),
    );
  }

  Future<void> putCacheEntry({
    required String key,
    required String filePath,
    required String engine,
    required int bytes,
  }) async {
    await db.customInsert(
      'INSERT OR REPLACE INTO audio_cache (cache_key, file_path, engine, bytes, created_at) VALUES (?, ?, ?, ?, ?)',
      variables: [_s(key), _s(filePath), _s(engine), _i(bytes), _i(_ms(DateTime.now()))],
    );
  }

  Future<void> removeCacheEntry(String key) async {
    await db.customUpdate('DELETE FROM audio_cache WHERE cache_key = ?', variables: [_s(key)]);
  }

  Future<int> cacheBytes() async {
    final row = await db.customSelect('SELECT COALESCE(SUM(bytes), 0) AS total FROM audio_cache').getSingle();
    return _int(row, 'total');
  }

  Future<void> clearCacheEntries() async {
    await db.customUpdate('DELETE FROM audio_cache');
  }

  Future<int> addRecording({
    required int profileId,
    required String filePath,
    String itemId = '',
  }) {
    return db.customInsert(
      'INSERT INTO recordings (profile_id, item_id, file_path, created_at) VALUES (?, ?, ?, ?)',
      variables: [_i(profileId), _s(itemId), _s(filePath), _i(_ms(DateTime.now()))],
    );
  }

  Future<List<Recording>> recordingsOlderThan(DateTime cutoff) async {
    final rows = await db.customSelect(
      'SELECT id, file_path FROM recordings WHERE created_at < ?',
      variables: [_i(_ms(cutoff))],
    ).get();
    return [for (final row in rows) Recording(id: _int(row, 'id'), filePath: _str(row, 'file_path'))];
  }

  Future<void> removeRecording(int id) async {
    await db.customUpdate('DELETE FROM recordings WHERE id = ?', variables: [_i(id)]);
  }
}

class ChatLogRepo extends _Repo {
  const ChatLogRepo(super.db);

  Future<int> add({
    required int profileId,
    required String sessionId,
    required String role,
    required String content,
    bool flagged = false,
    String flagReason = '',
  }) {
    return db.customInsert(
      'INSERT INTO chat_logs (profile_id, session_id, role, content, flagged, flag_reason, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      variables: [
        _i(profileId),
        _s(sessionId),
        _s(role),
        _s(content),
        _i(flagged ? 1 : 0),
        _s(flagReason),
        _i(_ms(DateTime.now())),
      ],
    );
  }

  Future<List<ChatLog>> forProfile(int profileId) async {
    final rows = await db.customSelect(
      'SELECT * FROM chat_logs WHERE profile_id = ? ORDER BY created_at DESC, id DESC LIMIT 500',
      variables: [_i(profileId)],
    ).get();
    return rows.map(ChatLog.fromRow).toList();
  }

  Future<void> clearProfile(int profileId) async {
    await db.customUpdate('DELETE FROM chat_logs WHERE profile_id = ?', variables: [_i(profileId)]);
  }
}

class ModelRepo extends _Repo {
  const ModelRepo(super.db);

  Future<ModelInstall?> byId(String packId) async {
    final row = await db.customSelect(
      'SELECT * FROM model_installs WHERE pack_id = ?',
      variables: [_s(packId)],
    ).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return ModelInstall(
      packId: _str(row, 'pack_id'),
      directory: _str(row, 'directory'),
      bytes: _int(row, 'bytes'),
      sha256: _str(row, 'sha256'),
      checksumVerified: _bool(row, 'checksum_verified'),
      source: _str(row, 'source'),
    );
  }

  Future<void> upsert({
    required String packId,
    required String directory,
    required int bytes,
    required String sha256,
    required bool checksumVerified,
    required String source,
  }) async {
    await db.customInsert(
      'INSERT OR REPLACE INTO model_installs '
      '(pack_id, directory, bytes, sha256, checksum_verified, source, installed_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
      variables: [
        _s(packId),
        _s(directory),
        _i(bytes),
        _s(sha256),
        _i(checksumVerified ? 1 : 0),
        _s(source),
        _i(_ms(DateTime.now())),
      ],
    );
  }

  Future<void> remove(String packId) async {
    await db.customUpdate('DELETE FROM model_installs WHERE pack_id = ?', variables: [_s(packId)]);
  }
}

class RewardRepo extends _Repo {
  const RewardRepo(super.db);

  Future<void> add(int profileId, String stickerId) async {
    await db.customInsert(
      'INSERT INTO rewards (profile_id, sticker_id, earned_at) VALUES (?, ?, ?)',
      variables: [_i(profileId), _s(stickerId), _i(_ms(DateTime.now()))],
    );
  }

  Future<List<Reward>> forProfile(int profileId) async {
    final rows = await db.customSelect(
      'SELECT sticker_id, earned_at FROM rewards WHERE profile_id = ? ORDER BY earned_at',
      variables: [_i(profileId)],
    ).get();
    return [
      for (final row in rows)
        Reward(stickerId: _str(row, 'sticker_id'), earnedAt: _time(_int(row, 'earned_at'))),
    ];
  }
}
