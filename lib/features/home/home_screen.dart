// lib/features/home/home_screen.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/kid_scaffold.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/config/app_config.dart';
import '../../core/providers.dart';
import '../../core/services/study_clock.dart';
import '../../curriculum/streak.dart';
import '../../l10n/strings_vi.dart';
import '../../widgets/bi_mascot.dart';
import '../../widgets/giant_button.dart';
import '../../widgets/item_picture.dart';
import '../daily_lesson/activities/activity_base.dart';
import '../daily_lesson/lesson_audio.dart';
import '../daily_lesson/lesson_screen.dart';
import '../parent/parent_gate_dialog.dart';
import '../rewards/badges.dart';
import 'week_honey.dart';

/// Kid home: Bi in the middle and three giant buttons. Nothing to read.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static bool _warmedUp = false;

  StreakInfo _streak = StreakInfo.none;
  bool _celebrating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  /// Loads today's study time and renders audio in the background, once.
  Future<void> _prepare() async {
    final services = ref.read(appServicesProvider);
    final settings = ref.read(parentSettingsProvider);
    final profile = await ref.read(activeProfileProvider.future);
    await services.studyClock.load(profile.id);
    await _refreshHoney();
    if (_warmedUp) {
      return;
    }
    _warmedUp = true;
    services.audioCache.prewarm(LessonAudio.instructions());
    final snapshot = await services.progress.snapshot(profile.id);
    services.audioCache.prewarm(LessonAudio.upcoming(
      services.curriculum,
      profile.level,
      snapshot,
      voice: settings.voice,
      speed: AppConfig.normalSpeechRate,
    ));
  }

  /// Updates the honeycomb and celebrates badges won since last time.
  Future<void> _refreshHoney() async {
    if (!mounted) {
      return;
    }
    final services = ref.read(appServicesProvider);
    try {
      final profile = await ref.read(activeProfileProvider.future);
      final streak = await services.badges.streak(profile.id);
      final fresh = await services.badges.awardNew(profile);
      if (!mounted) {
        return;
      }
      setState(() => _streak = streak);
      if (fresh.isNotEmpty && !_celebrating) {
        _celebrating = true;
        for (final badge in fresh) {
          if (!mounted) {
            break;
          }
          await _celebrate(badge);
        }
        _celebrating = false;
      }
    } catch (_) {
      // The honeycomb is a bonus; never block the home screen.
    }
  }

  Future<void> _celebrate(MilestoneBadge badge) async {
    final services = ref.read(appServicesProvider);
    unawaited(services.speech.sayVi(S.badgeSpoken(badge.title)).catchError((Object _) {}));
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.cream,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(S.badgeNew, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              EmojiText(badge.emoji, size: 96),
              const SizedBox(height: 12),
              Text(
                badge.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 20),
              KidIconButton(
                icon: Icons.check_rounded,
                size: 88,
                color: AppColors.leaf,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _goToSleepIfLocked() {
    final services = ref.read(appServicesProvider);
    final lock = services.studyClock.lock(ref.read(parentSettingsProvider));
    if (lock == StudyLock.none) {
      return false;
    }
    context.push(AppRoutes.sleep, extra: lock);
    return true;
  }

  Future<void> _learn() async {
    if (_goToSleepIfLocked()) {
      return;
    }
    final profile = await ref.read(activeProfileProvider.future);
    if (!mounted) {
      return;
    }
    await context.push(
      AppRoutes.lesson,
      extra: LessonRequest(mode: profile.placementDone ? LessonMode.daily : LessonMode.placement),
    );
    await _refreshHoney();
  }

  Future<void> _talk() async {
    final services = ref.read(appServicesProvider);
    final settings = ref.read(parentSettingsProvider);
    if (!settings.talkWithBiEnabled) {
      unawaited(services.speech.sayVi(S.talkDisabledSpoken).catchError((Object _) {}));
      return;
    }
    if (_goToSleepIfLocked()) {
      return;
    }
    await context.push(AppRoutes.talk);
    await _refreshHoney();
  }

  Future<void> _write() async {
    if (_goToSleepIfLocked()) {
      return;
    }
    await context.push(AppRoutes.write);
    await _refreshHoney();
  }

  Future<void> _openParentArea() async {
    final ok = await showParentGate(context);
    if (ok && mounted) {
      context.push(AppRoutes.parent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(activeProfileProvider).value;
    final level = profile?.level ?? 0;
    return KidScaffold(
      instructionVi: S.homeGreetingSpoken,
      topRight: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StarBar(stars: profile?.stars ?? 0),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => context.push(AppRoutes.stickers),
            child: Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.ink, width: 2.5),
              ),
              child: const EmojiText('🎁', size: 32),
            ),
          ),
        ],
      ),
      bottom: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 4),
          child: IconButton(
            tooltip: S.homeParent,
            iconSize: 26,
            color: AppColors.ink.withValues(alpha: 0.55),
            icon: const Icon(Icons.settings_rounded),
            onPressed: _openParentArea,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: FittedBox(child: BiMascot(mood: BiMood.happy, size: 220, level: level)),
            ),
            WeekHoney(streak: _streak),
            const SizedBox(height: 14),
            GiantButton(emoji: '📖', label: S.homeLearn, color: AppColors.honey, onPressed: _learn),
            const SizedBox(height: 18),
            GiantButton(emoji: '💬', label: S.homeTalk, color: AppColors.sky, onPressed: _talk),
            const SizedBox(height: 18),
            GiantButton(emoji: '✏️', label: S.homeWrite, color: AppColors.berry, onPressed: _write),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _StarBar extends StatelessWidget {
  const _StarBar({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.ink, width: 2.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const EmojiText('⭐', size: 26),
          const SizedBox(width: 6),
          Text('$stars', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
