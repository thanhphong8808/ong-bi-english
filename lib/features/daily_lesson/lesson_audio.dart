// lib/features/daily_lesson/lesson_audio.dart
//
// Decides which fixed sentences to synthesise ahead of time. Kokoro runs on
// the phone CPU, so the current lesson and the next three lessons are
// rendered in the background and later play instantly from the cache.
import '../../core/config/app_config.dart';
import '../../core/services/audio_request.dart';
import '../../core/services/english_voice.dart';
import '../../curriculum/lesson_plan.dart';
import '../../curriculum/models.dart';
import '../../curriculum/progress_snapshot.dart';
import '../../l10n/strings_vi.dart';
import '../speak/pron_drills.dart';

class LessonAudio {
  const LessonAudio._();

  /// Every fixed Vietnamese line Bi says in kid mode.
  static List<AudioRequest> instructions() => [
        for (final line in S.spokenInstructions) AudioRequest.vi(line),
        for (final line in S.praiseLines) AudioRequest.vi(line),
      ];

  static List<AudioRequest> _item(Item item, EnglishVoice voice, double speed) => [
        AudioRequest.en(item.en, voice: voice, speed: speed),
        if (item.exampleEn.isNotEmpty) AudioRequest.en(item.exampleEn, voice: voice, speed: speed),
        if (item.vi.isNotEmpty) AudioRequest.vi('${S.meaningPrefix} ${item.vi}'),
      ];

  /// Audio for one lesson, in the order it will be needed.
  static List<AudioRequest> forPlan(
    LessonPlan plan,
    Curriculum curriculum, {
    required EnglishVoice voice,
    required double speed,
  }) {
    final out = <AudioRequest>[];
    void word(String id) {
      final item = curriculum.item(id);
      if (item != null) {
        out.add(AudioRequest.en(item.en, voice: voice, speed: speed));
      }
    }

    for (final step in plan.steps) {
      switch (step) {
        case PickImageStep() || PickMeaningStep() || BubbleStep() || PickWordStep():
          word(step.itemId);
        case ColorStep():
          final item = curriculum.item(step.itemId);
          if (item != null) {
            out.add(AudioRequest.en('Color the ${item.en} ${step.color}.', voice: voice, speed: speed));
          }
        case MatchPairsStep():
          step.itemIds.forEach(word);
        case PresentItemStep():
          final item = curriculum.item(step.itemId);
          if (item != null) {
            out.addAll(_item(item, voice, speed));
            out.add(AudioRequest.en(item.en, voice: voice, speed: AppConfig.slowSpeechRate));
            if (item.syllables.length > 1) {
              out.add(AudioRequest.en(item.syllables.join(', '), voice: voice, speed: AppConfig.slowSpeechRate));
            }
          }
        case PhonicsStep():
          final item = curriculum.item(step.itemId);
          if (item != null) {
            if (item.tipVi.isNotEmpty) {
              out.add(AudioRequest.vi(item.tipVi));
            }
            for (final w in item.soundWords) {
              out.add(AudioRequest.en(w, voice: voice, speed: speed));
            }
          }
        case LetterSoundStep():
          final item = curriculum.item(step.itemId);
          if (item != null && item.soundWords.isNotEmpty) {
            out.add(AudioRequest.en(item.soundWords.join(', '), voice: voice, speed: speed));
          }
        case SayStep():
          out.add(AudioRequest.en(step.text, voice: voice, speed: speed));
        case AnswerStep():
          out.add(AudioRequest.en(step.questionEn, voice: voice, speed: speed));
        case DictationStep():
          out.add(AudioRequest.en(step.text, voice: voice, speed: speed));
        case WordBuilderStep():
          out.add(AudioRequest.en(step.word, voice: voice, speed: speed));
        case TrueFalseStep() || FillBlankStep() || TraceStep() || WriteLetterStep() || CopyWordStep():
          break;
        case WriteSentencesStep() || ReadingStep():
          break;
        case PronDrillStep():
          final drill = pronDrills[step.focus];
          if (drill != null) {
            out.add(AudioRequest.vi(drill.tipVi));
            for (final p in drill.practice.take(3)) {
              out.add(AudioRequest.en(p, voice: voice, speed: speed));
            }
          }
        case DialogueStep():
          final dialogue = curriculum.dialogue(step.dialogueId);
          if (dialogue != null) {
            for (final line in dialogue.lines) {
              final first = dialogue.roles.isNotEmpty && line.role == dialogue.roles.first;
              out.add(AudioRequest.en(line.en, voice: first ? voice : voice.partner, speed: speed));
            }
          }
      }
    }
    return out;
  }

  /// The words and dialogues of the next few lessons of the current unit.
  static List<AudioRequest> upcoming(
    Curriculum curriculum,
    int level,
    ProgressSnapshot snapshot, {
    required EnglishVoice voice,
    required double speed,
  }) {
    final perLesson = AppConfig.lessonMix[level.clamp(0, AppConfig.lessonMix.length - 1)][2];
    final budget = perLesson * AppConfig.audioPrewarmLessons;
    final out = <AudioRequest>[];
    var count = 0;
    for (final unit in curriculum.unitsOf(level)) {
      if (snapshot.unit(unit.id).passed) {
        continue;
      }
      for (final item in unit.items) {
        if (snapshot.introduced(item.id)) {
          continue;
        }
        out.addAll(_item(item, voice, speed));
        count++;
        if (count >= budget) {
          return out;
        }
      }
      for (final dialogue in unit.dialogues) {
        for (final line in dialogue.lines) {
          final first = dialogue.roles.isNotEmpty && line.role == dialogue.roles.first;
          out.add(AudioRequest.en(line.en, voice: first ? voice : voice.partner, speed: speed));
        }
      }
    }
    return out;
  }
}
