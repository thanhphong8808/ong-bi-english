// lib/features/tests/test_result_screen.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/providers.dart';
import '../../curriculum/scorers/test_grader.dart';
import '../../l10n/strings_vi.dart';
import '../../widgets/bi_mascot.dart';
import '../../widgets/item_picture.dart';
import '../daily_lesson/activities/activity_base.dart';

enum TestResultKind { placement, unit, level }

class TestResultArgs {
  const TestResultArgs._({
    required this.kind,
    required this.passed,
    this.report,
    this.level = 0,
    this.title = '',
  });

  factory TestResultArgs.placement(int level) =>
      TestResultArgs._(kind: TestResultKind.placement, passed: true, level: level);

  factory TestResultArgs.unit(GradeReport report, String topic) =>
      TestResultArgs._(kind: TestResultKind.unit, passed: report.passed, report: report, title: topic);

  factory TestResultArgs.level(GradeReport report, int level) =>
      TestResultArgs._(kind: TestResultKind.level, passed: report.passed, report: report, level: level);

  final TestResultKind kind;
  final bool passed;
  final GradeReport? report;
  final int level;
  final String title;
}

/// After a test: always encouraging. Stars for the child; the detailed
/// percentages are in the parent area.
class TestResultScreen extends ConsumerStatefulWidget {
  const TestResultScreen({super.key, required this.args});

  final TestResultArgs args;

  @override
  ConsumerState<TestResultScreen> createState() => _TestResultScreenState();
}

class _TestResultScreenState extends ConsumerState<TestResultScreen> {
  String get _spoken {
    final a = widget.args;
    switch (a.kind) {
      case TestResultKind.placement:
        return a.level >= 1 ? S.placementDoneLevel1 : S.placementDoneLevel0;
      case TestResultKind.unit:
        return a.passed ? S.testPassedSpoken : S.testRetrySpoken;
      case TestResultKind.level:
        return S.levelTestRetrySpoken;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appServicesProvider).speech.sayVi(_spoken).catchError((Object _) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.args.report;
    final stars = report == null ? 3 : (report.total >= 0.9 ? 3 : (report.total >= 0.6 ? 2 : 1));
    final level = ref.watch(activeProfileProvider).value?.level ?? 0;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BiMascot(mood: widget.args.passed ? BiMood.cheering : BiMood.happy, size: 230, level: level),
                Text(S.testDoneTitle, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                StarRow(stars: stars, size: 56),
                if (widget.args.passed && widget.args.kind == TestResultKind.unit) ...[
                  const SizedBox(height: 12),
                  const EmojiText('🔓', size: 64),
                ],
                const SizedBox(height: 30),
                KidIconButton(
                  icon: Icons.home_rounded,
                  size: 110,
                  color: AppColors.honey,
                  label: S.rewardHome,
                  onPressed: () => context.go(AppRoutes.home),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
