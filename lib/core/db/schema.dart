// lib/core/db/schema.dart
//
// SQL schema, versioned. The database is written with drift's raw-SQL API
// (no code generation), so the schema lives here as plain statements.

class DbSchema {
  const DbSchema._();

  static const int version = 2;

  /// Statements that create schema version 1.
  static const List<String> createV1 = [
    '''
    CREATE TABLE profiles (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      level INTEGER NOT NULL DEFAULT 0,
      unit_index INTEGER NOT NULL DEFAULT 0,
      stars INTEGER NOT NULL DEFAULT 0,
      placement_done INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL
    )''',
    '''
    CREATE TABLE settings (
      profile_id INTEGER NOT NULL DEFAULT 0,
      setting_key TEXT NOT NULL,
      setting_value TEXT NOT NULL,
      PRIMARY KEY (profile_id, setting_key)
    )''',
    '''
    CREATE TABLE item_progress (
      profile_id INTEGER NOT NULL,
      item_id TEXT NOT NULL,
      unit_id TEXT NOT NULL,
      skill TEXT NOT NULL,
      box INTEGER NOT NULL DEFAULT 1,
      due_at INTEGER NOT NULL,
      correct_count INTEGER NOT NULL DEFAULT 0,
      wrong_count INTEGER NOT NULL DEFAULT 0,
      last_seen_at INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (profile_id, item_id, skill)
    )''',
    'CREATE INDEX idx_progress_due ON item_progress (profile_id, due_at)',
    'CREATE INDEX idx_progress_unit ON item_progress (profile_id, unit_id)',
    '''
    CREATE TABLE attempts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      profile_id INTEGER NOT NULL,
      item_id TEXT NOT NULL,
      skill TEXT NOT NULL,
      correct INTEGER NOT NULL,
      score REAL NOT NULL DEFAULT 0,
      at INTEGER NOT NULL
    )''',
    'CREATE INDEX idx_attempts_time ON attempts (profile_id, at)',
    '''
    CREATE TABLE unit_progress (
      profile_id INTEGER NOT NULL,
      unit_id TEXT NOT NULL,
      lessons_done INTEGER NOT NULL DEFAULT 0,
      review_done INTEGER NOT NULL DEFAULT 0,
      passed INTEGER NOT NULL DEFAULT 0,
      best_score REAL NOT NULL DEFAULT 0,
      last_test_at INTEGER NOT NULL DEFAULT 0,
      remedial_pending INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (profile_id, unit_id)
    )''',
    '''
    CREATE TABLE dialogue_progress (
      profile_id INTEGER NOT NULL,
      dialogue_id TEXT NOT NULL,
      stage INTEGER NOT NULL DEFAULT 0,
      last_at INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (profile_id, dialogue_id)
    )''',
    '''
    CREATE TABLE study_days (
      profile_id INTEGER NOT NULL,
      day TEXT NOT NULL,
      seconds INTEGER NOT NULL DEFAULT 0,
      lessons_done INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (profile_id, day)
    )''',
    '''
    CREATE TABLE test_results (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      profile_id INTEGER NOT NULL,
      kind TEXT NOT NULL,
      target_id TEXT NOT NULL,
      score REAL NOT NULL,
      passed INTEGER NOT NULL,
      detail_json TEXT NOT NULL DEFAULT '{}',
      taken_at INTEGER NOT NULL
    )''',
    '''
    CREATE TABLE audio_cache (
      cache_key TEXT PRIMARY KEY,
      file_path TEXT NOT NULL,
      engine TEXT NOT NULL,
      bytes INTEGER NOT NULL,
      created_at INTEGER NOT NULL
    )''',
    '''
    CREATE TABLE recordings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      profile_id INTEGER NOT NULL,
      item_id TEXT NOT NULL DEFAULT '',
      file_path TEXT NOT NULL,
      created_at INTEGER NOT NULL
    )''',
    '''
    CREATE TABLE chat_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      profile_id INTEGER NOT NULL,
      session_id TEXT NOT NULL,
      role TEXT NOT NULL,
      content TEXT NOT NULL,
      flagged INTEGER NOT NULL DEFAULT 0,
      flag_reason TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL
    )''',
    '''
    CREATE TABLE model_installs (
      pack_id TEXT PRIMARY KEY,
      directory TEXT NOT NULL,
      bytes INTEGER NOT NULL,
      sha256 TEXT NOT NULL DEFAULT '',
      checksum_verified INTEGER NOT NULL DEFAULT 0,
      source TEXT NOT NULL DEFAULT 'download',
      installed_at INTEGER NOT NULL
    )''',
    '''
    CREATE TABLE rewards (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      profile_id INTEGER NOT NULL,
      sticker_id TEXT NOT NULL,
      earned_at INTEGER NOT NULL
    )''',
  ];

  /// Upgrade steps keyed by the version they upgrade FROM.
  /// Example for a future v2: `1: ['ALTER TABLE profiles ADD COLUMN avatar INTEGER NOT NULL DEFAULT 0']`.
  static const Map<int, List<String>> upgrades = <int, List<String>>{
    // v2 (build 12): builds before 10 counted time the phone slept on an
    // open lesson as study time, so Bi wrongly "went to sleep". Today's
    // count starts again; older days are capped at the largest daily limit.
    1: [
      "UPDATE study_days SET seconds = 0 WHERE day = date('now', 'localtime')",
      'UPDATE study_days SET seconds = 3600 WHERE seconds > 3600',
    ],
  };

  /// Tables included in backups, in restore order.
  static const List<String> backupTables = [
    'profiles',
    'settings',
    'item_progress',
    'attempts',
    'unit_progress',
    'dialogue_progress',
    'study_days',
    'test_results',
    'chat_logs',
    'rewards',
  ];
}
