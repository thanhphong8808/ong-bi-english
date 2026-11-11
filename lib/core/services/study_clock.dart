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
class StudyClock {
  StudyClock(this.studyRepo);

  final StudyRepo studyRepo;

  /// Seconds studied today by the active profile.
  final ValueNotifier<int> todaySeconds = ValueNotifier<int>(0);

  Timer? _timer;
  int _profileId = 0;
  DateTime? _lastTick;
  int _activeScreens = 0;
  bool _paused = false;

  /// The day [todaySeconds] belongs to (local date, yyyy-mm-dd).
  String _day = '';

  /// Longest stretch one tick may add. Anything longer means the phone slept
  /// or the app sat in the background, which is not study time.
  static const int _maxTickSeconds = AppConfig.studyTickSeconds * 2;

  Future<void> load(int profileId) async {
    _profileId = profileId;
    final now = DateTime.now();
    final day = await studyRepo.day(profileId, now);
    todaySeconds.value = day.seconds;
    _day = StudyRepo.dayKey(now);
  }

  /// The app went to the background: stop counting until [resume].
  void pause() {
    _tick();
    _paused = true;
    _lastTick = null;
  }

  /// The app is visible again.
  void resume() {
    _paused = false;
    if (_activeScreens > 0) {
      _lastTick = DateTime.now();
    }
  }

  /// Starts a new day's count when the date changed (the app may have stayed
  /// open overnight, so yesterday's minutes must not lock today).
  void _rollOver(DateTime now) {
    final key = StudyRepo.dayKey(now);
    if (key != _day) {
      _day = key;
      todaySeconds.value = 0;
    }
  }

  /// A learning screen opened. Nested screens are counted once.
  void start() {
    _activeScreens++;
    if (_timer != null) {
      return;
    }
    _lastTick = _paused ? null : DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: AppConfig.studyTickSeconds), (_) => _tick());
  }

  /// A learning screen closed.
  void stop() {
    if (_activeScreens > 0) {
      _activeScreens--;
    }
    if (_activeScreens == 0) {
      _tick();
      _timer?.cancel();
      _timer = null;
      _lastTick = null;
    }
  }

  void _tick() {
    final last = _lastTick;
    if (last == null) {
      return;
    }
    final now = DateTime.now();
    final elapsed = now.difference(last).inSeconds;
    if (elapsed <= 0) {
      return;
    }
    _lastTick = now;
    _rollOver(now);
    final seconds = elapsed > _maxTickSeconds ? _maxTickSeconds : elapsed;
    todaySeconds.value += seconds;
    unawaited(studyRepo.addSeconds(_profileId, now, seconds).catchError((Object _) {}));
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
    final now = DateTime.now();
    _rollOver(now);
    return lockFor(settings, todaySeconds.value, now);
  }

  void dispose() {
    _timer?.cancel();
    todaySeconds.dispose();
  }
}
