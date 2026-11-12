// lib/core/services/parent_settings.dart
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../config/app_config.dart';
import '../db/repositories.dart';
import 'english_voice.dart';

/// Everything a parent can change. Only the parent area writes these.
class ParentSettings {
  const ParentSettings({
    this.dailyLimitMinutes = AppConfig.defaultDailyLimitMinutes,
    this.sessionMinutes = AppConfig.defaultSessionMinutes,
    this.studyStartHour = AppConfig.defaultStudyStartHour,
    this.studyEndHour = AppConfig.defaultStudyEndHour,
    this.voice = EnglishVoice.usFemale,
    this.slowSpeech = false,
    this.speechDifficulty = AppConfig.defaultSpeechDifficulty,
    this.talkWithBiEnabled = true,
    this.delayEnglishReading = false,
    this.recordingRetentionDays = AppConfig.defaultRecordingRetentionDays,
    this.pinHash = '',
    this.setupDone = false,
    this.activeProfileId = 1,
    this.installedAtMs = 0,
    this.vietnameseSupport = VietnameseSupport.normal,
    this.reminderEnabled = false,
    this.reminderHour = AppConfig.defaultReminderHour,
    this.reminderMinute = AppConfig.defaultReminderMinute,
    this.delayReadingTouched = false,
    this.showIpa = true,
  });

  final int dailyLimitMinutes;
  final int sessionMinutes;
  final int studyStartHour;
  final int studyEndHour;
  final EnglishVoice voice;
  final bool slowSpeech;
  final SpeechDifficulty speechDifficulty;
  final bool talkWithBiEnabled;
  final bool delayEnglishReading;
  final int recordingRetentionDays;

  /// SHA-256 of the 4-digit parent PIN; empty when the multiplication gate is used.
  final String pinHash;
  final bool setupDone;
  final int activeProfileId;
  final int installedAtMs;
  final VietnameseSupport vietnameseSupport;
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;

  /// True once a parent changed "delay English reading" by hand; until then
  /// the app switches it off automatically after the first three months.
  final bool delayReadingTouched;

  /// Pronunciation (IPA) under English words and sentences.
  final bool showIpa;

  bool get hasPin => pinHash.isNotEmpty;

  double get speechRate => slowSpeech ? AppConfig.slowSpeechRate : AppConfig.normalSpeechRate;

  static String hashPin(String pin) => sha256.convert(utf8.encode('ongbi:$pin')).toString();

  ParentSettings copyWith({
    int? dailyLimitMinutes,
    int? sessionMinutes,
    int? studyStartHour,
    int? studyEndHour,
    EnglishVoice? voice,
    bool? slowSpeech,
    SpeechDifficulty? speechDifficulty,
    bool? talkWithBiEnabled,
    bool? delayEnglishReading,
    int? recordingRetentionDays,
    String? pinHash,
    bool? setupDone,
    int? activeProfileId,
    int? installedAtMs,
    VietnameseSupport? vietnameseSupport,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    bool? delayReadingTouched,
    bool? showIpa,
  }) {
    return ParentSettings(
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      sessionMinutes: sessionMinutes ?? this.sessionMinutes,
      studyStartHour: studyStartHour ?? this.studyStartHour,
      studyEndHour: studyEndHour ?? this.studyEndHour,
      voice: voice ?? this.voice,
      slowSpeech: slowSpeech ?? this.slowSpeech,
      speechDifficulty: speechDifficulty ?? this.speechDifficulty,
      talkWithBiEnabled: talkWithBiEnabled ?? this.talkWithBiEnabled,
      delayEnglishReading: delayEnglishReading ?? this.delayEnglishReading,
      recordingRetentionDays: recordingRetentionDays ?? this.recordingRetentionDays,
      pinHash: pinHash ?? this.pinHash,
      setupDone: setupDone ?? this.setupDone,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      installedAtMs: installedAtMs ?? this.installedAtMs,
      vietnameseSupport: vietnameseSupport ?? this.vietnameseSupport,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      delayReadingTouched: delayReadingTouched ?? this.delayReadingTouched,
      showIpa: showIpa ?? this.showIpa,
    );
  }

  Map<String, String> toMap() {
    return {
      'dailyLimitMinutes': '$dailyLimitMinutes',
      'sessionMinutes': '$sessionMinutes',
      'studyStartHour': '$studyStartHour',
      'studyEndHour': '$studyEndHour',
      'voice': voice.name,
      'slowSpeech': '$slowSpeech',
      'speechDifficulty': speechDifficulty.name,
      'talkWithBiEnabled': '$talkWithBiEnabled',
      'delayEnglishReading': '$delayEnglishReading',
      'recordingRetentionDays': '$recordingRetentionDays',
      'pinHash': pinHash,
      'setupDone': '$setupDone',
      'activeProfileId': '$activeProfileId',
      'installedAtMs': '$installedAtMs',
      'vietnameseSupport': vietnameseSupport.name,
      'reminderEnabled': '$reminderEnabled',
      'reminderHour': '$reminderHour',
      'reminderMinute': '$reminderMinute',
      'delayReadingTouched': '$delayReadingTouched',
      'showIpa': '$showIpa',
    };
  }

  factory ParentSettings.fromMap(Map<String, String> map) {
    const d = ParentSettings();
    int readInt(String key, int fallback) => int.tryParse(map[key] ?? '') ?? fallback;
    bool readBool(String key, bool fallback) {
      final raw = map[key];
      return raw == null ? fallback : raw == 'true';
    }

    T readEnum<T extends Enum>(String key, List<T> values, T fallback) {
      final raw = map[key];
      for (final value in values) {
        if (value.name == raw) {
          return value;
        }
      }
      return fallback;
    }

    return ParentSettings(
      dailyLimitMinutes: readInt('dailyLimitMinutes', d.dailyLimitMinutes)
          .clamp(AppConfig.minDailyLimitMinutes, AppConfig.maxDailyLimitMinutes)
          .toInt(),
      sessionMinutes: readInt('sessionMinutes', d.sessionMinutes),
      studyStartHour: readInt('studyStartHour', d.studyStartHour).clamp(0, 23).toInt(),
      studyEndHour: readInt('studyEndHour', d.studyEndHour).clamp(1, 24).toInt(),
      voice: readEnum('voice', EnglishVoice.values, d.voice),
      slowSpeech: readBool('slowSpeech', d.slowSpeech),
      speechDifficulty: readEnum('speechDifficulty', SpeechDifficulty.values, d.speechDifficulty),
      talkWithBiEnabled: readBool('talkWithBiEnabled', d.talkWithBiEnabled),
      delayEnglishReading: readBool('delayEnglishReading', d.delayEnglishReading),
      recordingRetentionDays: readInt('recordingRetentionDays', d.recordingRetentionDays)
          .clamp(AppConfig.minRecordingRetentionDays, AppConfig.maxRecordingRetentionDays)
          .toInt(),
      pinHash: map['pinHash'] ?? '',
      setupDone: readBool('setupDone', d.setupDone),
      activeProfileId: readInt('activeProfileId', d.activeProfileId),
      installedAtMs: readInt('installedAtMs', d.installedAtMs),
      vietnameseSupport: readEnum('vietnameseSupport', VietnameseSupport.values, d.vietnameseSupport),
      reminderEnabled: readBool('reminderEnabled', d.reminderEnabled),
      reminderHour: readInt('reminderHour', d.reminderHour).clamp(0, 23).toInt(),
      reminderMinute: readInt('reminderMinute', d.reminderMinute).clamp(0, 59).toInt(),
      delayReadingTouched: readBool('delayReadingTouched', d.delayReadingTouched),
      showIpa: readBool('showIpa', d.showIpa),
    );
  }
}

/// Loads and saves [ParentSettings] in the settings table.
class ParentSettingsStore {
  ParentSettingsStore(this.repo);

  final SettingsRepo repo;

  Future<ParentSettings> load({DateTime? now}) async {
    final time = now ?? DateTime.now();
    final map = await repo.readAll();
    var settings = ParentSettings.fromMap(map);
    var changed = false;
    if (settings.installedAtMs == 0) {
      settings = settings.copyWith(installedAtMs: time.millisecondsSinceEpoch);
      changed = true;
    }
    // English text is shown from the start, so the child sees the words Bi
    // says. Builds before 17 hid it for three months: switch that off unless
    // a parent turned it on by hand.
    if (settings.delayEnglishReading && !settings.delayReadingTouched) {
      settings = settings.copyWith(delayEnglishReading: false);
      changed = true;
    }
    if (changed) {
      await save(settings);
    }
    return settings;
  }

  Future<void> save(ParentSettings settings) => repo.writeAll(settings.toMap());
}
