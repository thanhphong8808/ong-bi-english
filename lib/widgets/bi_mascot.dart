// lib/widgets/bi_mascot.dart
import 'dart:math' as math;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

/// Bi's five moods. Each maps to one SVG in assets/svg/.
enum BiMood { happy, listening, thinking, cheering, sleeping }

/// Outfit layers by level: Bi grows up and dresses up as the child levels up.
const List<List<String>> biOutfits = [
  [],
  ['cap'],
  ['cap', 'bow'],
  ['glasses', 'bow'],
  ['glasses', 'scarf'],
  ['grad', 'glasses', 'scarf'],
];

/// The bee mascot with a gentle hover animation.
class BiMascot extends StatefulWidget {
  const BiMascot({super.key, this.mood = BiMood.happy, this.size = 220, this.level = 0});

  final BiMood mood;
  final double size;

  /// Child's level: picks the outfit and makes Bi a little bigger.
  final int level;

  @override
  State<BiMascot> createState() => _BiMascotState();
}

class _BiMascotState extends State<BiMascot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sleeping = widget.mood == BiMood.sleeping;
    final cheering = widget.mood == BiMood.cheering;
    final level = widget.level.clamp(0, biOutfits.length - 1).toInt();
    final grow = 0.86 + level * 0.028;
    final size = widget.size;
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final phase = _controller.value * 2 * math.pi;
          // Sleeping Bi breathes slowly; cheering Bi bounces higher.
          final amplitude = sleeping ? 2.0 : (cheering ? 12.0 : 6.0);
          final speed = cheering ? 2.0 : 1.0;
          final dy = math.sin(phase * speed) * amplitude;
          final tilt = sleeping ? 0.0 : math.sin(phase) * 0.03;
          return Transform.translate(
            offset: Offset(0, dy),
            child: Transform.rotate(angle: tilt, child: child),
          );
        },
        child: Transform.scale(
          scale: grow,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Stack(
              key: ValueKey<String>('${widget.mood.name}-$level'),
              children: [
                SvgPicture.asset('assets/svg/bi_${widget.mood.name}.svg', width: size, height: size),
                if (!sleeping)
                  for (final layer in biOutfits[level])
                    SvgPicture.asset('assets/svg/outfit_$layer.svg', width: size, height: size),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
