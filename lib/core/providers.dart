// lib/core/providers.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../curriculum/curriculum_loader.dart';
import '../curriculum/models.dart';
import '../curriculum/progress_service.dart';
import 'config/app_config.dart';
import 'db/app_database.dart';
import 'db/repositories.dart';
import 'services/audio_cache.dart';
import 'services/backup_service.dart';
import 'services/content_filter.dart';
import 'services/device_profile.dart';
import 'services/ink_service.dart';
import 'services/llm_service.dart';
import 'services/model_catalog.dart';
import 'services/model_downloader.dart';
import 'services/native_guard.dart';
import 'services/parent_settings.dart';
import 'services/platform_bridge.dart';
import 'services/recording_janitor.dart';
import 'services/sherpa_worker.dart';
import 'services/speech_output.dart';
import 'services/stt_service.dart';
import 'services/study_clock.dart';
import 'services/tts_en_service.dart';
import 'services/tts_vi_service.dart';

/// Directories resolved once at startup.
class AppPaths {
  const AppPaths({
    required this.modelsRoot,
    required this.audioCacheRoot,
    required this.recordingsRoot,
    required this.guardRoot,
  });

  final String modelsRoot;
  final String audioCacheRoot;
  final String recordingsRoot;

  /// Crash-guard markers (see NativeGuard).
  final String guardRoot;

  static Future<AppPaths> resolve() async {
    final support = await getApplicationSupportDirectory();
    final paths = AppPaths(
      modelsRoot: p.join(support.path, 'models'),
      audioCacheRoot: p.join(support.path, 'audio_cache'),
      recordingsRoot: p.join(support.path, 'recordings'),
      guardRoot: p.join(support.path, 'native_guard'),
    );
    await Directory(paths.modelsRoot).create(recursive: true);
    await Directory(paths.recordingsRoot).create(recursive: true);
    return paths;
  }
}

/// Which optional engines are usable right now.
class Capabilities {
  const Capabilities({
    required this.speech,
    required this.ink,
    required this.llm,
    required this.englishVoice,
  });

  /// Silero VAD + Whisper installed (speaking activities are scored).
  final bool speech;

  /// ML Kit handwriting model downloaded.
  final bool ink;

  /// Gemma installed ("Talk with Bi").
  final bool llm;

  /// Kokoro or the Piper fallback installed.
  final bool englishVoice;
}

/// Everything the UI needs, built once in main() before the first frame.
class AppServices {
  AppServices({
    required this.paths,
    required this.db,
    required this.profile,
    required this.downloader,
    required this.stt,
    required this.ttsEn,
    required this.ttsVi,
    required this.audioCache,
    required this.speech,
    required this.llm,
    required this.ink,
    required this.settingsStore,
    required this.janitor,
    required this.files,
    required this.reminders,
    required this.curriculum,
    required this.progress,
    required this.studyClock,
    required this.backup,
    required this.guard,
    this.switchedOffNow = const <String>{},
  });

  final AppPaths paths;
  final AppDatabase db;
  final DeviceProfile profile;
  final ModelDownloader downloader;
  final SttService stt;
  final TtsEnService ttsEn;
  final TtsViService ttsVi;
  final AudioCache audioCache;
  final SpeechOutput speech;
  final LlmService llm;
  final InkService ink;
  final ParentSettingsStore settingsStore;
  final RecordingJanitor janitor;
  final FilesPlatform files;
  final ReminderPlatform reminders;
  final Curriculum curriculum;
  final ProgressService progress;
  final StudyClock studyClock;
  final BackupService backup;

  /// Native engines switched off after a crash (see NativeGuard).
  final NativeGuard guard;

  /// Engines switched off at this start, for the parent notice.
  final Set<String> switchedOffNow;

  final ContentFilter contentFilter = const ContentFilter();

  final ValueNotifier<Capabilities> capabilities = ValueNotifier<Capabilities>(
    const Capabilities(speech: false, ink: false, llm: false, englishVoice: false),
  );

  /// [previousNativeCrash]: the last run ended in a native crash, so the
  /// engine that was busy at that moment is switched off (NativeGuard).
  static Future<AppServices> create({bool previousNativeCrash = false}) async {
    final paths = await AppPaths.resolve();
    final db = AppDatabase();
    final devicePlatform = DevicePlatform();
    final filesPlatform = FilesPlatform();
    final rawDeviceInfo = await devicePlatform.getDeviceInfo();
    final profile = DeviceProfile.select(DeviceInfo.fromMap(rawDeviceInfo));
    final curriculum = await CurriculumLoader.load();

    final guard = NativeGuard(paths.guardRoot);
    final switchedOff = await guard.start(
      build: '${rawDeviceInfo['appVersionCode'] ?? ''}',
      nativeCrash: previousNativeCrash,
    );

    // Worker isolates start lazily, on the first speech call.
    final sttWorker = SherpaWorker('ongbi-stt', guard: guard, guardEngine: NativeGuard.stt);
    final ttsWorker = SherpaWorker('ongbi-tts', guard: guard, guardEngine: NativeGuard.tts);

    final ttsEn = TtsEnService(worker: ttsWorker, modelsRoot: paths.modelsRoot, threads: profile.ttsThreads);
    final ttsVi = TtsViService(worker: ttsWorker, modelsRoot: paths.modelsRoot, threads: profile.ttsThreads);
    final audioCache = AudioCache(
      cacheRoot: paths.audioCacheRoot,
      mediaRepo: db.mediaRepo,
      ttsEn: ttsEn,
      ttsVi: ttsVi,
    );

    final services = AppServices(
      paths: paths,
      db: db,
      profile: profile,
      downloader: ModelDownloader(
        modelsRoot: paths.modelsRoot,
        modelRepo: db.modelRepo,
        device: devicePlatform,
        files: filesPlatform,
      ),
      stt: SttService(worker: sttWorker, modelsRoot: paths.modelsRoot),
      ttsEn: ttsEn,
      ttsVi: ttsVi,
      audioCache: audioCache,
      speech: SpeechOutput(cache: audioCache, ttsVi: ttsVi),
      llm: LlmService(guard: guard),
      ink: InkService(guard: guard),
      settingsStore: ParentSettingsStore(db.settingsRepo),
      janitor: RecordingJanitor(db.mediaRepo),
      files: filesPlatform,
      reminders: ReminderPlatform(),
      curriculum: curriculum,
      progress: ProgressService(db: db, curriculum: curriculum),
      studyClock: StudyClock(db.studyRepo),
      backup: BackupService(db: db, files: filesPlatform),
      guard: guard,
      switchedOffNow: switchedOff,
    );
    await services.refreshCapabilities();
    return services;
  }

  /// Re-checks installed models (after setup, downloads or deletions).
  Future<void> refreshCapabilities() async {
    final whisper = ModelCatalog.whisperFor(profile);
    // An engine switched off by the crash guard counts as unavailable, so
    // the lessons use their built-in fallbacks instead of crashing again.
    final speechReady = !guard.isDisabled(NativeGuard.stt) &&
        await downloader.isInstalled(ModelCatalog.vad) &&
        await downloader.isInstalled(whisper);
    var inkReady = false;
    try {
      inkReady = !guard.isDisabled(NativeGuard.ink) && await ink.isModelReady();
    } catch (_) {
      inkReady = false;
    }
    final gemma = ModelCatalog.gemmaFor(profile);
    final llmReady =
        gemma != null && !guard.isDisabled(NativeGuard.llm) && await downloader.isInstalled(gemma);
    capabilities.value = Capabilities(
      speech: speechReady,
      ink: inkReady,
      llm: llmReady,
      englishVoice: await ttsEn.available,
    );
  }

  /// Absolute path of the installed Gemma file, or null.
  String? gemmaPath() {
    final gemma = ModelCatalog.gemmaFor(profile);
    if (gemma == null) {
      return null;
    }
    return p.join(downloader.packDir(gemma), gemma.fileName);
  }

  /// Where the child's recording for [itemId] goes.
  String recordingPath(int profileId) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return p.join(paths.recordingsRoot, 'p${profileId}_$stamp.wav');
  }
}

/// Overridden in main() with the instance built at startup.
final appServicesProvider = Provider<AppServices>((ref) {
  throw UnimplementedError('appServicesProvider must be overridden in main()');
});

/// Parent settings, loaded once and updated only from the parent area.
class ParentSettingsNotifier extends Notifier<ParentSettings> {
  ParentSettingsNotifier(this._initial);

  final ParentSettings _initial;

  @override
  ParentSettings build() => _initial;

  Future<void> change(ParentSettings Function(ParentSettings current) edit) async {
    final next = edit(state);
    state = next;
    await ref.read(appServicesProvider).settingsStore.save(next);
  }

  /// Re-reads settings from the database (after restoring a backup).
  Future<void> reload() async {
    state = await ref.read(appServicesProvider).settingsStore.load();
  }
}

/// Overridden in main() with the settings read from the database.
final parentSettingsProvider = NotifierProvider<ParentSettingsNotifier, ParentSettings>(() {
  throw UnimplementedError('parentSettingsProvider must be overridden in main()');
});

/// The active child profile. Invalidate after changing profiles or progress.
final activeProfileProvider = FutureProvider<Profile>((ref) async {
  final services = ref.watch(appServicesProvider);
  final settings = ref.watch(parentSettingsProvider);
  final repo = services.db.profileRepo;
  final profile = await repo.byId(settings.activeProfileId);
  if (profile != null) {
    return profile;
  }
  final all = await repo.all();
  if (all.isNotEmpty) {
    return all.first;
  }
  final id = await repo.create(AppConfig.defaultProfileName);
  return (await repo.byId(id ?? 1))!;
});

/// Reading speed chosen with the turtle / rabbit button for this session.
class SlowModeNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(parentSettingsProvider).slowSpeech;

  void toggle() => state = !state;
}

final slowModeProvider = NotifierProvider<SlowModeNotifier, bool>(SlowModeNotifier.new);

/// True while written English must stay hidden (grade-1 reading delay).
final hideEnglishTextProvider = Provider<bool>((ref) {
  return ref.watch(parentSettingsProvider).delayEnglishReading;
});
