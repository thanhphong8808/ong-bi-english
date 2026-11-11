// lib/features/write/ink_pad.dart
import 'dart:async';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:material_ui/material_ui.dart';

import '../../core/services/ink_service.dart';
import 'ink_painting.dart';

/// Free handwriting area with the four guide lines. Accepts finger and
/// S Pen (pressure-sensitive ink). Reports strokes after a pause.
class InkPad extends StatefulWidget {
  const InkPad({super.key, required this.onPause, this.enabled = true, this.lines = 1});

  final void Function(List<List<InkPoint>> strokes) onPause;
  final bool enabled;

  /// Number of writing lines (1 for words, 2-3 for sentences).
  final int lines;

  @override
  State<InkPad> createState() => InkPadState();
}

class InkPadState extends State<InkPad> {
  final List<List<InkSample>> _strokes = [];
  Timer? _pause;

  @override
  void dispose() {
    _pause?.cancel();
    super.dispose();
  }

  bool get hasInk => _strokes.isNotEmpty;

  void clear() {
    _pause?.cancel();
    setState(_strokes.clear);
  }

  List<List<InkPoint>> get strokes => [
        for (final stroke in _strokes)
          [for (final s in stroke) InkPoint(s.position, s.timeMs, pressure: s.pressure)],
      ];

  static double _pressure(PointerEvent e) {
    if (e.kind != PointerDeviceKind.stylus) {
      return 1.0;
    }
    final range = e.pressureMax - e.pressureMin;
    return range <= 0 ? 1.0 : ((e.pressure - e.pressureMin) / range).clamp(0.0, 1.0).toDouble();
  }

  int _now(PointerEvent e) => e.timeStamp.inMilliseconds;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) {
        if (!widget.enabled) {
          return;
        }
        _pause?.cancel();
        setState(() => _strokes.add([InkSample(e.localPosition, _now(e), _pressure(e))]));
      },
      onPointerMove: (e) {
        if (!widget.enabled || _strokes.isEmpty) {
          return;
        }
        setState(() => _strokes.last.add(InkSample(e.localPosition, _now(e), _pressure(e))));
      },
      onPointerUp: (e) {
        if (!widget.enabled) {
          return;
        }
        _pause?.cancel();
        _pause = Timer(const Duration(milliseconds: 1600), () {
          if (mounted && _strokes.isNotEmpty) {
            widget.onPause(strokes);
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF3A2A1A), width: 3),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: CustomPaint(
            painter: _PadPainter(_strokes, widget.lines),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _PadPainter extends CustomPainter {
  _PadPainter(this.strokes, this.lines);

  final List<List<InkSample>> strokes;
  final int lines;

  @override
  void paint(Canvas canvas, Size size) {
    final rowHeight = size.height / lines;
    for (var i = 0; i < lines; i++) {
      final band = rowHeight / 3.6;
      canvas.save();
      canvas.translate(0, rowHeight * i);
      paintGuideLines(canvas, Size(size.width, rowHeight), (rowHeight - band * 3) / 2, band);
      canvas.restore();
    }
    paintInk(canvas, strokes, width: (rowHeight / 3.6) * 0.16);
  }

  @override
  bool shouldRepaint(covariant _PadPainter old) => true;
}
