// lib/features/home/hello_store.dart
//
// Starts "Chào Bi mỗi ngày" and keeps what it needs between days: when it
// was last done, today's mission (asked about tomorrow), the answers Bi
// notes in its notebook and the pocket phrase practised.
import 'dart:convert';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../core/providers.dart';
import '../../curriculum/bi_notes.dart';
import '../../curriculum/bi_world.dart';
import '../../curriculum/daily_hello.dart';
import '../../curriculum/pocket_phrases.dart';
import '../../curriculum/talk_scripts.dart';
import '../../l10n/strings_vi.dart';
import '../talk_with_bi/talk_home_screen.dart';

/// Today's hello state for the home screen.
class HelloStatus {
  const HelloStatus({required this.doneToday, this.mission});

  final bool doneToday;

  /// The mission given today (shown on the home card once done).
  final HelloMission? mission;
}

class HelloStore {
  const HelloStore._();

  static const String lastKey = 'hello_last';
  static const String missionKey = 'hello_mission';

  static int today() => BiWorld.dayNumber(DateTime.now());

  static Future<HelloStatus> status(AppServices services, int profileId) async {
    final last = await services.db.settingsRepo.read(lastKey, profileId: profileId);
    final saved = _mission(await services.db.settingsRepo.read(missionKey, profileId: profileId));
    final done = last == '${today()}';
    return HelloStatus(
      doneToday: done,
      mission: done && saved != null ? DailyHello.missionById(saved.$1) : null,
    );
  }

  /// (mission id, day given, checked)
  static (String, int, bool)? _mission(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return ('${m['id']}', (m['day'] as num).toInt(), m['checked'] == true);
    } catch (_) {
      return null;
    }
  }

  /// Builds today's hello and opens it. Returns when the child leaves.
  static Future<void> open(BuildContext context, AppServices services, int profileId, String name, int level) async {
    final repo = services.db.settingsRepo;
    final day = today();
    final notesRaw = await repo.read(BiNotes.key, profileId: profileId);
    final notesOff = await repo.read(BiNotes.offKey, profileId: profileId) == '1';
    final notes = BiNotes.decode(notesRaw);
    final pocket = PocketProgress.decode(await repo.read(PocketProgress.key, profileId: profileId));
    final saved = _mission(await repo.read(missionKey, profileId: profileId));
    final toCheck = saved != null && saved.$2 < day && !saved.$3 ? DailyHello.missionById(saved.$1) : null;

    final plan = DailyHello.build(
      childName: name,
      level: level,
      now: DateTime.now(),
      pocket: pocket,
      knownNotes: notesOff ? const {} : notes.keys,
      missionToCheck: toCheck,
    );
    final TalkScript script;
    try {
      script = const TalkParser().parse([plan.text]).scripts.single;
    } catch (_) {
      return;
    }
    var notesChanged = false;
    var checked = false;
    final args = GuidedTalkArgs(
      script: script,
      kidRole: TalkScript.kidRole,
      record: false,
      doneSpokenVi: S.helloDoneSpoken,
      onChoice: (blockId, option) {
        if (blockId == 'mission_check') {
          checked = true;
        }
        final note = plan.notes[option.en];
        if (note != null && !notesOff && notes.put(note.$1, note.$2, day)) {
          notesChanged = true;
        }
      },
      onFinished: () async {
        pocket.answer(plan.phrase.id, good: true, today: day);
        await repo.write(PocketProgress.key, pocket.encode(), profileId: profileId);
        if (notesChanged) {
          await repo.write(BiNotes.key, notes.encode(), profileId: profileId);
        }
        if (toCheck != null && !checked) {
          // Not reached the question: keep yesterday's mission for tomorrow.
          return;
        }
        await repo.write(lastKey, '$day', profileId: profileId);
        await repo.write(
          missionKey,
          jsonEncode({'id': plan.mission.id, 'day': day, 'checked': false}),
          profileId: profileId,
        );
      },
    );
    if (!context.mounted) {
      return;
    }
    await context.push(AppRoutes.talkGuided, extra: args);
  }
}
