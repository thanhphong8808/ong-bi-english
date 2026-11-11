// lib/features/daily_lesson/activities/activity_factory.dart
import 'package:material_ui/material_ui.dart';

import '../../../curriculum/lesson_plan.dart';
import 'activity_base.dart';
import 'dialogue_activity.dart';
import 'pick_activities.dart';
import 'speak_activities.dart';
import 'write_activities.dart';

/// Builds the activity widget for one lesson step.
Widget buildActivity(LessonStep step, {required StepDone onDone, required bool testMode, Key? key}) {
  switch (step) {
    case PickImageStep():
      return PickImageActivity(key: key, step: step, onDone: onDone, testMode: testMode);
    case PickMeaningStep():
      return PickMeaningActivity(key: key, step: step, onDone: onDone, testMode: testMode);
    case PresentItemStep():
      return PresentItemActivity(key: key, step: step, onDone: onDone, testMode: testMode);
    case PhonicsStep():
      return PhonicsActivity(key: key, step: step, onDone: onDone, testMode: testMode);
    case SayStep():
      return SayActivity(key: key, step: step, onDone: onDone, testMode: testMode);
    case AnswerStep():
      return AnswerActivity(key: key, step: step, onDone: onDone, testMode: testMode);
    case PickWordStep():
      return PickWordActivity(key: key, step: step, onDone: onDone, testMode: testMode);
    case MatchPairsStep():
      return MatchPairsActivity(key: key, step: step, onDone: onDone, testMode: testMode);
    case BubbleStep():
      return BubbleActivity(key: key, step: step, onDone: onDone, testMode: testMode);
    case ColorStep():
      return ColorActivity(key: key, step: step, onDone: onDone, testMode: testMode);
    case WordBuilderStep():
      return WordBuilderActivity(key: key, step: step, onDone: onDone, testMode: testMode);
    case TrueFalseStep():
      return TrueFalseActivity(key: key, step: step, onDone: onDone, testMode: testMode);
    case FillBlankStep():
      return FillBlankActivity(key: key, step: step, onDone: onDone, testMode: testMode);
    case LetterSoundStep():
      return LetterSoundActivity(key: key, step: step, onDone: onDone, testMode: testMode);
    case TraceStep():
      return TraceActivity(key: key, step: step, onDone: onDone, testMode: testMode);
    case WriteLetterStep():
      return WriteLetterActivity(key: key, step: step, onDone: onDone, testMode: testMode);
    case CopyWordStep():
      return CopyWordActivity(key: key, step: step, onDone: onDone, testMode: testMode);
    case DictationStep():
      return DictationActivity(key: key, step: step, onDone: onDone, testMode: testMode);
    case WriteSentencesStep():
      return WriteSentencesActivity(key: key, step: step, onDone: onDone, testMode: testMode);
    case ReadingStep():
      return ReadingActivity(key: key, step: step, onDone: onDone, testMode: testMode);
    case PronDrillStep():
      return PronDrillActivity(key: key, step: step, onDone: onDone, testMode: testMode);
    case DialogueStep():
      return DialogueActivity(key: key, step: step, onDone: onDone, testMode: testMode);
  }
}
