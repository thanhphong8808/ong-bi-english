// lib/features/rewards/badges.dart
//
// Milestone badges ("huy hiệu"). Earned from what the child has done, never
// bought, never lost. Pure Dart.

class MilestoneBadge {
  const MilestoneBadge(this.id, this.emoji, this.title);

  final String id;
  final String emoji;

  /// Vietnamese name, also spoken when the badge is won.
  final String title;

  /// Stored in the rewards table with this id.
  String get rewardId => 'badge:$id';
}

/// What badges are computed from.
class BadgeStats {
  const BadgeStats({
    required this.lessons,
    required this.studyDays,
    required this.bestStreak,
    required this.words,
    required this.talks,
    required this.goodSays,
    required this.level,
  });

  final int lessons;
  final int studyDays;
  final int bestStreak;
  final int words;
  final int talks;
  final int goodSays;
  final int level;
}

const List<MilestoneBadge> badges = [
  MilestoneBadge('first_lesson', '🌱', 'Bài học đầu tiên'),
  MilestoneBadge('streak_3', '🔥', 'Học 3 ngày liền'),
  MilestoneBadge('streak_7', '🍯', 'Học 7 ngày liền'),
  MilestoneBadge('streak_30', '👑', 'Học 30 ngày liền'),
  MilestoneBadge('days_10', '🐝', '10 ngày học'),
  MilestoneBadge('days_50', '🌻', '50 ngày học'),
  MilestoneBadge('days_100', '🏆', '100 ngày học'),
  MilestoneBadge('words_50', '📗', 'Biết 50 từ'),
  MilestoneBadge('words_100', '📘', 'Biết 100 từ'),
  MilestoneBadge('words_300', '📙', 'Biết 300 từ'),
  MilestoneBadge('words_1000', '📚', 'Biết 1000 từ'),
  MilestoneBadge('talk_first', '💬', 'Lần đầu trò chuyện với Bi'),
  MilestoneBadge('talk_10', '🗣️', '10 lần trò chuyện với Bi'),
  MilestoneBadge('say_20', '🎤', '20 lần nói thật hay'),
  MilestoneBadge('say_100', '🌟', '100 lần nói thật hay'),
  MilestoneBadge('level_1', '🥉', 'Lên cấp 1'),
  MilestoneBadge('level_2', '🥈', 'Lên cấp 2'),
  MilestoneBadge('level_3', '🥇', 'Lên cấp 3'),
  MilestoneBadge('level_4', '🎖️', 'Lên cấp 4'),
  MilestoneBadge('level_5', '🏅', 'Lên cấp 5'),
];

MilestoneBadge? badgeByRewardId(String rewardId) {
  for (final badge in badges) {
    if (badge.rewardId == rewardId) {
      return badge;
    }
  }
  return null;
}

bool isBadgeReward(String rewardId) => rewardId.startsWith('badge:');

/// Ids of every badge [s] deserves.
Set<String> earnedBadgeIds(BadgeStats s) {
  final earned = <String>{};
  void when(bool condition, String id) {
    if (condition) {
      earned.add(id);
    }
  }

  when(s.lessons >= 1, 'first_lesson');
  when(s.bestStreak >= 3, 'streak_3');
  when(s.bestStreak >= 7, 'streak_7');
  when(s.bestStreak >= 30, 'streak_30');
  when(s.studyDays >= 10, 'days_10');
  when(s.studyDays >= 50, 'days_50');
  when(s.studyDays >= 100, 'days_100');
  when(s.words >= 50, 'words_50');
  when(s.words >= 100, 'words_100');
  when(s.words >= 300, 'words_300');
  when(s.words >= 1000, 'words_1000');
  when(s.talks >= 1, 'talk_first');
  when(s.talks >= 10, 'talk_10');
  when(s.goodSays >= 20, 'say_20');
  when(s.goodSays >= 100, 'say_100');
  for (var level = 1; level <= 5; level++) {
    when(s.level >= level, 'level_$level');
  }
  return earned;
}
