// test/study_clock_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ong_bi_english/core/db/repositories.dart';
import 'package:ong_bi_english/core/services/parent_settings.dart';
import 'package:ong_bi_english/core/services/study_clock.dart';

class FakeStore implements StudyStore {
  final Map<String, int> seconds = {};

  @override
  Future<void> addSeconds(int profileId, DateTime when, int value) async {
    final key = StudyRepo.dayKey(when);
    seconds[key] = (seconds[key] ?? 0) + value;
  }

  @override
  Future<StudyDay> day(int profileId, DateTime when) async {
    final key = StudyRepo.dayKey(when);
    return StudyDay(day: key, seconds: seconds[key] ?? 0, lessonsDone: 0);
  }

  @override
  Future<void> resetDay(int profileId, DateTime when) async {
    seconds[StudyRepo.dayKey(when)] = 0;
  }
}

void main() {
  late DateTime now;
  late FakeStore store;
  late StudyClock clock;

  setUp(() async {
    now = DateTime(2026, 11, 12, 7, 0);
    store = FakeStore();
    clock = StudyClock(store, clock: () => now);
    await clock.load(1);
  });

  tearDown(() => clock.dispose());

  void advance(int seconds) {
    now = now.add(Duration(seconds: seconds));
    clock.tick();
  }

  test('counts time on screen in ticks', () {
    clock.start();
    for (var i = 0; i < 8; i++) {
      advance(15);
    }
    expect(clock.todaySeconds.value, 120);
    clock.stop();
    expect(store.seconds['2026-11-12'], 120);
  });

  test('a phone left asleep on a lesson does not count hours', () {
    clock.start();
    advance(15);
    advance(8 * 3600); // screen off all night, then the next tick
    expect(clock.todaySeconds.value, 15 + StudyClock.maxTickSeconds);
  });

  test('nothing counts while the app is in the background', () {
    clock.start();
    advance(15);
    clock.pause();
    advance(3600);
    advance(3600);
    clock.resume();
    advance(15);
    expect(clock.todaySeconds.value, 30);
  });

  test('a new day starts from zero even if the app stayed open', () async {
    clock.start();
    for (var i = 0; i < 20; i++) {
      advance(15);
    }
    expect(clock.todaySeconds.value, 300);
    clock.stop();
    now = DateTime(2026, 11, 13, 7, 0);
    const settings = ParentSettings(dailyLimitMinutes: 5);
    expect(clock.lock(settings), StudyLock.none);
    expect(clock.todaySeconds.value, 0);
  });

  test('the daily limit locks and the parent reset unlocks', () async {
    const settings = ParentSettings(dailyLimitMinutes: 5);
    clock.start();
    for (var i = 0; i < 21; i++) {
      advance(15);
    }
    expect(clock.lock(settings), StudyLock.dailyLimit);
    await clock.resetToday();
    expect(clock.todaySeconds.value, 0);
    expect(store.seconds['2026-11-12'], 0);
    expect(clock.lock(settings), StudyLock.none);
    advance(15);
    expect(clock.todaySeconds.value, 15);
  });

  test('a fresh load reads what was stored for today', () async {
    store.seconds['2026-11-12'] = 600;
    final other = StudyClock(store, clock: () => now);
    await other.load(1);
    expect(other.todaySeconds.value, 600);
    other.dispose();
  });
}
