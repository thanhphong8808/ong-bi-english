// lib/features/parent/parent_home_screen.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/db/repositories.dart';
import '../../core/providers.dart';
import '../../curriculum/bi_world.dart';
import '../../curriculum/pocket_phrases.dart';
import '../../l10n/strings_vi.dart';
import '../../widgets/ui_kit.dart';

/// This week at a glance for the parent dashboard.
class _Week {
  const _Week({
    required this.minutes,
    required this.lessons,
    required this.days,
    required this.talkTurns,
    required this.perDay,
    required this.weak,
  });

  final int minutes;
  final int lessons;
  final int days;
  final int talkTurns;

  /// Minutes per day, oldest first, with its weekday label.
  final List<(String, int)> perDay;

  /// Words with the most mistakes: (English, Vietnamese).
  final List<(String, String)> weak;
}

final _weekProvider = FutureProvider.autoDispose<_Week>((ref) async {
  final services = ref.read(appServicesProvider);
  final profile = await ref.watch(activeProfileProvider.future);
  final now = DateTime.now();
  final days = await services.db.studyRepo.recent(profile.id, 7);
  final byDay = {for (final d in days) d.day: d};
  final perDay = <(String, int)>[];
  for (var i = 6; i >= 0; i--) {
    final day = now.subtract(Duration(days: i));
    final row = byDay[StudyRepo.dayKey(day)];
    perDay.add((S.weekDays[day.weekday - 1], ((row?.seconds ?? 0) / 60).round()));
  }
  final turns = await services.db.speechTurnRepo.since(profile.id, now.subtract(const Duration(days: 7)));
  final snapshot = await services.progress.snapshot(profile.id);
  final mistakes = snapshot.allRows.where((r) => r.wrongCount > r.correctCount).toList()
    ..sort((a, b) => (b.wrongCount - b.correctCount).compareTo(a.wrongCount - a.correctCount));
  final weak = <(String, String)>[];
  final seen = <String>{};
  for (final row in mistakes) {
    final item = services.curriculum.item(row.itemId);
    if (item == null || item.isLetter || !seen.add(item.id)) {
      continue;
    }
    weak.add((item.en, item.vi));
    if (weak.length >= 6) {
      break;
    }
  }
  return _Week(
    minutes: days.fold<int>(0, (sum, d) => sum + d.seconds) ~/ 60,
    lessons: days.fold<int>(0, (sum, d) => sum + d.lessonsDone),
    days: days.where((d) => d.seconds > 0).length,
    talkTurns: turns.where((t) => t.source == SpeechTurn.talk).length,
    perDay: perDay,
    weak: weak,
  );
});

/// Entry of the parent area. Reached only through the parent gate.
class ParentHomeScreen extends ConsumerWidget {
  const ParentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(activeProfileProvider).value;
    final week = ref.watch(_weekProvider).value;
    final level = profile?.level ?? 0;
    final weekNumber = BiWorld.dayNumber(DateTime.now()) ~/ 7;
    Widget entry(IconData icon, String title, String route, {Color tint = AppColors.honeySoft}) {
      return ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 22, color: AppColors.ink),
        ),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push(route),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text(S.parentTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (profile != null)
              SoftCard(
                gradient: AppGradients.honey,
                child: Row(
                  children: [
                    const IconTile('🧒', color: AppColors.white, size: 56),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                          Text(S.certificateLevel(profile.level),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    StatPill(emoji: '⭐', text: '${profile.stars}'),
                  ],
                ),
              ),
            const SectionTitle(S.dashOverview),
            if (week == null)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else ...[
              Row(
                children: [
                  Expanded(child: _Stat(emoji: '⏱️', label: S.dashMinutes, value: S.dashMinutesValue(week.minutes), tint: AppColors.honeySoft)),
                  const SizedBox(width: 10),
                  Expanded(child: _Stat(emoji: '📖', label: S.dashLessons, value: '${week.lessons}', tint: AppColors.skySoft)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _Stat(emoji: '📅', label: S.dashDays, value: S.dashDaysValue(week.days), tint: AppColors.leafSoft)),
                  const SizedBox(width: 10),
                  Expanded(child: _Stat(emoji: '💬', label: S.dashTalks, value: '${week.talkTurns}', tint: AppColors.grapeSoft)),
                ],
              ),
              const SizedBox(height: 12),
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(S.dashWeekChart, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    _Bars(days: week.perDay),
                  ],
                ),
              ),
            ],
            const SectionTitle(S.dashTips),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(S.dashTipsIntro, style: TextStyle(fontSize: 14, color: AppColors.inkSoft)),
                  const SizedBox(height: 8),
                  for (final p in PocketPhrases.familyWeek(level, weekNumber))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          IconTile(p.emoji, size: 44),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.en, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                                Text(p.vi, style: const TextStyle(fontSize: 14, color: AppColors.inkSoft)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (week != null) ...[
                    const Divider(height: 22),
                    const Text(S.dashWeak, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    if (week.weak.isEmpty)
                      const Text(S.dashWeakNone, style: TextStyle(fontSize: 14, color: AppColors.inkSoft))
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final w in week.weak)
                            Chip(label: Text('${w.$1} · ${w.$2}')),
                        ],
                      ),
                  ],
                ],
              ),
            ),
            const SectionTitle(S.dashMenu),
            SoftCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  entry(Icons.insights_rounded, S.progressTitle, AppRoutes.parentProgress, tint: AppColors.grapeSoft),
                  entry(Icons.tune_rounded, S.parentSettings, AppRoutes.parentSettings),
                  entry(Icons.menu_book_rounded, S.parentWordsTitle, AppRoutes.parentWords, tint: AppColors.skySoft),
                  entry(Icons.auto_stories_rounded, S.notesTitle, AppRoutes.parentNotes, tint: AppColors.leafSoft),
                  entry(Icons.people_alt_rounded, S.profilesTitle, AppRoutes.parentProfiles, tint: AppColors.berrySoft),
                  entry(Icons.forum_rounded, S.chatLogsTitle, AppRoutes.parentChats, tint: AppColors.skySoft),
                  entry(Icons.save_alt_rounded, S.dataTitle, AppRoutes.parentData),
                  entry(Icons.download_done_rounded, S.parentModels, AppRoutes.parentModels, tint: AppColors.leafSoft),
                  entry(Icons.health_and_safety_outlined, S.parentDiagnostics, AppRoutes.parentDiagnostics,
                      tint: AppColors.berrySoft),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(S.pinningHint, style: TextStyle(fontSize: 14, color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.emoji, required this.label, required this.value, required this.tint});

  final String emoji;
  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          IconTile(emoji, color: tint, size: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Minutes per day as soft rounded bars; today is honey, other days grape.
class _Bars extends StatelessWidget {
  const _Bars({required this.days});

  final List<(String, int)> days;

  @override
  Widget build(BuildContext context) {
    final top = days.fold<int>(1, (m, d) => d.$2 > m ? d.$2 : m);
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${days[i].$2}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Container(
                    width: 22,
                    height: 4 + 96 * days[i].$2 / top,
                    decoration: BoxDecoration(
                      color: i == days.length - 1 ? AppColors.honeyDeep : AppColors.grape.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  EmojiTextLabel(days[i].$1),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Plain day label (kept separate so the bar chart stays light).
class EmojiTextLabel extends StatelessWidget {
  const EmojiTextLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.inkSoft));
}
