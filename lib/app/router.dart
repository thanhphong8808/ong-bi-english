// lib/app/router.dart
import 'package:go_router/go_router.dart';

import '../core/services/study_clock.dart';
import '../features/daily_lesson/lesson_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/sleep_screen.dart';
import '../features/parent/chat_log_screen.dart';
import '../features/parent/data_screen.dart';
import '../features/parent/diagnostics_screen.dart';
import '../features/parent/model_manager_screen.dart';
import '../features/parent/parent_home_screen.dart';
import '../features/parent/parent_settings_screen.dart';
import '../features/parent/profiles_screen.dart';
import '../features/parent/progress_screen.dart';
import '../features/rewards/reward_screen.dart';
import '../features/rewards/sticker_album_screen.dart';
import '../features/setup/setup_screen.dart';
import '../features/talk_with_bi/talk_screen.dart';
import '../features/tests/level_up_screen.dart';
import '../features/tests/test_result_screen.dart';
import '../features/write/write_home_screen.dart';

class AppRoutes {
  const AppRoutes._();

  static const String setup = '/setup';
  static const String home = '/home';
  static const String lesson = '/lesson';
  static const String talk = '/talk';
  static const String write = '/write';
  static const String stickers = '/stickers';
  static const String sleep = '/sleep';
  static const String reward = '/reward';
  static const String testResult = '/test-result';
  static const String levelUp = '/level-up';
  static const String parent = '/parent';
  static const String parentSettings = '/parent/settings';
  static const String parentModels = '/parent/models';
  static const String parentDiagnostics = '/parent/diagnostics';
  static const String parentProgress = '/parent/progress';
  static const String parentProfiles = '/parent/profiles';
  static const String parentChats = '/parent/chats';
  static const String parentData = '/parent/data';
}

/// The parent routes are only ever pushed after the parent gate succeeds
/// (see showParentGate); kid mode has no other way to reach them.
GoRouter buildRouter({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: AppRoutes.setup, builder: (context, state) => const SetupScreen()),
      GoRoute(path: AppRoutes.home, builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: AppRoutes.lesson,
        builder: (context, state) {
          final extra = state.extra;
          return LessonScreen(request: extra is LessonRequest ? extra : const LessonRequest());
        },
      ),
      GoRoute(path: AppRoutes.talk, builder: (context, state) => const TalkScreen()),
      GoRoute(path: AppRoutes.write, builder: (context, state) => const WriteHomeScreen()),
      GoRoute(path: AppRoutes.stickers, builder: (context, state) => const StickerAlbumScreen()),
      GoRoute(
        path: AppRoutes.sleep,
        builder: (context, state) {
          final extra = state.extra;
          return SleepScreen(lock: extra is StudyLock ? extra : StudyLock.dailyLimit);
        },
      ),
      GoRoute(
        path: AppRoutes.reward,
        builder: (context, state) {
          final extra = state.extra;
          return RewardScreen(args: extra is RewardArgs ? extra : const RewardArgs(stars: 0));
        },
      ),
      GoRoute(
        path: AppRoutes.testResult,
        builder: (context, state) {
          final extra = state.extra;
          return TestResultScreen(args: extra is TestResultArgs ? extra : TestResultArgs.placement(0));
        },
      ),
      GoRoute(
        path: AppRoutes.levelUp,
        builder: (context, state) {
          final extra = state.extra;
          return LevelUpScreen(level: extra is int ? extra : 1);
        },
      ),
      GoRoute(
        path: AppRoutes.parent,
        builder: (context, state) => const ParentHomeScreen(),
        routes: [
          GoRoute(path: 'settings', builder: (context, state) => const ParentSettingsScreen()),
          GoRoute(path: 'models', builder: (context, state) => const ModelManagerScreen()),
          GoRoute(path: 'diagnostics', builder: (context, state) => const DiagnosticsScreen()),
          GoRoute(path: 'progress', builder: (context, state) => const ProgressScreen()),
          GoRoute(path: 'profiles', builder: (context, state) => const ProfilesScreen()),
          GoRoute(path: 'chats', builder: (context, state) => const ChatLogScreen()),
          GoRoute(path: 'data', builder: (context, state) => const DataScreen()),
        ],
      ),
    ],
  );
}
