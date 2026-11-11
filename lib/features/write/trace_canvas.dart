// lib/features/write/trace_canvas.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../curriculum/letter_strokes.dart';
import 'ink_painting.dart';

/// Tracing surface for one letter: dotted model, numbered start dots with
/// arrows, blinking start point, smoothed ink. Reports the child's strokes in
/// "band" coordinates (see LetterStrokes) after a short pause.
class TraceCanvas extends StatefulWidget {
  const TraceCanvas({super.key, required this.template, required this.onPause, this.enabled = true});

  final LetterTemplate template;

  /// Called ~1 s after the child lifts the finger, with all strokes so far.
  final void Function(List<List<P>> strokes) onPause;
  final bool enabled;

  @override
  State<TraceCanvas> createState() => TraceCanvasState();
}

class TraceCanvasState extends State<TraceCanvas> with SingleTickerProviderStateMixin {
  final List<List<InkSample>> _strokes = [];
  Timer? _pause;
  Size _size = Size.zero;
  late final AnimationController _blink =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);

  @override
  void dispose() {
    _pause?.cancel();
    _blink.dispose();
    super.dispose();
  }

  void clear() {
    _pause?.cancel();
    setState(_strokes.clear);
  }

  bool get hasInk => _strokes.isNotEmpty;

  _Frame get _frame => _Frame.of(_size, widget.template);

  List<List<P>> strokesInBands() {
    final f = _frame;
    return [
      for (final stroke in _strokes)
        [for (final s in stroke) f.toBands(s.position)],
    ];
  }

  void _down(PointerDownEvent e) {
    if (!widget.enabled) {
      return;
    }
    _pause?.cancel();
    setState(() => _strokes.add([InkSample(e.localPosition, e.timeStamp.inMilliseconds, _pressure(e))]));
  }

  void _move(PointerMoveEvent e) {
    if (!widget.enabled || _strokes.isEmpty) {
      return;
    }
    setState(() => _strokes.last.add(InkSample(e.localPosition, e.timeStamp.inMilliseconds, _pressure(e))));
  }

  void _up(PointerUpEvent e) {
    if (!widget.enabled) {
      return;
    }
    _pause?.cancel();
    _pause = Timer(const Duration(milliseconds: 1000), () {
      if (mounted && _strokes.isNotEmpty) {
        widget.onPause(strokesInBands());
      }
    });
  }

  static double _pressure(PointerEvent e) {
    if (e.kind != PointerDeviceKind.stylus) {
      return 1.0;
    }
    final range = e.pressureMax - e.pressureMin;
    return range <= 0 ? 1.0 : ((e.pressure - e.pressureMin) / range).clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        return Listener(
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _up,
          child: AnimatedBuilder(
            animation: _blink,
            builder: (context, _) => CustomPaint(
              size: _size,
              painter: _TracePainter(
                template: widget.template,
                strokes: _strokes,
                blink: _blink.value,
                frame: _frame,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Maps band units to canvas pixels.
class _Frame {
  const _Frame(this.band, this.left, this.top);

  factory _Frame.of(Size size, LetterTemplate template) {
    final band = math.min(size.height / 3.4, size.width / (template.width + 1.2));
    final top = (size.height - band * 3) / 2;
    final left = (size.width - template.width * band) / 2 - template.minX * band;
    return _Frame(band, left, top);
  }

  final double band;
  final double left;
  final double top;

  Offset toPixels(P p) => Offset(left + p.x * band, top + p.y * band);

  P toBands(Offset o) => P((o.dx - left) / band, (o.dy - top) / band);
}

class _TracePainter extends CustomPainter {
  _TracePainter({required this.template, required this.strokes, required this.blink, required this.frame});

  final LetterTemplate template;
  final List<List<InkSample>> strokes;
  final double blink;
  final _Frame frame;

  @override
  void paint(Canvas canvas, Size size) {
    paintGuideLines(canvas, size, frame.top, frame.band);
    final thick = Paint()
      ..color = const Color(0xFFEDE3C8)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = frame.band * 0.42;
    final dotted = Paint()
      ..color = const Color(0xFFB08D57)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;
    final paths = [
      for (final stroke in template.strokes) catmullRomPath([for (final p in stroke) frame.toPixels(p)]),
    ];
    for (final path in paths) {
      canvas.drawPath(path, thick);
    }
    for (final path in paths) {
      paintDashed(canvas, path, dotted);
    }

    // Numbered start points with an arrow showing the direction.
    final next = strokes.length.clamp(0, template.strokes.length - 1);
    for (var i = 0; i < template.strokes.length; i++) {
      final stroke = template.strokes[i];
      final start = frame.toPixels(stroke.first);
      final isNext = i == next && strokes.length < template.strokes.length;
      final radius = frame.band * (isNext ? 0.16 + 0.05 * blink : 0.13);
      canvas.drawCircle(start, radius, Paint()..color = isNext ? AppColors.leaf : const Color(0xFF9CC9A9));
      final text = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(color: AppColors.white, fontSize: radius * 1.2, fontWeight: FontWeight.w900),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, start - Offset(text.width / 2, text.height / 2));
      if (stroke.length >= 2) {
        final a = frame.toPixels(stroke[0]);
        final b = frame.toPixels(stroke[math.min(2, stroke.length - 1)]);
        final dir = b - a;
        if (dir.distance > 1) {
          final unit = dir / dir.distance;
          final tip = a + unit * frame.band * 0.45;
          final side = Offset(-unit.dy, unit.dx) * frame.band * 0.1;
          final arrow = Path()
            ..moveTo(tip.dx, tip.dy)
            ..lineTo(tip.dx - unit.dx * frame.band * 0.16 + side.dx, tip.dy - unit.dy * frame.band * 0.16 + side.dy)
            ..lineTo(tip.dx - unit.dx * frame.band * 0.16 - side.dx, tip.dy - unit.dy * frame.band * 0.16 - side.dy)
            ..close();
          canvas.drawPath(arrow, Paint()..color = AppColors.berry);
        }
      }
    }
    paintInk(canvas, strokes, width: frame.band * 0.2);
  }

  @override
  bool shouldRepaint(covariant _TracePainter old) => true;
}
