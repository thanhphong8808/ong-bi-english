// lib/features/parent/progress_screen.dart
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../core/config/app_config.dart';
import '../../core/db/repositories.dart';
import '../../core/providers.dart';
import '../../curriculum/lesson_composer.dart';
import '../../curriculum/models.dart';
import '../../curriculum/progress_snapshot.dart';
import '../../l10n/strings_vi.dart';
import '../tests/certificate.dart';

class _ProgressData {
  const _ProgressData({
    required this.profile,
    required this.snapshot,
    required this.mastered,
    required this.patterns,
    required this.currentUnit,
    required this.weekly,
    required this.days,
    required this.mistakes,
    required this.tests,
    required this.canDo,
  });

  final Profile profile;
  final ProgressSnapshot snapshot;
  final int mastered;
  final int patterns;
  final Unit? currentUnit;

  /// skill -> scores of the last 4 weeks (oldest first), null when no data.
  final Map<String, List<double?>> weekly;
  final List<StudyDay> days;
  final List<ItemProgressRow> mistakes;
  final List<TestResult> tests;
  final List<String> canDo;
}

final _progressProvider = FutureProvider.autoDispose<_ProgressData>((ref) async {
  final services = ref.watch(appServicesProvider);
  final profile = await ref.watch(activeProfileProvider.future);
  final snapshot = await services.progress.snapshot(profile.id);
  final curriculum = services.curriculum;
  final now = DateTime.now();
  final attempts = await services.db.progressRepo.attemptsSince(profile.id, now.subtract(const Duration(days: 28)));
  final weekly = <String, List<double?>>{};
  for (final skill in const ['listen', 'speak', 'read', 'write']) {
    final weeks = <double?>[];
    for (var w = 3; w >= 0; w--) {
      final start = now.subtract(Duration(days: 7 * (w + 1)));
      final end = now.subtract(Duration(days: 7 * w));
      final scores = [
        for (final a in attempts)
          if (a.skill == skill && a.at.isAfter(start) && !a.at.isAfter(end)) a.correct ? 1.0 : 0.0,
      ];
      weeks.add(scores.isEmpty ? null : scores.reduce((x, y) => x + y) / scores.length);
    }
    weekly[skill] = weeks;
  }
  final passedUnits = [
    for (final unit in curriculum.units)
      if (snapshot.unit(unit.id).passed) unit,
  ];
  final mistakes = snapshot.allRows.where((r) => r.wrongCount > 0).toList()
    ..sort((a, b) => b.wrongCount.compareTo(a.wrongCount));
  return _ProgressData(
    profile: profile,
    snapshot: snapshot,
    mastered: services.progress.masteredCount(snapshot, speechAvailable: services.capabilities.value.speech),
    patterns: passedUnits.fold<int>(0, (sum, u) => sum + u.patterns.length),
    currentUnit: LessonComposer(curriculum: curriculum).currentUnit(profile.level, snapshot),
    weekly: weekly,
    days: await services.db.studyRepo.recent(profile.id, 14),
    mistakes: mistakes.take(12).toList(),
    tests: await services.db.testRepo.forProfile(profile.id),
    canDo: [for (final u in passedUnits.reversed.take(6)) ...u.canDoVi],
  );
});

/// Parent dashboard: level, words learned, weekly skills, time, mistakes, tests.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  Future<void> _saveCertificate(BuildContext context, WidgetRef ref, Profile profile, int level) async {
    final services = ref.read(appServicesProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await renderCertificate(childName: profile.name, level: level, date: DateTime.now());
      final path = await services.files.saveToDownloads(
        name: 'ongbi-giay-khen-cap-$level-${DateTime.now().millisecondsSinceEpoch}.png',
        mime: 'image/png',
        bytes: bytes,
      );
      messenger.showSnackBar(SnackBar(content: Text('${S.certificateSaved}\n$path')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text(S.certificateFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_progressProvider);
    final curriculum = ref.watch(appServicesProvider).curriculum;
    return Scaffold(
      appBar: AppBar(title: const Text(S.progressTitle)),
      body: SafeArea(
        child: data.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (d) {
            final unit = d.currentUnit;
            final unitsInLevel = curriculum.unitsOf(d.profile.level).length;
            final title = Theme.of(context).textTheme.titleMedium;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(S.certificateLevel(d.profile.level), style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(unit == null
                            ? S.levelTestReady
                            : S.currentUnit(unit.number, unitsInLevel, unit.topicVi)),
                        const SizedBox(height: 8),
                        Text(S.masteredSummary(d.mastered, d.snapshot.byItem.length, d.patterns)),
                        Text(S.starsSummary(d.profile.stars)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(S.skillsWeekly, style: title),
                const SizedBox(height: 8),
                SizedBox(height: 180, child: _SkillChart(weekly: d.weekly)),
                const SizedBox(height: 16),
                Text(S.minutesDaily, style: title),
                const SizedBox(height: 8),
                SizedBox(height: 150, child: _MinutesChart(days: d.days)),
                if (d.canDo.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(S.canDoTitle, style: title),
                  for (final line in d.canDo) ListTile(dense: true, leading: const Icon(Icons.check_circle_outline), title: Text(line)),
                ],
                const SizedBox(height: 16),
                Text(S.frequentMistakes, style: title),
                if (d.mistakes.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text(S.noMistakes)),
                for (final row in d.mistakes)
                  ListTile(
                    dense: true,
                    title: Text(curriculum.item(row.itemId)?.en ?? row.itemId),
                    subtitle: Text('${curriculum.item(row.itemId)?.vi ?? ''} · ${S.skillName(row.skill)}'),
                    trailing: Text(S.wrongTimes(row.wrongCount)),
                  ),
                const SizedBox(height: 16),
                Text(S.testsHistory, style: title),
                if (d.tests.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text(S.noTests)),
                for (final t in d.tests) _testTile(context, ref, d.profile, t),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _testTile(BuildContext context, WidgetRef ref, Profile profile, TestResult t) {
    final curriculum = ref.read(appServicesProvider).curriculum;
    final weak = <String>[];
    try {
      final detail = jsonDecode(t.detailJson);
      final sections = detail is Map<String, dynamic> ? detail['sections'] : null;
      if (sections is Map<String, dynamic>) {
        for (final e in sections.entries) {
          final value = (e.value as num?)?.toDouble() ?? 1;
          if (value < AppConfig.levelTestSectionFloor) {
            weak.add('${S.sectionLabel(e.key)} ${(value * 100).round()}%');
          }
        }
      }
    } catch (_) {
      // Old or malformed detail: show the summary only.
    }
    final name = switch (t.kind) {
      'unit' => '${S.unitTestLabel} · ${curriculum.unitById(t.targetId)?.topicVi ?? t.targetId}',
      'level' => '${S.levelTestLabel} · ${t.targetId}',
      _ => S.placementLabel,
    };
    final passedLevel = t.kind == 'level' && t.passed;
    return ListTile(
      leading: Icon(t.passed ? Icons.emoji_events_rounded : Icons.replay_rounded,
          color: t.passed ? AppColors.honeyDeep : AppColors.ink),
      title: Text(name),
      subtitle: Text([
        '${(t.score * 100).round()}% · ${t.takenAt.day}/${t.takenAt.month}/${t.takenAt.year}',
        if (weak.isNotEmpty) '${S.weakSections}: ${weak.join(', ')}',
      ].join('\n')),
      trailing: passedLevel
          ? IconButton(
              tooltip: S.certificateSave,
              icon: const Icon(Icons.workspace_premium_rounded),
              onPressed: () => _saveCertificate(context, ref, profile, int.tryParse(t.targetId.substring(1)) ?? 0),
            )
          : null,
    );
  }
}

class _SkillChart extends StatelessWidget {
  const _SkillChart({required this.weekly});

  final Map<String, List<double?>> weekly;

  static const _colors = {
    'listen': AppColors.sky,
    'speak': AppColors.berry,
    'read': AppColors.leaf,
    'write': AppColors.grape,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: CustomPaint(size: Size.infinite, painter: _SkillPainter(weekly))),
        const SizedBox(height: 6),
        Wrap(
          spacing: 14,
          children: [
            for (final e in _colors.entries)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 14, height: 14, color: e.value),
                  const SizedBox(width: 4),
                  Text(S.skillName(e.key)),
                ],
              ),
            const Text(S.lastFourWeeks, style: TextStyle(fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

class _SkillPainter extends CustomPainter {
  _SkillPainter(this.weekly);

  final Map<String, List<double?>> weekly;

  @override
  void paint(Canvas canvas, Size size) {
    final axis = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), axis);
    }
    final groupWidth = size.width / 4;
    final barWidth = groupWidth / 6;
    var s = 0;
    for (final entry in weekly.entries) {
      final paint = Paint()..color = _SkillChart._colors[entry.key] ?? AppColors.ink;
      for (var w = 0; w < entry.value.length; w++) {
        final v = entry.value[w];
        if (v == null) {
          continue;
        }
        final x = groupWidth * w + barWidth * (s + 1);
        final h = math.max(2.0, size.height * v);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, size.height - h, barWidth * 0.9, h), const Radius.circular(3)),
          paint,
        );
      }
      s++;
    }
  }

  @override
  bool shouldRepaint(covariant _SkillPainter old) => true;
}

class _MinutesChart extends StatelessWidget {
  const _MinutesChart({required this.days});

  final List<StudyDay> days;

  @override
  Widget build(BuildContext context) {
    final byDay = {for (final d in days) d.day: d.seconds ~/ 60};
    final now = DateTime.now();
    final keys = [for (var i = 13; i >= 0; i--) StudyRepo.dayKey(now.subtract(Duration(days: i)))];
    final values = [for (final k in keys) byDay[k] ?? 0];
    final top = math.max(20, values.fold<int>(0, math.max));
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth / keys.length;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < keys.length; i++)
              SizedBox(
                width: width,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${values[i]}', style: const TextStyle(fontSize: 10)),
                    Container(
                      height: (box.maxHeight - 34) * values[i] / top,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(color: AppColors.honeyDeep, borderRadius: BorderRadius.circular(3)),
                    ),
                    Text(keys[i].substring(8), style: const TextStyle(fontSize: 10)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
