// lib/widgets/motion.dart
import 'package:material_ui/material_ui.dart';

/// Keeps a decorative looping animation running, except when the phone asks
/// for reduced motion (animations switched off in Android's accessibility
/// or developer settings). Call from didChangeDependencies.
///
/// [stillValue] is where the animation rests while stopped.
void loopUnlessReducedMotion(
  AnimationController controller,
  BuildContext context, {
  bool reverse = false,
  double stillValue = 0,
}) {
  final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  if (reduce) {
    controller
      ..stop()
      ..value = stillValue;
  } else if (!controller.isAnimating) {
    controller.repeat(reverse: reverse);
  }
}
