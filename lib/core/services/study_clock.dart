// lib/core/services/study_clock.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../db/repositories.dart';
import 'parent_settings.dart';

/// Why kid mode is closed right now.
enum StudyLock { none, dailyLimit, outsideHours }

/// Counts study time while a learning screen is open and decides when Bi
/// "goes to sleep" (daily limit reached or outside the allowed hours).
///
/// Only time on screen counts: the clock pauses when the app goes to the
/// background, one tick never adds more than [maxTickSeconds] (a phone that
/// slept on an open lesson is not studying), and the count starts again
/// when the date changes, even if the app stayed open overnight.
class StudyClock {
  StudyClock(this.store, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final StudyStore store;
  final DateTime Function() _now;

  /// Seconds studied today by the active profile.
  final ValueNotifier<int> todaySeconds = ValueNotifier<int>(0);

  /// Longest stretch one tick may add.
  static const int maxTickSeconds = AppConfig.studyTickSeconds * 2;

  Timer? _timer;
  int _profileId = 0;
  DateTime? _lastTick;
  int _activeScreens = 0;
  bool _paused = false;

  /// The day [todaySeconds] belongs to (local date, yyyy-mm-dd).
  String _day = '';

  Future<void> load(int profileId) async {
    _profileId = profileId;
    final now = _now();
    final day = await store.day(profileId, now);
    todaySeconds.value = day.seconds;
    _day = StudyRepo.dayKey(now);
  }

  /// A learning screen opened. Nested screens are counted once.
  void start() {
    _activeScreens++;
    _lastTick ??= _paused ? null : _now();
    _timer ??= Timer.periodic(const Duration(seconds: AppConfig.studyTickSeconds), (_) => tick());
  }

  /// A learning screen closed.
  void stop() {
    if (_activeScreens > 0) {
      _activeScreens--;
    }
    if (_activeScreens == 0) {
      tick();
      _timer?.cancel();
      _timer = null;
      _lastTick = null;
    }
  }

  /// The app went to the background: stop counting until [resume].
  void pause() {
    tick();
    _paused = true;
    _lastTick = null;
  }

  /// The app is visible again.
  void resume() {
    _paused = false;
    if (_activeScreens > 0) {
      _lastTick = _now();
    }
  }

  /// Parent action: today's count back to zero for the active profile.
  Future<void> resetToday() async {
    final now = _now();
    _rollOver(now);
    todaySeconds.value = 0;
    if (_lastTick != null) {
      _lastTick = now;
    }
    await store.resetDay(_profileId, now);
  }

  /// Adds the time since the last tick (called by the timer).
  @visibleForTesting
  void tick() {
    final last = _lastTick;
    if (last == null) {
      return;
    }
    final now = _now();
    final elapsed = now.difference(last).inSeconds;
    if (elapsed <= 0) {
      return;
    }
    _lastTick = now;
    _rollOver(now);
    final seconds = elapsed > maxTickSeconds ? maxTickSeconds : elapsed;
    todaySeconds.value += seconds;
    unawaited(store.addSeconds(_profileId, now, seconds).catchError((Object _) {}));
  }

  void _rollOver(DateTime now) {
    final key = StudyRepo.dayKey(now);
    if (key != _day) {
      _day = key;
      todaySeconds.value = 0;
    }
  }

  static StudyLock lockFor(ParentSettings settings, int secondsToday, DateTime now) {
    final hour = now.hour;
    final start = settings.studyStartHour;
    final end = settings.studyEndHour;
    final inside = start < end ? hour >= start && hour < end : hour >= start || hour < end;
    if (!inside) {
      return StudyLock.outsideHours;
    }
    if (secondsToday >= settings.dailyLimitMinutes * 60) {
      return StudyLock.dailyLimit;
    }
    return StudyLock.none;
  }

  StudyLock lock(ParentSettings settings) {
    final now = _now();
    _rollOver(now);
    return lockFor(settings, todaySeconds.value, now);
  }

  void dispose() {
    _timer?.cancel();
    todaySeconds.dispose();
  }
}
