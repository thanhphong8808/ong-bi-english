// lib/main.dart
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'app/router.dart';
import 'core/providers.dart';
import 'core/services/model_catalog.dart';
import 'l10n/strings_vi.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);

  final services = await AppServices.create();
  final settings = await services.settingsStore.load();

  // The core lessons need every required pack. Gemma is optional by design:
  // deleting it must never block anything except "Talk with Bi".
  final required = ModelCatalog.packsFor(services.profile).where((pack) => !pack.optional);
  final ready = settings.setupDone && await services.downloader.allInstalled(required);

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
      ),
    ),
  );
}
