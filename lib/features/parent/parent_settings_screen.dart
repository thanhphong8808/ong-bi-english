// lib/features/parent/parent_settings_screen.dart
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/providers.dart';
import '../../core/services/parent_gate.dart';
import '../../core/services/parent_settings.dart';
import '../../core/services/english_voice.dart';
import '../../l10n/strings_vi.dart';
import '../../core/services/study_clock.dart';

/// The only place where learning settings can be changed.
class ParentSettingsScreen extends ConsumerWidget {
  const ParentSettingsScreen({super.key});

  static String _voiceLabel(EnglishVoice voice) {
    switch (voice) {
      case EnglishVoice.usFemale:
        return S.voiceUsFemale;
      case EnglishVoice.usMale:
        return S.voiceUsMale;
      case EnglishVoice.ukFemale:
        return S.voiceUkFemale;
      case EnglishVoice.ukMale:
        return S.voiceUkMale;
    }
  }

  static String _difficultyLabel(SpeechDifficulty difficulty) {
    switch (difficulty) {
      case SpeechDifficulty.easy:
        return S.difficultyEasy;
      case SpeechDifficulty.medium:
        return S.difficultyMedium;
      case SpeechDifficulty.strict:
        return S.difficultyStrict;
    }
  }

  Future<void> _setPin(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(S.parentPinSet),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: AppConfig.gatePinLength,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(hintText: S.parentPinHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(S.cancel)),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text(S.save),
          ),
        ],
      ),
    );
    if (pin == null || !context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    if (!PinCheck.isValidFormat(pin)) {
      messenger.showSnackBar(const SnackBar(content: Text(S.parentPinInvalid)));
      return;
    }
    await ref
        .read(parentSettingsProvider.notifier)
        .change((s) => s.copyWith(pinHash: ParentSettings.hashPin(pin)));
    messenger.showSnackBar(const SnackBar(content: Text(S.parentPinSaved)));
  }

  Future<void> _setReminder(BuildContext context, WidgetRef ref, {required bool enabled}) async {
    final services = ref.read(appServicesProvider);
    final notifier = ref.read(parentSettingsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    if (!enabled) {
      await notifier.change((s) => s.copyWith(reminderEnabled: false));
      await services.reminders.cancel();
      return;
    }
    final allowed = await services.reminders.requestPermission();
    if (!allowed) {
      messenger.showSnackBar(const SnackBar(content: Text(S.reminderDenied)));
      return;
    }
    await notifier.change((s) => s.copyWith(reminderEnabled: true));
    final settings = ref.read(parentSettingsProvider);
    await services.reminders.schedule(
      hour: settings.reminderHour,
      minute: settings.reminderMinute,
      title: S.reminderTitle,
      body: S.reminderBody,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(parentSettingsProvider);
    final notifier = ref.read(parentSettingsProvider.notifier);

    Widget sliderRow({
      required String title,
      required int value,
      required int min,
      required int max,
      required void Function(int value) onChanged,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 12),
            child: Text('$title: $value', style: Theme.of(context).textTheme.titleMedium),
          ),
          Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            label: '$value',
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text(S.parentSettings)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            sliderRow(
              title: S.parentDailyLimit,
              value: settings.dailyLimitMinutes,
              min: AppConfig.minDailyLimitMinutes,
              max: AppConfig.maxDailyLimitMinutes,
              onChanged: (v) => notifier.change((s) => s.copyWith(dailyLimitMinutes: v)),
            ),
            _StudiedToday(clock: ref.read(appServicesProvider).studyClock),
            sliderRow(
              title: S.parentSession,
              value: settings.sessionMinutes,
              min: 5,
              max: 20,
              onChanged: (v) => notifier.change((s) => s.copyWith(sessionMinutes: v)),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 12),
              child: Text(
                '${S.parentHours}: ${settings.studyStartHour}h – ${settings.studyEndHour}h',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            RangeSlider(
              values: RangeValues(
                settings.studyStartHour.toDouble(),
                settings.studyEndHour.toDouble(),
              ),
              min: 0,
              max: 24,
              divisions: 24,
              onChanged: (range) {
                final start = range.start.round().clamp(0, 23).toInt();
                final end = range.end.round().clamp(start + 1, 24).toInt();
                notifier.change((s) => s.copyWith(studyStartHour: start, studyEndHour: end));
              },
            ),
            ListTile(
              title: const Text(S.parentVoice),
              trailing: DropdownButton<EnglishVoice>(
                value: settings.voice,
                onChanged: (voice) {
                  if (voice != null) {
                    notifier.change((s) => s.copyWith(voice: voice));
                  }
                },
                items: [
                  for (final voice in EnglishVoice.values)
                    DropdownMenuItem(value: voice, child: Text(_voiceLabel(voice))),
                ],
              ),
            ),
            SwitchListTile(
              title: const Text(S.parentSlow),
              value: settings.slowSpeech,
              onChanged: (v) => notifier.change((s) => s.copyWith(slowSpeech: v)),
            ),
            ListTile(
              title: const Text(S.parentDifficulty),
              trailing: DropdownButton<SpeechDifficulty>(
                value: settings.speechDifficulty,
                onChanged: (difficulty) {
                  if (difficulty != null) {
                    notifier.change((s) => s.copyWith(speechDifficulty: difficulty));
                  }
                },
                items: [
                  for (final difficulty in SpeechDifficulty.values)
                    DropdownMenuItem(value: difficulty, child: Text(_difficultyLabel(difficulty))),
                ],
              ),
            ),
            SwitchListTile(
              title: const Text(S.parentTalk),
              value: settings.talkWithBiEnabled,
              onChanged: (v) => notifier.change((s) => s.copyWith(talkWithBiEnabled: v)),
            ),
            SwitchListTile(
              title: const Text(S.parentDelayReading),
              value: settings.delayEnglishReading,
              onChanged: (v) => notifier.change((s) => s.copyWith(delayEnglishReading: v, delayReadingTouched: true)),
            ),
            ListTile(
              title: const Text(S.parentVietnameseSupport),
              trailing: DropdownButton<VietnameseSupport>(
                value: settings.vietnameseSupport,
                onChanged: (value) {
                  if (value != null) {
                    notifier.change((s) => s.copyWith(vietnameseSupport: value));
                  }
                },
                items: [
                  for (final value in VietnameseSupport.values)
                    DropdownMenuItem(value: value, child: Text(S.vietnameseSupportLabel(value.name))),
                ],
              ),
            ),
            SwitchListTile(
              title: const Text(S.parentReminder),
              subtitle: Text(S.reminderAt(settings.reminderHour, settings.reminderMinute)),
              value: settings.reminderEnabled,
              onChanged: (v) => _setReminder(context, ref, enabled: v),
            ),
            if (settings.reminderEnabled)
              ListTile(
                title: const Text(S.parentReminderTime),
                trailing: const Icon(Icons.schedule_rounded),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: settings.reminderHour, minute: settings.reminderMinute),
                  );
                  if (picked != null && context.mounted) {
                    await notifier.change((s) => s.copyWith(reminderHour: picked.hour, reminderMinute: picked.minute));
                    if (context.mounted) {
                      await _setReminder(context, ref, enabled: true);
                    }
                  }
                },
              ),
            sliderRow(
              title: S.parentRetention,
              value: settings.recordingRetentionDays,
              min: AppConfig.minRecordingRetentionDays,
              max: AppConfig.maxRecordingRetentionDays,
              onChanged: (v) => notifier.change((s) => s.copyWith(recordingRetentionDays: v)),
            ),
            const Divider(),
            ListTile(
              title: const Text(S.parentPin),
              subtitle: Text(settings.hasPin ? S.parentPinClear : S.parentPinSet),
              trailing: const Icon(Icons.lock_outline_rounded),
              onTap: () async {
                if (settings.hasPin) {
                  await notifier.change((s) => s.copyWith(pinHash: ''));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text(S.parentPinCleared)));
                  }
                } else {
                  await _setPin(context, ref);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Today's study minutes, with a button to start the count again.
class _StudiedToday extends StatelessWidget {
  const _StudiedToday({required this.clock});

  final StudyClock clock;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: clock.todaySeconds,
      builder: (context, seconds, _) => ListTile(
        title: Text(S.parentStudiedToday(seconds ~/ 60)),
        subtitle: const Text(S.parentResetTodayHint),
        trailing: TextButton(
          onPressed: seconds == 0
              ? null
              : () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await clock.resetToday();
                  messenger.showSnackBar(const SnackBar(content: Text(S.parentResetTodayDone)));
                },
          child: const Text(S.parentResetToday),
        ),
      ),
    );
  }
}
