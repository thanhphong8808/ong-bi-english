// lib/main.dart
import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'app/router.dart';
import 'app/startup_error_app.dart';
import 'core/providers.dart';
import 'core/services/crash_report.dart';
import 'core/services/model_catalog.dart';
import 'core/services/parent_settings.dart';
import 'l10n/strings_vi.dart';

const CrashReportPlatform _crash = CrashReportPlatform();

Future<void> main() async {
  runZonedGuarded(_start, (error, stack) {
    unawaited(_crash.recordError(error, stack, context: 'zone'));
  });
}

Future<void> _start() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Every Dart error is kept for the report shown on the next start.
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    unawaited(_crash.recordError(details.exception, details.stack, context: 'flutter'));
    previousOnError?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(_crash.recordError(error, stack, context: 'platform'));
    return true;
  };

  try {
    await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
  } catch (_) {
    // Orientation lock is a nicety; never block start-up on it.
  }

  final CrashReport? lastCrash = await _crash.takePendingReport();

  final AppServices services;
  final ParentSettings settings;
  final bool ready;
  try {
    // After a native crash, the engine that was busy is switched off so the
    // child is not stuck in a crash loop (see NativeGuard).
    services = await AppServices.create(
      previousNativeCrash: lastCrash?.text.contains('CRASH_NATIVE') ?? false,
    );
    settings = await services.settingsStore.load();
    // The core lessons need every required pack. Gemma is optional by design:
    // deleting it must never block anything except "Talk with Bi".
    final required = ModelCatalog.packsFor(services.profile).where((pack) => !pack.optional);
    ready = settings.setupDone && await services.downloader.allInstalled(required);
  } catch (error, stack) {
    // Show what went wrong instead of a frozen splash screen.
    await _crash.recordError(error, stack, context: 'start-up');
    final report = await _crash.takePendingReport(force: true);
    runApp(StartupErrorApp(error: error, stack: stack, savedTo: report?.savedTo ?? ''));
    return;
  }

  // Study time counts only while the app is on screen. The listener
  // registers itself with the binding and lives for the whole run.
  AppLifecycleListener(
    onPause: services.studyClock.pause,
    onResume: services.studyClock.resume,
  );

  // Privacy: purge the child's old recordings without delaying the first frame.
  unawaited(
    services.janitor.purge(retentionDays: settings.recordingRetentionDays).catchError((Object _) => 0),
  );
  // Re-arm the daily reminder (alarms are lost when the app is updated).
  if (settings.reminderEnabled) {
    unawaited(services.reminders
        .schedule(
          hour: settings.reminderHour,
          minute: settings.reminderMinute,
          title: S.reminderTitle,
          body: S.reminderBody,
        )
        .catchError((Object _) {}));
  }

  runApp(
    ProviderScope(
      overrides: [
        appServicesProvider.overrideWithValue(services),
        parentSettingsProvider.overrideWith(() => ParentSettingsNotifier(settings)),
      ],
      child: OngBiApp(
        router: buildRouter(initialLocation: ready ? AppRoutes.home : AppRoutes.setup),
        lastCrash: lastCrash,
        switchedOff: services.switchedOffNow,
      ),
    ),
  );
}
