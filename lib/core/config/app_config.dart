// lib/core/config/app_config.dart
//
// Single source of truth for every tunable threshold, duration and limit.
// Nothing else in the code base may hard-code these numbers.

/// How strict pronunciation scoring is. Parents can change it.
enum SpeechDifficulty { easy, medium, strict }

/// How much Vietnamese Bi uses in "Talk with Bi". Parents can change it.
enum VietnameseSupport { low, normal, high }

class AppConfig {
  const AppConfig._();

  // ---- App identity -------------------------------------------------------
  static const String appName = 'Ong Bi English';
  static const String databaseName = 'ong_bi_english';
  static const String defaultProfileName = 'Bé';
  static const int maxProfiles = 3;
  static const int levelCount = 6;

  // ---- Session and daily limits -------------------------------------------
  static const int defaultSessionMinutes = 12;
  static const int defaultDailyLimitMinutes = 20;
  static const int minDailyLimitMinutes = 5;
  static const int maxDailyLimitMinutes = 60;
  static const int defaultStudyStartHour = 6;
  static const int defaultStudyEndHour = 21;
  static const int studyTickSeconds = 15;

  /// Steps per lesson block, by level:
  /// [warm-up, review, new items (max), speaking, writing, reading].
  /// Low levels lean on listening and speaking; high levels add reading
  /// and writing. About 20-24 steps fill the 12-minute session.
  static const List<List<int>> lessonMix = [
    [3, 5, 4, 2, 1, 0],
    [3, 5, 4, 2, 2, 1],
    [3, 6, 5, 2, 2, 2],
    [2, 6, 5, 2, 3, 2],
    [2, 6, 5, 2, 3, 3],
    [2, 6, 5, 2, 3, 3],
  ];
  static const int maxAttemptsPerItem = 2;

  // ---- Playback -------------------------------------------------------------
  static const double slowSpeechRate = 0.7;
  static const double normalSpeechRate = 1.0;

  // ---- Leitner spaced repetition --------------------------------------------
  /// Days until the next review for boxes 1..7.
  static const List<int> leitnerIntervalsDays = [0, 1, 2, 4, 7, 14, 30];

  /// A skill counts as passed from this box (three spaced correct answers).
  static const int leitnerMasteredBox = 4;
  static const int firstLevelRequiringWriting = 2;

  // ---- Pronunciation scoring ------------------------------------------------
  static const SpeechDifficulty defaultSpeechDifficulty = SpeechDifficulty.easy;

  /// Minimum similarity (0..1) for 1, 2 and 3 stars per difficulty.
  static const Map<SpeechDifficulty, List<double>> speechStarThresholds = {
    SpeechDifficulty.easy: [0.45, 0.65, 0.85],
    SpeechDifficulty.medium: [0.60, 0.78, 0.92],
    SpeechDifficulty.strict: [0.75, 0.88, 0.97],
  };
  static const int speechScoringBudgetMs = 2000;

  /// Speech shorter than this is treated as silence in open answers.
  static const int minAnswerSpeechMs = 350;

  // ---- Speech capture (VAD) ---------------------------------------------------
  static const int sttSampleRate = 16000;
  static const double vadThreshold = 0.40;

  /// Children pause mid-phrase, so the trailing silence is generous.
  static const double vadMinSilenceSeconds = 0.8;
  static const double vadMinSpeechSeconds = 0.15;
  static const double vadMaxSpeechSeconds = 15.0;
  static const int vadWindowSize = 512;
  static const int listenTimeoutSeconds = 8;
  static const int listenTimeoutSentenceSeconds = 14;

  // ---- Handwriting ------------------------------------------------------------
  /// Tracing passes when at least 75 % of the letter path is covered.
  static const double traceCoverageMin = 0.75;
  static const double traceNearlyCoverage = 0.55;

  /// Distances are in "bands" (one band = space between two guide lines).
  static const double traceHitRadiusBands = 0.32;
  static const double traceMaxDeviationBands = 0.55;
  static const int typingAllowedFromLevel = 4;

  /// Minimum words for guided writing, by level (levels 0-2 do not use it).
  static const List<int> guidedWritingMinWords = [0, 0, 0, 15, 40, 80];

  // ---- Tests --------------------------------------------------------------------
  static const double unitTestPassRatio = 0.80;
  static const int unitTestMinQuestions = 8;
  static const int unitTestMaxQuestions = 12;
  static const int unitRetakeDelayDays = 1;
  static const double levelTestPassRatio = 0.75;
  static const double levelTestSectionFloor = 0.60;
  static const int levelTestPerSection = 6;
  static const int levelTestWritingQuestions = 4;

  /// After a failed level test: review-only lessons for this many days.
  static const int levelReviewDays = 7;
  static const int placementTestMinutes = 5;
  static const int placementPerLevel = 6;
  static const double placementLevel0Pass = 0.80;
  static const double placementLevel1Pass = 0.65;
  static const int weeklyReviewMinutes = 5;
  static const int quizBankMinPerUnit = 30;

  // ---- Rewards ------------------------------------------------------------------
  static const int starsPerActivity = 1;
  static const int starsLessonBonus = 3;

  // ---- Talk with Bi (LLM) ---------------------------------------------------------
  static const int biMaxSentencesPerTurn = 2;
  static const int biMaxWordsPerSentenceLow = 8; // levels 0-1
  static const int biMaxWordsPerSentenceHigh = 16;
  static const int biMaxNewWordsPerTurn = 1;
  static const int biSilentTurnsBeforeHint = 2;
  static const int biSessionMinutesLow = 5; // levels 0-1
  static const int biSessionMinutesHigh = 10;
  static const int biMaxReplyChars = 240;
  static const int biFirstTokenBudgetMs = 2000;
  static const int biPromptKnownWordsMax = 150;

  /// More unknown words than this in a reply and Bi falls back to a simple,
  /// safe template sentence made of known words.
  static const List<int> biUnknownWordsTolerance = [3, 3, 4, 5, 6, 8];
  static const int biHintButtons = 3;
  static const int biReplyTimeoutSeconds = 25;

  // ---- Device profile ---------------------------------------------------------------
  /// Reported RAM is lower than the marketing figure (a "12 GB" phone reports
  /// about 11.2 GB), so thresholds leave headroom.
  static const int ramMbForGemmaE4b = 9500; // "10 GB or more"
  static const int ramMbForGemmaE2b = 5200; // "6 GB" phones
  static const int ramMbForWhisperBase = 5200;
  static const int minInferenceThreads = 2;
  static const int maxInferenceThreads = 4;

  // ---- Model download -----------------------------------------------------------------
  static const int downloadMaxRetries = 8;
  static const int downloadRetryBaseSeconds = 2;
  static const int downloadConnectTimeoutSeconds = 30;
  static const int downloadIdleTimeoutSeconds = 60;
  static const int freeSpaceSafetyMarginMb = 500;

  // ---- Audio cache and recordings --------------------------------------------------------
  static const int audioPrewarmLessons = 3;
  static const int defaultRecordingRetentionDays = 7;
  static const int minRecordingRetentionDays = 0;
  static const int maxRecordingRetentionDays = 30;

  // ---- Parent gate -------------------------------------------------------------------------
  static const int gateFactorMin = 6;
  static const int gateFactorMax = 9;
  static const int gatePinLength = 4;
  static const int gateMaxAttempts = 3;
  static const int gateLockoutSeconds = 30;

  // ---- English reading delay for grade-1 pupils -------------------------------------------------
  static const int delayEnglishReadingDefaultDays = 90;

  // ---- Reminders ------------------------------------------------------------------------------------
  static const int defaultReminderHour = 18;
  static const int defaultReminderMinute = 30;

  // ---- Kid UI ---------------------------------------------------------------------------------------
  static const double giantButtonMinSize = 120;
  static const double kidTouchTargetMin = 64;
  static const int startupBudgetMs = 3000;

  /// Colours used by "colour by command" activities (English words).
  static const List<String> colorWords = ['red', 'blue', 'green', 'yellow', 'pink', 'orange'];
}
