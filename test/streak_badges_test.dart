// test/streak_badges_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ong_bi_english/curriculum/streak.dart';
import 'package:ong_bi_english/features/rewards/badges.dart';

void main() {
  // Thursday 12 November 2026.
  final now = DateTime(2026, 11, 12, 9);

  group('honeycomb streak', () {
    test('no study yet', () {
      final s = streakFrom(const [], now);
      expect(s.current, 0);
      expect(s.best, 0);
      expect(s.week, List.filled(7, false));
    });

    test('a run up to yesterday is still alive this morning', () {
      final s = streakFrom(const ['2026-11-09', '2026-11-10', '2026-11-11'], now);
      expect(s.todayDone, isFalse);
      expect(s.current, 3);
      expect(s.best, 3);
    });

    test('studying today extends the run', () {
      final s = streakFrom(const ['2026-11-10', '2026-11-11', '2026-11-12'], now);
      expect(s.todayDone, isTrue);
      expect(s.current, 3);
    });

    test('a missed day starts a new run quietly; the best is kept', () {
      final s = streakFrom(const ['2026-11-01', '2026-11-02', '2026-11-03', '2026-11-04', '2026-11-11'], now);
      expect(s.current, 1);
      expect(s.best, 4);
      expect(s.totalDays, 5);
    });

    test('runs cross month ends', () {
      final s = streakFrom(const ['2026-10-30', '2026-10-31', '2026-11-01'], DateTime(2026, 11, 1, 20));
      expect(s.current, 3);
    });

    test('the week row is Monday to Sunday of this week', () {
      final s = streakFrom(const ['2026-11-08', '2026-11-09', '2026-11-11'], now);
      // Monday 9 and Wednesday 11 are this week; Sunday 8 is last week.
      expect(s.week, [true, false, true, false, false, false, false]);
    });
  });

  group('badges', () {
    BadgeStats stats({
      int lessons = 0,
      int studyDays = 0,
      int bestStreak = 0,
      int words = 0,
      int talks = 0,
      int goodSays = 0,
      int level = 0,
    }) =>
        BadgeStats(
          lessons: lessons,
          studyDays: studyDays,
          bestStreak: bestStreak,
          words: words,
          talks: talks,
          goodSays: goodSays,
          level: level,
        );

    test('nothing done, nothing earned', () {
      expect(earnedBadgeIds(stats()), isEmpty);
    });

    test('milestones unlock in order', () {
      expect(earnedBadgeIds(stats(lessons: 1)), {'first_lesson'});
      expect(earnedBadgeIds(stats(bestStreak: 7)), {'streak_3', 'streak_7'});
      expect(earnedBadgeIds(stats(words: 120)), {'words_50', 'words_100'});
      expect(earnedBadgeIds(stats(talks: 1)), {'talk_first'});
      expect(earnedBadgeIds(stats(level: 2)), {'level_1', 'level_2'});
    });

    test('every badge has a unique id, an emoji and a Vietnamese title', () {
      final ids = <String>{};
      for (final badge in badges) {
        expect(ids.add(badge.id), isTrue, reason: 'duplicate ${badge.id}');
        expect(badge.emoji, isNotEmpty);
        expect(badge.title, isNotEmpty);
        expect(badgeByRewardId(badge.rewardId), same(badge));
        expect(isBadgeReward(badge.rewardId), isTrue);
      }
      final everything = earnedBadgeIds(stats(
        lessons: 9999,
        studyDays: 9999,
        bestStreak: 9999,
        words: 9999,
        talks: 9999,
        goodSays: 9999,
        level: 5,
      ));
      expect(everything, ids, reason: 'every badge must be winnable');
    });
  });
}
