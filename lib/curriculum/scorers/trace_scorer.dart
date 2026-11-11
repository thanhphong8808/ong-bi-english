// lib/curriculum/scorers/trace_scorer.dart
//
// Geometric scoring of letter tracing (level 0). No machine learning:
// coverage of the template path, maximum deviation, stroke direction and
// stroke order. Coordinates are in the band units of LetterStrokes.
import 'dart:math' as math;

import '../../core/config/app_config.dart';
import '../letter_strokes.dart';

class TraceResult {
  const TraceResult({
    required this.coverage,
    required this.deviation,
    required this.directionOk,
    required this.orderOk,
  });

  /// Fraction of the template path the child went over (0..1).
  final double coverage;

  /// 90th-percentile distance of the child's ink from the template, in bands.
  final double deviation;
  final bool directionOk;
  final bool orderOk;

  bool get passed =>
      coverage >= AppConfig.traceCoverageMin &&
      deviation <= AppConfig.traceMaxDeviationBands &&
      directionOk &&
      orderOk;

  /// Close enough to praise: the shape is there but not every rule is met.
  bool get nearly => coverage >= AppConfig.traceNearlyCoverage;

  int get stars {
    if (!passed) {
      return 0;
    }
    return coverage >= 0.9 ? 3 : 2;
  }
}

class TraceScorer {
  const TraceScorer({
    this.hitRadius = AppConfig.traceHitRadiusBands,
    this.sampleStep = 0.05,
  });

  /// Two ink strokes whose coverage differs by less than this are a tie.
  static const double _tieTolerance = 0.02;

  /// A template point counts as covered when ink passes within this radius.
  final double hitRadius;
  final double sampleStep;

  static List<P> resample(List<P> stroke, double step) {
    if (stroke.length < 2) {
      return List<P>.of(stroke);
    }
    final out = <P>[stroke.first];
    var carry = 0.0;
    for (var i = 1; i < stroke.length; i++) {
      final a = stroke[i - 1];
      final b = stroke[i];
      final length = a.distanceTo(b);
      if (length == 0) {
        continue;
      }
      var t = step - carry;
      while (t <= length) {
        out.add(a + (b - a) * (t / length));
        t += step;
      }
      carry = length - (t - step);
    }
    if (out.last.distanceTo(stroke.last) > 1e-9) {
      out.add(stroke.last);
    }
    return out;
  }

  static double _distanceToPolyline(P p, List<P> line) {
    if (line.length == 1) {
      return p.distanceTo(line.first);
    }
    var best = double.infinity;
    for (var i = 1; i < line.length; i++) {
      best = math.min(best, _distanceToSegment(p, line[i - 1], line[i]));
    }
    return best;
  }

  static double _distanceToSegment(P p, P a, P b) {
    final ab = b - a;
    final lengthSq = ab.x * ab.x + ab.y * ab.y;
    if (lengthSq == 0) {
      return p.distanceTo(a);
    }
    final t = (((p.x - a.x) * ab.x + (p.y - a.y) * ab.y) / lengthSq).clamp(0.0, 1.0);
    return p.distanceTo(a + ab * t.toDouble());
  }

  /// Index of the point in [points] nearest to [p].
  static int _nearestIndex(P p, List<P> points) {
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final d = p.distanceTo(points[i]);
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    return best;
  }

  TraceResult score(LetterTemplate template, List<List<P>> userStrokes) {
    final ink = [
      for (final stroke in userStrokes)
        if (stroke.isNotEmpty) resample(stroke, sampleStep),
    ];
    if (ink.isEmpty) {
      return const TraceResult(coverage: 0, deviation: 99, directionOk: false, orderOk: false);
    }
    final allInk = ink.expand((s) => s).toList();
    final templatePoints = [for (final s in template.strokes) resample(s, sampleStep)];
    final allTemplate = templatePoints.expand((s) => s).toList();

    // Coverage over the whole letter.
    var covered = 0;
    for (final point in allTemplate) {
      if (allInk.any((q) => q.distanceTo(point) <= hitRadius)) {
        covered++;
      }
    }
    final coverage = covered / allTemplate.length;

    // Deviation: 90th percentile of ink distance to the nearest template stroke.
    final distances = [
      for (final q in allInk)
        template.strokes.map((s) => _distanceToPolyline(q, s)).reduce(math.min),
    ]..sort();
    final deviation = distances[(distances.length * 0.9).floor().clamp(0, distances.length - 1)];

    // Match every template stroke to the ink stroke that covers it best.
    // Strokes that overlap (the right side of "u", the stem of "d") can be
    // covered equally well by two ink strokes; the tie goes to the ink stroke
    // drawn in the expected position, so a correct letter is never punished.
    final matched = <int>[];
    var directionOk = true;
    for (var index = 0; index < templatePoints.length; index++) {
      final points = templatePoints[index];
      final covers = [
        for (var s = 0; s < ink.length; s++)
          points.where((t) => ink[s].any((q) => q.distanceTo(t) <= hitRadius)).length / points.length,
      ];
      final bestCover = covers.reduce(math.max);
      var bestStroke = 0;
      var bestGap = 1 << 30;
      for (var s = 0; s < ink.length; s++) {
        if (covers[s] >= bestCover - _tieTolerance && (s - index).abs() < bestGap) {
          bestGap = (s - index).abs();
          bestStroke = s;
        }
      }
      matched.add(bestStroke);

      // Direction: along the matched ink stroke, the template's start should
      // be reached before its end. Dots and tiny strokes are exempt.
      final length = _length(points);
      if (length >= 0.3 && bestCover >= 0.5) {
        final strokeInk = ink[bestStroke];
        final startAt = _nearestIndex(points.first, strokeInk);
        final endAt = _nearestIndex(points.last, strokeInk);
        final closed = points.first.distanceTo(points.last) < hitRadius;
        if (closed) {
          // Loops (o, a, O): compare the turning direction, wherever the
          // child started on the loop.
          if (_signedArea(points).sign != _signedArea(strokeInk).sign) {
            directionOk = false;
          }
        } else if (startAt > endAt) {
          directionOk = false;
        }
      }
    }
    var orderOk = true;
    for (var i = 1; i < matched.length; i++) {
      if (matched[i] < matched[i - 1]) {
        orderOk = false;
      }
    }
    return TraceResult(
      coverage: coverage,
      deviation: deviation,
      directionOk: directionOk,
      orderOk: orderOk,
    );
  }

  /// Shoelace formula: the sign tells clockwise from counter-clockwise.
  static double _signedArea(List<P> points) {
    var sum = 0.0;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      sum += a.x * b.y - b.x * a.y;
    }
    return sum / 2;
  }

  static double _length(List<P> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += points[i - 1].distanceTo(points[i]);
    }
    return total;
  }
}
