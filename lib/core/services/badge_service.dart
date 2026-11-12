// lib/core/services/badge_service.dart
import '../../curriculum/streak.dart';
import '../../features/rewards/badges.dart';
import '../config/app_config.dart';
import '../db/app_database.dart';
import '../db/repositories.dart';

/// Streak and badges of one child, read from the database.
class BadgeService {
  BadgeService(this.db);

  final AppDatabase db;

  Future<StreakInfo> streak(int profileId, {DateTime? now}) async {
    final days = await db.studyRepo.activeDays(profileId);
    return streakFrom(days, now ?? DateTime.now());
  }

  /// Gives every badge the child now deserves and does not have yet, and
  /// returns those new badges (to celebrate them once).
  Future<List<MilestoneBadge>> awardNew(Profile profile, {DateTime? now}) async {
    final id = profile.id;
    final streakInfo = await streak(id, now: now);
    final stats = BadgeStats(
      lessons: await db.studyRepo.totalLessons(id),
      studyDays: streakInfo.totalDays,
      bestStreak: streakInfo.best,
      words: await db.progressRepo.wordsSeen(id),
      talks: await db.chatLogRepo.childSessions(id),
      goodSays: await db.progressRepo.goodSays(id, AppConfig.goodSayScore),
      level: profile.level,
    );
    final owned = {for (final reward in await db.rewardRepo.forProfile(id)) reward.stickerId};
    final earned = earnedBadgeIds(stats);
    final fresh = <MilestoneBadge>[];
    for (final badge in badges) {
      if (earned.contains(badge.id) && !owned.contains(badge.rewardId)) {
        await db.rewardRepo.add(id, badge.rewardId);
        fresh.add(badge);
      }
    }
    return fresh;
  }
}
