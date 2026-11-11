// lib/features/write/write_home_screen.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/kid_scaffold.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/config/app_config.dart';
import '../../core/providers.dart';
import '../../curriculum/lesson_plan.dart';
import '../../curriculum/models.dart';
import '../../l10n/strings_vi.dart';
import '../../widgets/giant_button.dart';
import '../daily_lesson/activities/activity_base.dart';
import '../daily_lesson/lesson_screen.dart';

/// "Tập viết": trace any letter, or (level 1 up) write learned words.
class WriteHomeScreen extends ConsumerStatefulWidget {
  const WriteHomeScreen({super.key});

  @override
  ConsumerState<WriteHomeScreen> createState() => _WriteHomeScreenState();
}

class _WriteHomeScreenState extends ConsumerState<WriteHomeScreen> {
  bool _letters = false;
  bool _upper = true;

  void _trace(String letter) {
    context.push(
      AppRoutes.lesson,
      extra: LessonRequest(
        mode: LessonMode.practice,
        plan: LessonPlan(
          kind: LessonKind.practice,
          unitId: 'WRITE',
          level: 0,
          steps: [TraceStep(stage: LessonStage.write, letter: letter)],
        ),
      ),
    );
  }

  Future<void> _words() async {
    final services = ref.read(appServicesProvider);
    final profile = await ref.read(activeProfileProvider.future);
    final snapshot = await services.progress.snapshot(profile.id);
    final caps = services.capabilities.value;
    final learned = [
      for (final unit in services.curriculum.units)
        if (unit.level <= profile.level)
          for (final item in unit.items)
            if (snapshot.introduced(item.id) &&
                !item.isLetter &&
                item.picturable &&
                RegExp(r'^[a-z]{2,8}$').hasMatch(item.en.toLowerCase()))
              item,
    ]..shuffle();
    final steps = <LessonStep>[
      for (final item in learned.take(6)) _wordStep(item, profile.level, caps.ink),
    ];
    if (steps.isEmpty) {
      await services.speech.sayVi(S.writeNoWordsYet).catchError((Object _) {});
      return;
    }
    if (!mounted) {
      return;
    }
    context.push(
      AppRoutes.lesson,
      extra: LessonRequest(
        mode: LessonMode.practice,
        plan: LessonPlan(kind: LessonKind.practice, unitId: 'WRITE', level: profile.level, steps: steps),
      ),
    );
  }

  LessonStep _wordStep(Item item, int level, bool ink) {
    final word = item.en.toLowerCase();
    if (level >= 2 && (ink || level >= AppConfig.typingAllowedFromLevel)) {
      return DictationStep(
        stage: LessonStage.write,
        itemId: item.id,
        text: word,
        sentence: false,
        allowKeyboard: level >= AppConfig.typingAllowedFromLevel,
      );
    }
    if (ink && !ref.read(hideEnglishTextProvider)) {
      return CopyWordStep(stage: LessonStage.write, word: word, itemId: item.id);
    }
    return WordBuilderStep(stage: LessonStage.write, itemId: item.id, word: word, speakWord: level >= 2);
  }

  @override
  Widget build(BuildContext context) {
    final level = ref.watch(activeProfileProvider).value?.level ?? 0;
    final lettersOnly = level == 0;
    if (_letters || lettersOnly) {
      final alphabet = 'abcdefghijklmnopqrstuvwxyz'.split('');
      return KidScaffold(
        instructionVi: S.writeMenuSpoken,
        showBack: true,
        onBack: lettersOnly || !_letters ? null : () => setState(() => _letters = false),
        topRight: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('ABC', style: TextStyle(fontSize: 22))),
            ButtonSegment(value: false, label: Text('abc', style: TextStyle(fontSize: 22))),
          ],
          selected: {_upper},
          onSelectionChanged: (value) => setState(() => _upper = value.first),
        ),
        child: GridView.count(
          crossAxisCount: 5,
          padding: const EdgeInsets.all(14),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            for (final c in alphabet)
              Material(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _trace(_upper ? c.toUpperCase() : c),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.ink, width: 2.5),
                    ),
                    child: BigWord(_upper ? c.toUpperCase() : c, size: 40),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return KidScaffold(
      instructionVi: S.writeHomeSpoken,
      showBack: true,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GiantButton(
              emoji: '🔤',
              label: S.writeLetters,
              color: AppColors.honey,
              onPressed: () => setState(() => _letters = true),
            ),
            const SizedBox(height: 24),
            GiantButton(emoji: '📝', label: S.writeWords, color: AppColors.berry, onPressed: _words),
          ],
        ),
      ),
    );
  }
}
