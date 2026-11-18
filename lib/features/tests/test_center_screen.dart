// lib/features/tests/test_center_screen.dart
//
// "Kiểm tra": the child (or a parent sitting next to them) can take a test
// any time to see how far they have come: a test of one unit already
// reached, a test of the whole level, or the mixed grammar test. These
// "check-up" tests never change the lesson path (a failed check-up does not
// add remedial lessons); they are saved with the other results, and this
// screen shows the average, the last ten scores and each skill.
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/kid_scaffold.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/db/repositories.dart';
import '../../core/providers.dart';
import '../../curriculum/grammar.dart';
import '../../curriculum/lesson_composer.dart';
import '../../curriculum/models.dart';
import '../../curriculum/test_builder.dart';
import '../../l10n/strings_vi.dart';
import '../../widgets/ui_kit.dart';
import '../daily_lesson/lesson_screen.dart';
import '../grammar/grammar_practice_screen.dart';

/// Summary of the saved results, pure so it can be tested.
class TestStats {
  const TestStats({required this.count, required this.passed, required this.average, required this.recent, required this.skills});

  /// Results that count (placement is left out).
  final int count;
  final int passed;

  /// Mean of the last ten scores, 0..1.
  final double average;

  /// The last ten scores, oldest first.
  final List<double> recent;

  /// Mean score of each skill section over the last twenty results.
  final Map<String, double> skills;

  static TestStats of(List<TestResult> results) {
    final counted = results.where((r) => r.kind != 'placement').toList()
      ..sort((a, b) => b.takenAt.compareTo(a.takenAt));
    final last = counted.take(10).toList();
    final sums = <String, double>{};
    final counts = <String, int>{};
    for (final r in counted.take(20)) {
      try {
        final detail = jsonDecode(r.detailJson);
        final sections = detail is Map ? detail['sections'] : null;
        if (sections is Map) {
          for (final e in sections.entries) {
            final v = e.value;
            if (v is num) {
              sums['${e.key}'] = (sums['${e.key}'] ?? 0) + v.toDouble();
              counts['${e.key}'] = (counts['${e.key}'] ?? 0) + 1;
            }
          }
        }
      } catch (_) {
        // An old or broken detail: the score alone still counts.
      }
    }
    return TestStats(
      count: counted.length,
      passed: counted.where((r) => r.passed).length,
      average: last.isEmpty ? 0 : last.map((r) => r.score).reduce((a, b) => a + b) / last.length,
      recent: last.reversed.map((r) => r.score).toList(),
      skills: {for (final k in sums.keys) k: sums[k]! / counts[k]!},
    );
  }
}

class TestCenterScreen extends ConsumerStatefulWidget {
  const TestCenterScreen({super.key});

  @override
  ConsumerState<TestCenterScreen> createState() => _TestCenterScreenState();
}

class _TestCenterScreenState extends ConsumerState<TestCenterScreen> {
  late final AppServices _services = ref.read(appServicesProvider);
  List<TestResult> _results = const [];
  GrammarBook _grammar = GrammarBook.empty;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await ref.read(activeProfileProvider.future);
    final results = await _services.db.testRepo.forProfile(profile.id);
    final grammar = await _services.grammarBook();
    if (mounted) {
      setState(() {
        _results = results;
        _grammar = grammar;
        _loaded = true;
      });
    }
  }

  ComposerOptions _options() {
    final settings = ref.read(parentSettingsProvider);
    final caps = _services.capabilities.value;
    return ComposerOptions(
      now: DateTime.now(),
      delayReading: settings.delayEnglishReading,
      speechAvailable: caps.speech,
      inkAvailable: caps.ink,
    );
  }

  Future<void> _run(LessonRequest request) async {
    unawaited(_services.speech.stop());
    await context.push(AppRoutes.lesson, extra: request);
    await _load();
  }

  Future<void> _unitTest(Unit unit) => _run(LessonRequest(
        mode: LessonMode.checkup,
        plan: TestBuilder(_services.curriculum).unitTest(unit, options: _options(), random: Random()),
      ));

  Future<void> _levelTest(int level) => _run(LessonRequest(
        mode: LessonMode.checkup,
        plan: TestBuilder(_services.curriculum).levelTest(level, options: _options(), random: Random()),
      ));

  Future<void> _grammarTest(int level) async {
    unawaited(_services.speech.stop());
    final lessons = [
      for (final l in _grammar.lessons)
        if (GrammarBook.levelForStage(l.stage) <= max(1, level)) l.id,
    ];
    await context.push(AppRoutes.grammarLesson, extra: GrammarPracticeArgs.mixed(_grammar, fromLessons: lessons));
    await _load();
  }

  double? _best(String kindA, String target, [String? kindB]) {
    double? best;
    for (final r in _results) {
      if ((r.kind == kindA || r.kind == kindB) && r.targetId == target && (best == null || r.score > best)) {
        best = r.score;
      }
    }
    return best;
  }

  String _name(TestResult r) {
    switch (r.kind) {
      case 'unit':
      case 'checkup':
        if (r.targetId.startsWith('L') && !r.targetId.contains('U')) {
          return '${S.testsLevel} · ${S.testsLevelName(int.tryParse(r.targetId.substring(1)) ?? 0)}';
        }
        final unit = _services.curriculum.unitById(r.targetId);
        return unit == null ? r.targetId : unit.topicVi;
      case 'level':
        return '${S.testsLevel} · ${S.testsLevelName(int.tryParse(r.targetId.substring(1)) ?? 0)}';
      case GrammarPracticeArgs.resultKind:
        if (r.targetId == GrammarPracticeArgs.mixedId) {
          return S.grammarQuiz;
        }
        return _grammar.lesson(r.targetId)?.titleVi ?? S.homeGrammar;
      default:
        return r.targetId;
    }
  }

  static String _emoji(TestResult r) => switch (r.kind) {
        GrammarPracticeArgs.resultKind => '📐',
        'level' => '🏅',
        _ => r.targetId.contains('U') ? '📘' : '🏅',
      };

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(activeProfileProvider).value;
    final level = profile?.level ?? 0;
    final unitIndex = profile?.unitIndex ?? 0;
    final stats = TestStats.of(_results);
    final units = <Unit>[
      for (final u in _services.curriculum.unitsOf(level).take(unitIndex + 1).toList().reversed) u,
      for (var l = level - 1; l >= 0; l--) ..._services.curriculum.unitsOf(l).reversed,
    ];
    final history = _results.where((r) => r.kind != 'placement').take(15).toList();
    return KidScaffold(
      instructionVi: S.testsSpoken,
      showBack: true,
      child: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                const Text(S.testsTitle, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                _StatsCard(stats: stats),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _BigTestCard(
                        emoji: '🏅',
                        title: S.testsLevel,
                        sub: S.testsLevelName(level),
                        best: _best('checkup', 'L$level', 'level'),
                        tint: AppColors.honeySoft,
                        onTap: () => _levelTest(level),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BigTestCard(
                        emoji: '📐',
                        title: S.testsGrammar,
                        sub: S.grammarQuizSub,
                        best: _best(GrammarPracticeArgs.resultKind, GrammarPracticeArgs.mixedId),
                        tint: AppColors.grapeSoft,
                        onTap: () => _grammarTest(level),
                      ),
                    ),
                  ],
                ),
                const SectionTitle(S.testsUnits),
                for (final u in units.take(12))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _UnitRow(
                      unit: u,
                      best: _best('unit', u.id, 'checkup'),
                      onTap: () => _unitTest(u),
                    ),
                  ),
                const SectionTitle(S.testsRecent),
                if (history.isEmpty)
                  const SoftCard(child: Text(S.testsNone, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)))
                else
                  SoftCard(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    child: Column(
                      children: [
                        for (final r in history)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Text(_emoji(r), style: const TextStyle(fontSize: 20)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_name(r),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                                      Text(
                                        '${r.takenAt.day}/${r.takenAt.month}/${r.takenAt.year}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkSoft),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(S.percent(r.score),
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      color: r.passed ? AppColors.leaf : AppColors.honeyDeep,
                                    )),
                                const SizedBox(width: 6),
                                Text(r.passed ? '✅' : '🔁', style: const TextStyle(fontSize: 16)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final TestStats stats;

  @override
  Widget build(BuildContext context) {
    Widget number(String label, String value) => Expanded(
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
            ],
          ),
        );
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              number(S.testsCount, '${stats.count}'),
              number(S.testsPassed, '${stats.passed}'),
              number(S.testsAverage, stats.count == 0 ? '–' : S.percent(stats.average)),
            ],
          ),
          if (stats.recent.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(S.testsTrend, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.inkSoft)),
            const SizedBox(height: 6),
            SizedBox(
              height: 70,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final s in stats.recent)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Container(
                          height: 8 + 62 * s.clamp(0.0, 1.0).toDouble(),
                          decoration: BoxDecoration(
                            color: s >= 0.8 ? AppColors.leaf : (s >= 0.6 ? AppColors.honey : AppColors.berry),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (stats.skills.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(S.testsSkills, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.inkSoft)),
            for (final e in stats.skills.entries)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 84,
                      child: Text(S.testSection(e.key), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    ),
                    Expanded(child: SoftProgress(value: e.value.clamp(0.0, 1.0).toDouble())),
                    SizedBox(
                      width: 48,
                      child: Text(S.percent(e.value),
                          textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _BigTestCard extends StatelessWidget {
  const _BigTestCard({
    required this.emoji,
    required this.title,
    required this.sub,
    required this.best,
    required this.tint,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String sub;
  final double? best;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = best;
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
          Text(b == null ? sub : '${S.grammarBest}: ${S.percent(b)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
        ],
      ),
    );
  }
}

class _UnitRow extends StatelessWidget {
  const _UnitRow({required this.unit, required this.best, required this.onTap});

  final Unit unit;
  final double? best;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = best;
    return SoftCard(
      onTap: onTap,
      semanticLabel: unit.topicVi,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          IconTile('📘', size: 44, color: b == null ? AppColors.skySoft : AppColors.leafSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(S.testsUnitName(unit.number, unit.topicVi),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                Text('${S.testsLevelName(unit.level)} · ${unit.topicEn}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
              ],
            ),
          ),
          Text(b == null ? S.testsTake : S.percent(b),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: b == null ? AppColors.honeyDeep : (b >= 0.8 ? AppColors.leaf : AppColors.honeyDeep),
              )),
          const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
        ],
      ),
    );
  }
}
