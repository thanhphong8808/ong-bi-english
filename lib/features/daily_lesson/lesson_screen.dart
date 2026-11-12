// lib/features/daily_lesson/lesson_screen.dart
//
// "Học hôm nay": composes today's lesson (or a test), runs its steps one
// screen at a time, records every answer, then hands out rewards.
import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/config/app_config.dart';
import '../../core/db/repositories.dart';
import '../../core/providers.dart';
import '../../core/services/study_clock.dart';
import '../../curriculum/lesson_composer.dart';
import '../../curriculum/lesson_plan.dart';
import '../../curriculum/scorers/test_grader.dart';
import '../../curriculum/test_builder.dart';
import '../../l10n/strings_vi.dart';
import '../../widgets/bi_mascot.dart';
import '../rewards/reward_screen.dart';
import '../rewards/stickers.dart';
import '../tests/test_result_screen.dart';
import 'activities/activity_base.dart';
import 'activities/activity_factory.dart';
import 'lesson_audio.dart';

enum LessonMode { daily, placement, practice }

/// Route argument for /lesson.
class LessonRequest {
  const LessonRequest({this.mode = LessonMode.daily, this.plan});

  final LessonMode mode;

  /// A ready-made plan (writing practice); otherwise the composer decides.
  final LessonPlan? plan;
}

class LessonScreen extends ConsumerStatefulWidget {
  const LessonScreen({super.key, this.request = const LessonRequest()});

  final LessonRequest request;

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  final GlobalKey<ActivityState> _activity = GlobalKey<ActivityState>();
  late final AppServices _services = ref.read(appServicesProvider);
  final DateTime _started = DateTime.now();

  Profile? _profile;
  LessonPlan? _plan;
  int _index = -1;
  int _stars = 0;
  bool _finishing = false;
  final List<QuestionOutcome> _outcomes = [];
  final List<String> _introduced = [];

  @override
  void initState() {
    super.initState();
    _services.studyClock.start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _services.studyClock.stop();
    _services.speech.stop();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = ref.read(parentSettingsProvider);
    final profile = await ref.read(activeProfileProvider.future);
    if (!mounted) {
      return;
    }
    final caps = _services.capabilities.value;
    final now = DateTime.now();
    final options = ComposerOptions(
      now: now,
      delayReading: settings.delayEnglishReading,
      speechAvailable: caps.speech,
      inkAvailable: caps.ink,
    );
    final random = Random(now.millisecondsSinceEpoch);
    final LessonPlan plan;
    if (widget.request.plan != null) {
      plan = widget.request.plan!;
    } else if (widget.request.mode == LessonMode.placement) {
      plan = TestBuilder(_services.curriculum).placement(options: options, random: random);
    } else {
      final snapshot = await _services.progress.snapshot(profile.id, now: now);
      plan = LessonComposer(curriculum: _services.curriculum).compose(
        level: profile.level,
        snapshot: snapshot,
        options: options,
        random: random,
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _profile = profile;
      _plan = plan;
    });

    final voice = settings.voice;
    final speed = ref.read(slowModeProvider) ? AppConfig.slowSpeechRate : AppConfig.normalSpeechRate;
    _services.audioCache.prewarm(LessonAudio.forPlan(plan, _services.curriculum, voice: voice, speed: speed));
    if (caps.speech) {
      unawaited(_services.stt.ensureReady(_services.profile).catchError((Object _) {}));
    }

    if (plan.isEmpty) {
      await _services.speech.sayVi(S.lessonEmpty).catchError((Object _) {});
      return;
    }
    await _services.speech.sayVi(_introFor(plan)).catchError((Object _) {});
    if (mounted) {
      setState(() => _index = 0);
    }
  }

  String _introFor(LessonPlan plan) {
    final unit = _services.curriculum.unitById(plan.unitId);
    switch (plan.kind) {
      case LessonKind.newContent:
        return S.lessonIntro(unit?.topicVi ?? '');
      case LessonKind.unitReview:
        return S.reviewIntro;
      case LessonKind.remedial:
        return S.remedialIntro;
      case LessonKind.practice:
        return S.practiceIntro;
      case LessonKind.levelReview:
        return S.levelReviewIntro;
      case LessonKind.unitTest:
        return S.unitTestSpoken;
      case LessonKind.levelTest:
        return S.levelTestSpoken;
      case LessonKind.placement:
        return S.placementSpoken;
    }
  }

  bool get _isPlacement => _plan?.kind == LessonKind.placement;

  Future<void> _onDone(StepResult result) async {
    final plan = _plan;
    final profile = _profile;
    if (plan == null || profile == null || _index < 0 || _index >= plan.steps.length) {
      return;
    }
    final step = plan.steps[_index];
    _stars += result.correct ? AppConfig.starsPerActivity : 0;

    if (step is PresentItemStep || step is PhonicsStep) {
      _introduced.add(step.itemId);
    }
    if (step is DialogueStep) {
      unawaited(_services.progress.setDialogueStage(profile.id, step.dialogueId, step.dialogueStage));
    }
    if (!_isPlacement && !result.unscored && step.itemId.isNotEmpty && step.skill.isNotEmpty) {
      unawaited(_services.progress.recordAnswer(
        profileId: profile.id,
        itemId: step.itemId,
        skill: step.skill,
        correct: result.correct,
        score: result.value,
      ).catchError((Object _) {}));
    }
    if (plan.isTest) {
      _outcomes.add(QuestionOutcome(
        questionId: step.questionId,
        itemId: step.itemId,
        skill: step.skill.isEmpty ? 'listen' : step.skill,
        score: result.unscored ? 1.0 : result.value.clamp(0.0, 1.0).toDouble(),
      ));
    }

    final next = _index + 1;
    final settings = ref.read(parentSettingsProvider);
    final overtime = DateTime.now().difference(_started).inMinutes >= settings.sessionMinutes;
    final locked = _services.studyClock.lock(settings) != StudyLock.none;
    final stopEarly = !plan.isTest && widget.request.mode == LessonMode.daily && (overtime || locked);
    if (next >= plan.steps.length || stopEarly) {
      await _finish();
    } else if (mounted) {
      setState(() => _index = next);
    }
  }

  Future<void> _finish() async {
    if (_finishing) {
      return;
    }
    _finishing = true;
    final plan = _plan!;
    final profile = _profile!;
    final services = _services;
    final grader = const TestGrader();
    if (!mounted) {
      return;
    }
    final router = GoRouter.of(context);
    // Captured now: the child may close the screen while results are saved,
    // and `ref` must not be used after that.
    final container = ProviderScope.containerOf(context, listen: false);
    final settings = ref.read(parentSettingsProvider);

    switch (plan.kind) {
      case LessonKind.placement:
        double scoreOf(String prefix) {
          final scores = _outcomes.where((o) => o.questionId.startsWith(prefix)).map((o) => o.score).toList();
          return scores.isEmpty ? 0 : scores.reduce((a, b) => a + b) / scores.length;
        }
        final l0 = scoreOf('PLACE-L0');
        final l1 = scoreOf('PLACE-L1');
        final level = grader.placeLevel(level0Score: l0, level1Score: l1);
        await services.progress.recordPlacement(profile.id, level, (l0 + l1) / 2);
        container.invalidate(activeProfileProvider);
        router.go(AppRoutes.testResult, extra: TestResultArgs.placement(level));
      case LessonKind.unitTest:
        final unit = services.curriculum.unitById(plan.unitId)!;
        final report = grader.gradeUnit(_outcomes);
        await services.progress.recordUnitTest(profile.id, unit, report);
        await services.db.profileRepo.addStars(profile.id, _stars + (report.passed ? AppConfig.starsLessonBonus : 0));
        container.invalidate(activeProfileProvider);
        router.go(AppRoutes.testResult, extra: TestResultArgs.unit(report, unit.topicVi));
      case LessonKind.levelTest:
        final report = grader.gradeLevel(_outcomes);
        final passed = await services.progress.recordLevelTest(profile.id, plan.level, report);
        await services.db.profileRepo.addStars(profile.id, _stars);
        container.invalidate(activeProfileProvider);
        if (passed) {
          router.go(AppRoutes.levelUp, extra: plan.level + 1);
        } else {
          router.go(AppRoutes.testResult, extra: TestResultArgs.level(report, plan.level));
        }
      case LessonKind.newContent:
      case LessonKind.unitReview:
      case LessonKind.remedial:
      case LessonKind.practice:
      case LessonKind.levelReview:
        if (widget.request.mode == LessonMode.daily) {
          await services.progress.completeLesson(profile.id, plan, introducedIds: _introduced);
        }
        final owned = {for (final r in await services.db.rewardRepo.forProfile(profile.id)) r.stickerId};
        final sticker = nextSticker(owned);
        final earnSticker = widget.request.mode == LessonMode.daily;
        if (earnSticker) {
          await services.db.rewardRepo.add(profile.id, sticker.id);
        }
        final total = _stars + AppConfig.starsLessonBonus;
        await services.db.profileRepo.addStars(profile.id, total);
        container.invalidate(activeProfileProvider);
        // Prepare the next lessons' audio while the child celebrates.
        final snapshot = await services.progress.snapshot(profile.id);
        services.audioCache.prewarm(LessonAudio.upcoming(
          services.curriculum,
          profile.level,
          snapshot,
          voice: settings.voice,
          speed: AppConfig.normalSpeechRate,
        ));
        router.go(AppRoutes.reward, extra: RewardArgs(stars: total, stickerId: earnSticker ? sticker.id : null));
    }
  }

  Future<void> _confirmExit() async {
    final services = _services;
    unawaited(services.speech.sayVi(S.exitConfirmSpoken).catchError((Object _) {}));
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.cream,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              KidIconButton(
                icon: Icons.home_rounded,
                size: 96,
                label: S.exitLesson,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              KidIconButton(
                icon: Icons.play_arrow_rounded,
                size: 96,
                color: AppColors.leaf,
                label: S.continueLabel,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
    if (leave == true && mounted) {
      await services.speech.stop();
      if (mounted) {
        context.go(AppRoutes.home);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final slow = ref.watch(slowModeProvider);
    final level = _profile?.level ?? 0;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _confirmExit();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    KidIconButton(icon: Icons.close_rounded, size: 60, onPressed: _confirmExit),
                    const SizedBox(width: 10),
                    KidIconButton(
                      icon: Icons.volume_up_rounded,
                      size: 60,
                      onPressed: () => _activity.currentState?.replay(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: LinearProgressIndicator(
                          minHeight: 18,
                          value: plan == null || plan.steps.isEmpty || _index < 0
                              ? 0
                              : (_index / plan.steps.length).clamp(0.0, 1.0).toDouble(),
                          color: AppColors.honeyDeep,
                          backgroundColor: AppColors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => ref.read(slowModeProvider.notifier).toggle(),
                      child: Container(
                        width: 60,
                        height: 60,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: slow ? AppColors.leaf : AppColors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.ink, width: 3),
                        ),
                        child: Text(
                          slow ? '🐢' : '🐇',
                          style: const TextStyle(fontFamily: AppTheme.emojiFont, fontSize: 30),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: plan == null || _index < 0
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              BiMascot(mood: BiMood.thinking, size: 220, level: level),
                              const SizedBox(height: 12),
                              Text(
                                plan != null && plan.isEmpty ? S.lessonEmpty : S.lessonLoading,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                              ),
                              if (plan != null && plan.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 20),
                                  child: KidIconButton(
                                    icon: Icons.home_rounded,
                                    size: 96,
                                    onPressed: () => context.go(AppRoutes.home),
                                  ),
                                ),
                            ],
                          ),
                        )
                      : _index >= plan.steps.length
                          ? const Center(child: BiMascot(mood: BiMood.cheering, size: 220))
                          : buildActivity(
                              plan.steps[_index],
                              key: ValueKey<int>(_index),
                              onDone: _onDone,
                              testMode: plan.isTest,
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
