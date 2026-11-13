// lib/features/home/week_honey.dart
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../curriculum/streak.dart';
import '../../l10n/strings_vi.dart';
import '../../widgets/item_picture.dart';

/// This week as a row of honeycomb cells: a cell fills with honey on each
/// study day. A missed day just stays empty; nothing is ever taken away.
class WeekHoney extends StatelessWidget {
  const WeekHoney({super.key, required this.streak});

  final StreakInfo streak;

  @override
  Widget build(BuildContext context) {
    final todayIndex = DateTime.now().weekday - DateTime.monday;
    return Semantics(
      label: streak.current >= 2 ? S.streakDays(streak.current) : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 7; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomPaint(
                    size: const Size(34, 38),
                    painter: _HexPainter(filled: streak.week[i], today: i == todayIndex),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    S.weekDays[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: i == todayIndex ? FontWeight.w900 : FontWeight.w600,
                      color: AppColors.ink.withValues(alpha: i == todayIndex ? 1 : 0.6),
                    ),
                  ),
                ],
              ),
            ),
          if (streak.current >= 2) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.line, width: 1.5),
                boxShadow: AppShadows.soft,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EmojiText('🔥', size: 20),
                  const SizedBox(width: 4),
                  Text('${streak.current}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HexPainter extends CustomPainter {
  _HexPainter({required this.filled, required this.today});

  final bool filled;
  final bool today;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 2;
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = math.pi / 6 + i * math.pi / 3;
      final point = center + Offset(radius * math.cos(angle), radius * math.sin(angle));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = filled ? AppColors.honey : AppColors.honeySoft);
    canvas.drawPath(
      path,
      Paint()
        ..color = today || filled ? AppColors.honeyDeep : AppColors.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = today ? 3.5 : 2,
    );
  }

  @override
  bool shouldRepaint(_HexPainter old) => old.filled != filled || old.today != today;
}
