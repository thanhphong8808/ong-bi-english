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
import '../../curriculum/lesson_composer.dart';
import '../../curriculum/pocket_phrases.dart';
import '../../widgets/bi_mascot.dart';
import '../../widgets/item_picture.dart';
import '../../widgets/ui_kit.dart';
import '../daily_lesson/activities/activity_base.dart';
import '../daily_lesson/lesson_audio.dart';
import '../daily_lesson/lesson_screen.dart';
import '../parent/parent_gate_dialog.dart';
import '../rewards/badges.dart';
import 'hello_store.dart';
import 'week_honey.dart';

/// Kid home: the morning hello with Bi, today's lesson, four tiles (talk,
/// stories, writing, pocket phrases), this week's honeycomb and a bottom
/// bar. Every card has a big picture, so a child who cannot read yet can
/// still find their way; Bi reads the greeting aloud.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static bool _warmedUp = false;

  StreakInfo _streak = StreakInfo.none;
  bool _celebrating = false;
  HelloStatus _helloStatus = const HelloStatus(doneToday: false);

  /// Current unit: (number, topic, share of its words met).
  (int, String, double)? _unit;
  int _pocketCount = 0;

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
      final hello = await HelloStore.status(services, profile.id);
      final pocket = PocketProgress.decode(await services.db.settingsRepo.read(PocketProgress.key, profileId: profile.id));
      final snapshot = await services.progress.snapshot(profile.id);
      final unit = LessonComposer(curriculum: services.curriculum).currentUnit(profile.level, snapshot);
      (int, String, double)? unitInfo;
      if (unit != null) {
        final words = unit.items.where((i) => !i.isLetter).toList();
        final met = words.where((i) => snapshot.introduced(i.id)).length;
        unitInfo = (unit.number, unit.topicVi, words.isEmpty ? 0 : met / words.length);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _streak = streak;
        _helloStatus = hello;
        _pocketCount = pocket.collected;
        _unit = unitInfo;
      });
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

  Future<void> _hello() async {
    if (_goToSleepIfLocked()) {
      return;
    }
    final services = ref.read(appServicesProvider);
    final profile = await ref.read(activeProfileProvider.future);
    if (!mounted) {
      return;
    }
    await HelloStore.open(context, services, profile.id, profile.name, profile.level);
    await _refreshHoney();
  }

  Future<void> _stories() async {
    if (_goToSleepIfLocked()) {
      return;
    }
    await context.push(AppRoutes.talk, extra: 'stories');
    await _refreshHoney();
  }

  Future<void> _pocket() async {
    if (_goToSleepIfLocked()) {
      return;
    }
    await context.push(AppRoutes.pocket);
    await _refreshHoney();
  }

  String get _subtitle {
    final hour = DateTime.now().hour;
    if (hour < 11) {
      return S.homeSubtitleMorning;
    }
    return hour < 18 ? S.homeSubtitleDay : S.homeSubtitleEvening;
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(activeProfileProvider).value;
    final level = profile?.level ?? 0;
    final hello = _helloStatus;
    final unit = _unit;
    return KidScaffold(
      instructionVi: S.homeGreetingSpoken,
      topRight: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatPill(emoji: '⭐', text: '${profile?.stars ?? 0}'),
          const SizedBox(width: 8),
          RoundIconButton(
            icon: Icons.settings_rounded,
            semanticLabel: S.homeParent,
            size: 48,
            onPressed: _openParentArea,
          ),
        ],
      ),
      bottom: KidBottomNav(
        current: 0,
        items: [
          KidNavItem(emoji: '🏠', label: S.navHome, onTap: () {}),
          KidNavItem(emoji: '📖', label: S.navLearn, onTap: _learn),
          KidNavItem(emoji: '🐝', label: S.navTalk, onTap: _talk),
          KidNavItem(emoji: '🎁', label: S.navGifts, onTap: () => context.push(AppRoutes.stickers)),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
        children: [
          Text(S.homeHello(profile?.name ?? ''), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
          Text(_subtitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
          const SizedBox(height: 14),
          // Chào Bi mỗi ngày.
          SoftCard(
            gradient: AppGradients.honey,
            padding: const EdgeInsets.fromLTRB(20, 16, 10, 16),
            onTap: _hello,
            semanticLabel: S.homeHelloTitle,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(S.homeHelloTitle, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      if (hello.doneToday && hello.mission != null) ...[
                        const Text('🎯 ${S.homeHelloDone}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                        Text(hello.mission!.vi,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ] else
                        const Text(S.homeHelloSub, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      PillButton(
                        label: hello.doneToday ? S.homeHelloAgain : S.homeHelloStart,
                        icon: hello.doneToday ? Icons.replay_rounded : Icons.play_arrow_rounded,
                        color: AppColors.white,
                        onPressed: _hello,
                      ),
                    ],
                  ),
                ),
                BiMascot(mood: hello.doneToday ? BiMood.cheering : BiMood.happy, size: 132, level: level),
              ],
            ),
          ),
          const SectionTitle(S.homeLessonSection),
          SoftCard(
            onTap: _learn,
            semanticLabel: S.homeLearn,
            child: Row(
              children: [
                const IconTile('📖', size: 72),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(S.homeLearn, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                      Text(
                        unit == null ? S.homeLessonSub : S.homeUnit(unit.$1, unit.$2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.inkSoft),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: SoftProgress(value: unit?.$3 ?? 0)),
                          const SizedBox(width: 8),
                          Text('${((unit?.$3 ?? 0) * 100).round()}%',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(gradient: AppGradients.honey, shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded, size: 32, color: AppColors.ink),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _Tile(emoji: '💬', title: S.homeTalk, sub: S.homeTalkSub, tint: AppColors.skySoft, onTap: _talk)),
              const SizedBox(width: 14),
              Expanded(
                child: _Tile(emoji: '📚', title: S.homeStories, sub: S.homeStoriesSub, tint: AppColors.berrySoft, onTap: _stories),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _Tile(emoji: '✏️', title: S.homeWrite, sub: S.homeWriteSub, tint: AppColors.grapeSoft, onTap: _write)),
              const SizedBox(width: 14),
              Expanded(
                child: _Tile(
                  emoji: '🎒',
                  title: S.homePocket,
                  sub: S.homePocketSub(_pocketCount),
                  tint: AppColors.leafSoft,
                  onTap: _pocket,
                ),
              ),
            ],
          ),
          const SectionTitle(S.homeWeek),
          SoftCard(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: WeekHoney(streak: _streak),
          ),
        ],
      ),
    );
  }
}

/// A square-ish home tile: emoji in a pastel tile, title and a short line.
class _Tile extends StatelessWidget {
  const _Tile({required this.emoji, required this.title, required this.sub, required this.tint, required this.onTap});

  final String emoji;
  final String title;
  final String sub;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      semanticLabel: title,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(emoji, color: tint, size: 60),
          const SizedBox(height: 10),
          Text(title, maxLines: 2, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, height: 1.15)),
          const SizedBox(height: 2),
          Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
        ],
      ),
    );
  }
}
