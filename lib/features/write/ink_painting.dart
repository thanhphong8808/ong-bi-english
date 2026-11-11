// lib/features/write/ink_painting.dart
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';

/// One sampled point of the child's ink, in canvas pixels.
class InkSample {
  const InkSample(this.position, this.timeMs, this.pressure);

  final Offset position;
  final int timeMs;

  /// 0..1 from the S Pen; 1.0 for a finger.
  final double pressure;
}

/// Smooth path through the points (Catmull-Rom spline converted to cubic
/// Bézier segments).
Path catmullRomPath(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) {
    return path;
  }
  path.moveTo(points.first.dx, points.first.dy);
  if (points.length == 1) {
    path.lineTo(points.first.dx + 0.1, points.first.dy + 0.1);
    return path;
  }
  for (var i = 0; i < points.length - 1; i++) {
    final p0 = i == 0 ? points[i] : points[i - 1];
    final p1 = points[i];
    final p2 = points[i + 1];
    final p3 = i + 2 < points.length ? points[i + 2] : p2;
    final c1 = p1 + (p2 - p0) / 6;
    final c2 = p2 - (p3 - p1) / 6;
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  return path;
}

/// Paints the four-line handwriting grid (like a Vietnamese exercise book).
void paintGuideLines(Canvas canvas, Size size, double top, double band) {
  final strong = Paint()
    ..color = const Color(0xFF7EA6E0)
    ..strokeWidth = 2.5;
  final light = Paint()
    ..color = const Color(0xFFB9CFF0)
    ..strokeWidth = 2;
  for (var i = 0; i <= 3; i++) {
    final y = top + band * i;
    if (i == 1) {
      // The middle line is dashed.
      for (var x = 0.0; x < size.width; x += 18) {
        canvas.drawLine(Offset(x, y), Offset(x + 10, y), light);
      }
    } else {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), i == 2 ? strong : light);
    }
  }
}

/// Paints ink strokes, thicker where the S Pen presses harder.
void paintInk(Canvas canvas, List<List<InkSample>> strokes, {required double width, Color color = AppColors.grape}) {
  for (final stroke in strokes) {
    if (stroke.isEmpty) {
      continue;
    }
    final pressure = stroke.map((s) => s.pressure).reduce((a, b) => a + b) / stroke.length;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width * (0.75 + 0.5 * pressure.clamp(0.0, 1.0));
    canvas.drawPath(catmullRomPath([for (final s in stroke) s.position]), paint);
  }
}

/// Dashed version of a path (template centre lines).
void paintDashed(Canvas canvas, Path path, Paint paint, {double dash = 10, double gap = 8}) {
  for (final ui.PathMetric metric in path.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final end = (distance + dash).clamp(0.0, metric.length).toDouble();
      canvas.drawPath(metric.extractPath(distance, end), paint);
      distance += dash + gap;
    }
  }
}
