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

  Future<void> load(int profileId) async {
    _profileId = profileId;
    final day = await studyRepo.day(profileId, DateTime.now());
    todaySeconds.value = day.seconds;
  }

  /// A learning screen opened. Nested screens are counted once.
  void start() {
    _activeScreens++;
    if (_timer != null) {
      return;
    }
    _lastTick = DateTime.now();
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
    final seconds = now.difference(last).inSeconds;
    if (seconds <= 0) {
      return;
    }
    _lastTick = now;
    // A new day resets the counter shown to the child.
    if (now.day != last.day) {
      todaySeconds.value = 0;
    }
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

  StudyLock lock(ParentSettings settings) => lockFor(settings, todaySeconds.value, DateTime.now());

  void dispose() {
    _timer?.cancel();
    todaySeconds.dispose();
  }
}
