// lib/features/daily_lesson/activities/activity_base.dart
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers.dart';
import '../../../core/services/english_voice.dart';
import '../../../curriculum/lesson_plan.dart';
import '../../../curriculum/models.dart';
import '../../../l10n/strings_vi.dart';

/// Result of one activity.
class StepResult {
  const StepResult({required this.correct, required this.stars, this.score});

  final bool correct;
  final int stars;

  /// 0..1; defaults to 1 for correct and 0 for wrong.
  final double? score;

  double get value => score ?? (correct ? 1 : 0);

  /// Used when the child could not be scored (no speech model): counts as
  /// practice, but never updates progress.
  static const StepResult practised = StepResult(correct: true, stars: 1, score: -1);

  bool get unscored => score != null && score! < 0;
}

typedef StepDone = void Function(StepResult result);

/// Base class of every kid activity widget.
abstract class ActivityView<St extends LessonStep> extends ConsumerStatefulWidget {
  const ActivityView({super.key, required this.step, required this.onDone, this.testMode = false});

  final St step;
  final StepDone onDone;

  /// Tests allow a single attempt and give no praise per question.
  final bool testMode;
}

/// Shared behaviour: Bi's voice, the two-attempt rule and positive feedback.
abstract class ActivityState<T extends ActivityView> extends ConsumerState<T> {
  static final Random random = Random();

  int attempts = 0;
  bool finished = false;
  bool celebrating = false;

  /// Spoken once when the activity opens (and by the replay button).
  String get instructionVi;

  AppServices get services => ref.read(appServicesProvider);

  Curriculum get curriculum => services.curriculum;

  double get speed => ref.read(slowModeProvider) ? AppConfig.slowSpeechRate : AppConfig.normalSpeechRate;

  EnglishVoice get voice => ref.read(parentSettingsProvider).voice;

  bool get hideText => ref.read(hideEnglishTextProvider);

  Item? item(String id) => curriculum.item(id);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  void dispose() {
    services.speech.stop();
    super.dispose();
  }

  Future<void> _open() async {
    if (!mounted) {
      return;
    }
    await replay();
  }

  /// Instruction and English model again (speaker button).
  Future<void> replay() async {
    if (instructionVi.isNotEmpty) {
      await sayVi(instructionVi);
    }
    if (mounted) {
      await onOpened();
    }
  }

  /// Runs after the instruction: typically plays the English model.
  Future<void> onOpened() async {}

  Future<void> sayVi(String text) async {
    try {
      await services.speech.sayVi(text, speed: 1.0);
    } catch (_) {
      // Voice is best-effort; pictures still carry the task.
    }
  }

  Future<void> sayEn(String text, {bool slow = false, EnglishVoice? as}) async {
    if (text.isEmpty) {
      return;
    }
    try {
      await services.speech.sayEn(
        text,
        voice: as ?? voice,
        speed: slow ? AppConfig.slowSpeechRate : speed,
      );
    } catch (_) {
      // English voice pack missing: the parent sees this in diagnostics.
    }
  }

  /// A right answer: praise, sparkle, then move on.
  Future<void> succeed(int stars, {double? score}) async {
    if (finished) {
      return;
    }
    finished = true;
    if (mounted) {
      setState(() => celebrating = true);
    }
    if (!widget.testMode) {
      await sayVi(S.praiseLines[random.nextInt(S.praiseLines.length)]);
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted) {
      widget.onDone(StepResult(correct: true, stars: stars.clamp(1, 3).toInt(), score: score));
    }
  }

  /// A wrong answer. Returns true when the child gets another try.
  /// Never shows a red cross or plays an error sound.
  Future<bool> miss({Future<void> Function()? showModel, double score = 0}) async {
    if (finished) {
      return false;
    }
    attempts++;
    if (widget.testMode) {
      finished = true;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        widget.onDone(StepResult(correct: false, stars: 0, score: score));
      }
      return false;
    }
    if (attempts < AppConfig.maxAttemptsPerItem) {
      await sayVi(S.sayRetry);
      if (showModel != null && mounted) {
        await showModel();
      }
      return true;
    }
    finished = true;
    await sayVi(S.sayEffort);
    if (mounted) {
      widget.onDone(StepResult(correct: false, stars: 0, score: score));
    }
    return false;
  }

  /// Finish without a right/wrong judgement (listen-only stages).
  void complete([StepResult result = const StepResult(correct: true, stars: 1)]) {
    if (finished) {
      return;
    }
    finished = true;
    widget.onDone(result);
  }
}

/// Big round icon button for kid mode.
class KidIconButton extends StatelessWidget {
  const KidIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.label,
    this.color = AppColors.white,
    this.size = 72,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? label;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: color,
            shape: const CircleBorder(side: BorderSide(color: AppColors.ink, width: 3)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(icon, size: size * 0.55, color: AppColors.ink, semanticLabel: label),
              ),
            ),
          ),
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(label!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }
}

/// Big word text in the handwriting font.
class BigWord extends StatelessWidget {
  const BigWord(this.text, {super.key, this.size = 44, this.color = AppColors.ink});

  final String text;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: AppTheme.writingFont,
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.15,
      ),
    );
  }
}

/// Grid of 2-6 equal cells that fills the available space.
class ChoiceGrid extends StatelessWidget {
  const ChoiceGrid({super.key, required this.children, this.spacing = 14});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final columns = children.length <= 3 ? children.length : 2;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final row = children.sublist(i, min(i + columns, children.length));
      rows.add(Expanded(
        child: Row(
          children: [
            for (var j = 0; j < row.length; j++) ...[
              if (j > 0) SizedBox(width: spacing),
              Expanded(child: row[j]),
            ],
          ],
        ),
      ));
      if (i + columns < children.length) {
        rows.add(SizedBox(height: spacing));
      }
    }
    if (children.length <= 3) {
      return Row(
        children: [
          for (var j = 0; j < children.length; j++) ...[
            if (j > 0) SizedBox(width: spacing),
            Expanded(child: AspectRatio(aspectRatio: 0.85, child: children[j])),
          ],
        ],
      );
    }
    return Column(children: rows);
  }
}
