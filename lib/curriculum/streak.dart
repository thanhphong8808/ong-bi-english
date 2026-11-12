// lib/curriculum/streak.dart
//
// The honeycomb of study days. Gentle by design: a missed day is never
// announced or punished. Today still counts as "alive" until midnight, so
// the streak does not drop to zero in the morning before the child studies.
// Pure Dart.

/// Study-day facts shown on the home screen and used for badges.
class StreakInfo {
  const StreakInfo({
    required this.current,
    required this.best,
    required this.totalDays,
    required this.week,
    required this.todayDone,
  });

  static const StreakInfo none = StreakInfo(
    current: 0,
    best: 0,
    totalDays: 0,
    week: [false, false, false, false, false, false, false],
    todayDone: false,
  );

  /// Consecutive study days up to today (or up to yesterday while today is
  /// not studied yet).
  final int current;

  /// Longest run ever.
  final int best;

  /// All study days.
  final int totalDays;

  /// This week, Monday to Sunday: studied or not.
  final List<bool> week;

  final bool todayDone;
}

String dayKeyOf(DateTime time) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)}';
}

DateTime _date(DateTime t) => DateTime(t.year, t.month, t.day);

/// Builds [StreakInfo] from the study days (yyyy-mm-dd keys).
StreakInfo streakFrom(Iterable<String> studyDays, DateTime now) {
  final days = studyDays.toSet();
  if (days.isEmpty) {
    return StreakInfo.none;
  }
  final today = _date(now);
  final todayDone = days.contains(dayKeyOf(today));

  // DateTime(y, m, d - n) stays correct across months and daylight saving.
  DateTime back(DateTime from, int n) => DateTime(from.year, from.month, from.day - n);

  var current = 0;
  var cursor = todayDone ? today : back(today, 1);
  while (days.contains(dayKeyOf(cursor))) {
    current++;
    cursor = back(cursor, 1);
  }

  final sorted = days.map(DateTime.parse).map(_date).toList()..sort();
  var best = 0;
  var run = 0;
  DateTime? previous;
  for (final day in sorted) {
    if (previous != null && back(day, 1) == previous) {
      run++;
    } else {
      run = 1;
    }
    if (run > best) {
      best = run;
    }
    previous = day;
  }

  final monday = back(today, today.weekday - DateTime.monday);
  final week = [for (var i = 0; i < 7; i++) days.contains(dayKeyOf(DateTime(monday.year, monday.month, monday.day + i)))];

  return StreakInfo(current: current, best: best, totalDays: days.length, week: week, todayDone: todayDone);
}
