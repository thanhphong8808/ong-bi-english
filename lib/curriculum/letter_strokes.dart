// lib/curriculum/letter_strokes.dart
//
// Stroke templates for tracing A-Z and a-z, in "band" units of a four-line
// handwriting grid: y = 0 top line, 1 middle line, 2 baseline, 3 bottom line.
// Capitals go from the top line to the baseline; lower-case letters sit
// between the middle line and the baseline, with ascenders and descenders.
// Each stroke is an ordered list of points: order and direction matter.
import 'dart:math' as math;

class P {
  const P(this.x, this.y);

  final double x;
  final double y;

  P operator +(P o) => P(x + o.x, y + o.y);
  P operator -(P o) => P(x - o.x, y - o.y);
  P operator *(double k) => P(x * k, y * k);

  double distanceTo(P o) => math.sqrt((x - o.x) * (x - o.x) + (y - o.y) * (y - o.y));
}

typedef Stroke = List<P>;

class LetterTemplate {
  const LetterTemplate(this.letter, this.strokes);

  final String letter;
  final List<Stroke> strokes;

  double get minX => strokes.expand((s) => s).map((p) => p.x).reduce(math.min);
  double get maxX => strokes.expand((s) => s).map((p) => p.x).reduce(math.max);
  double get width => maxX - minX;
}

/// Builds a straight segment.
List<P> _line(double x1, double y1, double x2, double y2) => [P(x1, y1), P(x2, y2)];

/// Builds an elliptical arc. Angles are in degrees in screen coordinates
/// (0 = right, 90 = down). Increasing angles turn clockwise on screen.
List<P> _arc(double cx, double cy, double rx, double ry, double fromDeg, double toDeg) {
  final steps = math.max(6, ((toDeg - fromDeg).abs() / 12).ceil());
  return [
    for (var i = 0; i <= steps; i++)
      () {
        final a = (fromDeg + (toDeg - fromDeg) * i / steps) * math.pi / 180;
        return P(cx + rx * math.cos(a), cy + ry * math.sin(a));
      }(),
  ];
}

/// Joins pieces into one stroke, dropping duplicated joint points.
List<P> _join(List<List<P>> pieces) {
  final out = <P>[];
  for (final piece in pieces) {
    for (final p in piece) {
      if (out.isEmpty || out.last.distanceTo(p) > 1e-6) {
        out.add(p);
      }
    }
  }
  return out;
}

class LetterStrokes {
  const LetterStrokes._();

  static final Map<String, List<Stroke>> _data = {
    // ---- Capitals ----
    'A': [_line(0.8, 0, 0, 2), _line(0.8, 0, 1.6, 2), _line(0.35, 1.25, 1.25, 1.25)],
    'B': [
      _line(0, 0, 0, 2),
      _join([_line(0, 0, 0.7, 0), _arc(0.7, 0.5, 0.5, 0.5, -90, 90), _line(0.7, 1, 0, 1)]),
      _join([_line(0, 1, 0.8, 1), _arc(0.8, 1.5, 0.5, 0.5, -90, 90), _line(0.8, 2, 0, 2)]),
    ],
    'C': [_arc(0.9, 1, 0.9, 1, -45, -315)],
    'D': [
      _line(0, 0, 0, 2),
      _join([_line(0, 0, 0.4, 0), _arc(0.4, 1, 1.0, 1, -90, 90), _line(0.4, 2, 0, 2)]),
    ],
    'E': [_line(0, 0, 0, 2), _line(0, 0, 1.2, 0), _line(0, 1, 1.0, 1), _line(0, 2, 1.2, 2)],
    'F': [_line(0, 0, 0, 2), _line(0, 0, 1.2, 0), _line(0, 1, 1.0, 1)],
    'G': [_arc(0.9, 1, 0.9, 1, -45, -360), _line(1.0, 1, 1.8, 1)],
    'H': [_line(0, 0, 0, 2), _line(1.4, 0, 1.4, 2), _line(0, 1, 1.4, 1)],
    'I': [_line(0.3, 0, 0.3, 2)],
    'J': [_join([_line(0.9, 0, 0.9, 1.5), _arc(0.45, 1.5, 0.45, 0.5, 0, 180)])],
    'K': [_line(0, 0, 0, 2), _line(1.2, 0, 0.05, 1.15), _line(0.4, 0.85, 1.3, 2)],
    'L': [_join([_line(0, 0, 0, 2), _line(0, 2, 1.1, 2)])],
    'M': [_line(0, 0, 0, 2), _join([_line(0, 0, 0.9, 1.5), _line(0.9, 1.5, 1.8, 0), _line(1.8, 0, 1.8, 2)])],
    'N': [_line(0, 0, 0, 2), _join([_line(0, 0, 1.4, 2), _line(1.4, 2, 1.4, 0)])],
    'O': [_arc(0.9, 1, 0.9, 1, -90, -450)],
    'P': [_line(0, 0, 0, 2), _join([_line(0, 0, 0.7, 0), _arc(0.7, 0.5, 0.5, 0.5, -90, 90), _line(0.7, 1, 0, 1)])],
    'Q': [_arc(0.9, 1, 0.9, 1, -90, -450), _line(1.05, 1.45, 1.8, 2.15)],
    'R': [
      _line(0, 0, 0, 2),
      _join([_line(0, 0, 0.7, 0), _arc(0.7, 0.5, 0.5, 0.5, -90, 90), _line(0.7, 1, 0, 1)]),
      _line(0.55, 1, 1.3, 2),
    ],
    'S': [_join([_arc(0.65, 0.5, 0.6, 0.5, -30, -270), _arc(0.65, 1.5, 0.65, 0.5, -90, 150)])],
    'T': [_line(0.7, 0, 0.7, 2), _line(0, 0, 1.4, 0)],
    'U': [_join([_line(0, 0, 0, 1.3), _arc(0.7, 1.3, 0.7, 0.7, 180, 0), _line(1.4, 1.3, 1.4, 0)])],
    'V': [_join([_line(0, 0, 0.8, 2), _line(0.8, 2, 1.6, 0)])],
    'W': [_join([_line(0, 0, 0.55, 2), _line(0.55, 2, 1.1, 0.6), _line(1.1, 0.6, 1.65, 2), _line(1.65, 2, 2.2, 0)])],
    'X': [_line(0, 0, 1.4, 2), _line(1.4, 0, 0, 2)],
    'Y': [_line(0, 0, 0.7, 1), _join([_line(1.4, 0, 0.7, 1), _line(0.7, 1, 0.7, 2)])],
    'Z': [_join([_line(0, 0, 1.4, 0), _line(1.4, 0, 0, 2), _line(0, 2, 1.4, 2)])],

    // ---- Lower case ----
    'a': [_arc(0.5, 1.5, 0.5, 0.5, -30, -390), _line(1.0, 1.0, 1.0, 2)],
    'b': [_line(0, 0, 0, 2), _arc(0.5, 1.5, 0.5, 0.5, 180, 540)],
    'c': [_arc(0.5, 1.5, 0.5, 0.5, -40, -320)],
    'd': [_arc(0.5, 1.5, 0.5, 0.5, -30, -390), _line(1.0, 0, 1.0, 2)],
    'e': [_join([_line(0.02, 1.5, 1.0, 1.5), _arc(0.5, 1.5, 0.5, 0.5, 0, -320)])],
    'f': [_join([_arc(0.6, 0.4, 0.3, 0.35, -40, -180), _line(0.3, 0.4, 0.3, 2)]), _line(0, 1, 0.75, 1)],
    'g': [
      _arc(0.5, 1.5, 0.5, 0.5, -30, -390),
      _join([_line(1.0, 1.0, 1.0, 2.6), _arc(0.55, 2.6, 0.45, 0.35, 0, 160)]),
    ],
    'h': [_line(0, 0, 0, 2), _join([_arc(0.5, 1.4, 0.5, 0.4, 180, 360), _line(1.0, 1.4, 1.0, 2)])],
    'i': [_line(0.2, 1, 0.2, 2), _line(0.2, 0.5, 0.2, 0.6)],
    'j': [_join([_line(0.6, 1, 0.6, 2.6), _arc(0.3, 2.6, 0.3, 0.3, 0, 160)]), _line(0.6, 0.5, 0.6, 0.6)],
    'k': [_line(0, 0, 0, 2), _line(0.9, 1.0, 0.05, 1.6), _line(0.35, 1.4, 0.95, 2)],
    'l': [_line(0.2, 0, 0.2, 2)],
    'm': [
      _line(0, 1, 0, 2),
      _join([_arc(0.35, 1.35, 0.35, 0.35, 180, 360), _line(0.7, 1.35, 0.7, 2)]),
      _join([_arc(1.05, 1.35, 0.35, 0.35, 180, 360), _line(1.4, 1.35, 1.4, 2)]),
    ],
    'n': [_line(0, 1, 0, 2), _join([_arc(0.5, 1.4, 0.5, 0.4, 180, 360), _line(1.0, 1.4, 1.0, 2)])],
    'o': [_arc(0.5, 1.5, 0.5, 0.5, -90, -450)],
    'p': [_line(0, 1, 0, 3), _arc(0.5, 1.5, 0.5, 0.5, 180, 540)],
    'q': [_arc(0.5, 1.5, 0.5, 0.5, -30, -390), _line(1.0, 1, 1.0, 3)],
    'r': [_line(0, 1, 0, 2), _arc(0.45, 1.45, 0.45, 0.45, 180, 300)],
    's': [_join([_arc(0.45, 1.25, 0.42, 0.25, -30, -270), _arc(0.45, 1.75, 0.45, 0.25, -90, 150)])],
    't': [_join([_line(0.35, 0.3, 0.35, 1.8), _arc(0.6, 1.8, 0.25, 0.2, 180, 60)]), _line(0, 1, 0.75, 1)],
    'u': [_join([_line(0, 1, 0, 1.6), _arc(0.5, 1.6, 0.5, 0.4, 180, 0), _line(1.0, 1.6, 1.0, 1.0)]), _line(1.0, 1.0, 1.0, 2)],
    'v': [_join([_line(0, 1, 0.5, 2), _line(0.5, 2, 1.0, 1)])],
    'w': [_join([_line(0, 1, 0.35, 2), _line(0.35, 2, 0.7, 1.3), _line(0.7, 1.3, 1.05, 2), _line(1.05, 2, 1.4, 1)])],
    'x': [_line(0, 1, 1, 2), _line(1, 1, 0, 2)],
    'y': [_line(0, 1, 0.5, 2), _line(1.0, 1, 0.25, 3)],
    'z': [_join([_line(0, 1, 1, 1), _line(1, 1, 0, 2), _line(0, 2, 1, 2)])],
  };

  static LetterTemplate? of(String letter) {
    final strokes = _data[letter];
    return strokes == null ? null : LetterTemplate(letter, strokes);
  }

  static Iterable<String> get letters => _data.keys;
}
