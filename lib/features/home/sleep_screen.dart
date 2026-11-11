// lib/features/home/sleep_screen.dart
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/kid_scaffold.dart';
import '../../core/services/study_clock.dart';
import '../../l10n/strings_vi.dart';
import '../../widgets/bi_mascot.dart';
import '../daily_lesson/activities/activity_base.dart';

/// Bi sleeps when today's time is used up or outside the allowed hours.
/// The app stays locked until the next allowed period.
class SleepScreen extends StatelessWidget {
  const SleepScreen({super.key, required this.lock});

  final StudyLock lock;

  @override
  Widget build(BuildContext context) {
    final outside = lock == StudyLock.outsideHours;
    return KidScaffold(
      instructionVi: outside ? S.outsideHoursSpoken : S.sleepSpoken,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BiMascot(mood: BiMood.sleeping, size: 280),
            const SizedBox(height: 12),
            Text(S.sleepTitle, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            const Text(S.sleepBody, style: TextStyle(fontSize: 22)),
            const SizedBox(height: 30),
            KidIconButton(icon: Icons.home_rounded, size: 90, onPressed: () => context.pop()),
          ],
        ),
      ),
    );
  }
}
