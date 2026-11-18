// lib/features/grammar/grammar_home_screen.dart
//
// "Ngữ pháp": the tense overview, the verb table, a mixed grammar test and
// the lessons in five steps (simple sentences, present, past and future,
// comparing and advice, more). Each lesson shows its best score so far.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/kid_scaffold.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/providers.dart';
import '../../curriculum/grammar.dart';
import '../../l10n/strings_vi.dart';
import '../../widgets/ui_kit.dart';
import 'grammar_practice_screen.dart';

class GrammarHomeScreen extends ConsumerStatefulWidget {
  const GrammarHomeScreen({super.key});

  @override
  ConsumerState<GrammarHomeScreen> createState() => _GrammarHomeScreenState();
}

class _GrammarHomeScreenState extends ConsumerState<GrammarHomeScreen> {
  late final AppServices _services = ref.read(appServicesProvider);
  GrammarBook? _book;

  /// Best score (0..1) of each lesson and of the mixed test.
  Map<String, double> _best = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final book = await _services.grammarBook();
    final profile = await ref.read(activeProfileProvider.future);
    final results = await _services.db.testRepo.forProfile(profile.id);
    final best = <String, double>{};
    for (final r in results) {
      if (r.kind == GrammarPracticeArgs.resultKind && r.score > (best[r.targetId] ?? -1)) {
        best[r.targetId] = r.score;
      }
    }
    if (mounted) {
      setState(() {
        _book = book;
        _best = best;
      });
    }
  }

  Future<void> _open(GrammarPracticeArgs args) async {
    unawaited(_services.speech.stop());
    await context.push(AppRoutes.grammarLesson, extra: args);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final book = _book;
    final level = ref.watch(activeProfileProvider).value?.level ?? 0;
    return KidScaffold(
      instructionVi: S.grammarHomeSpoken,
      showBack: true,
      child: book == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                const Text(S.grammarTitle, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ToolCard(
                        emoji: '🕰️',
                        title: S.grammarTenses,
                        sub: S.grammarTensesSub,
                        tint: AppColors.skySoft,
                        onTap: () => context.push(AppRoutes.grammarTenses),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ToolCard(
                        emoji: '🔤',
                        title: S.grammarVerbs,
                        sub: S.grammarVerbsSub,
                        tint: AppColors.grapeSoft,
                        onTap: () => context.push(AppRoutes.grammarVerbs),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SoftCard(
                  semanticLabel: S.grammarQuiz,
                  gradient: AppGradients.honey,
                  onTap: () => _open(GrammarPracticeArgs.mixed(book)),
                  child: Row(
                    children: [
                      const IconTile('📝', color: AppColors.white, size: 60),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(S.grammarQuiz, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                            Text(
                              _best.containsKey(GrammarPracticeArgs.mixedId)
                                  ? '${S.grammarBest}: ${S.percent(_best[GrammarPracticeArgs.mixedId]!)}'
                                  : S.grammarQuizSub,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.play_circle_fill_rounded, size: 40, color: AppColors.ink),
                    ],
                  ),
                ),
                for (final stage in book.stages) ...[
                  SectionTitle(
                    S.grammarStage(stage.stage, stage.nameVi),
                    trailing: Text(
                      '${S.grammarForLevel} ${GrammarBook.levelForStage(stage.stage)}${level >= GrammarBook.levelForStage(stage.stage) ? ' ✓' : ''}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.inkSoft),
                    ),
                  ),
                  for (final lesson in book.ofStage(stage.stage))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _LessonCard(
                        lesson: lesson,
                        best: _best[lesson.id],
                        onTap: () => _open(GrammarPracticeArgs.lesson(lesson)),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.emoji, required this.title, required this.sub, required this.tint, required this.onTap});

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
          IconTile(emoji, color: tint, size: 54),
          const SizedBox(height: 8),
          Text(title, maxLines: 2, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, height: 1.15)),
          Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
        ],
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.lesson, required this.best, required this.onTap});

  final GrammarLesson lesson;
  final double? best;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final score = best;
    return SoftCard(
      onTap: onTap,
      semanticLabel: lesson.titleVi,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          IconTile(lesson.emoji, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lesson.titleVi, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, height: 1.2)),
                const SizedBox(height: 2),
                Text(lesson.titleEn,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: score == null
                  ? AppColors.line
                  : (score >= 0.8 ? AppColors.leafSoft : AppColors.honeySoft),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              score == null ? S.grammarNotYet : '${'⭐' * grammarStars(score)} ${S.percent(score)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}
