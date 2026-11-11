// lib/features/tests/certificate.dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../l10n/strings_vi.dart';

/// Draws the level-up certificate as a PNG (1600 x 1131, A4 landscape ratio).
Future<Uint8List> renderCertificate({
  required String childName,
  required int level,
  required DateTime date,
}) async {
  const width = 1600.0;
  const height = 1131.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

  canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), Paint()..color = AppColors.cream);
  final border = Paint()
    ..color = AppColors.honeyDeep
    ..style = PaintingStyle.stroke
    ..strokeWidth = 28;
  canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(40, 40, width - 80, height - 80), const Radius.circular(40)), border);
  final inner = Paint()
    ..color = AppColors.ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4;
  canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(80, 80, width - 160, height - 160), const Radius.circular(28)), inner);

  void text(String value, double y, double size, {FontWeight weight = FontWeight.w800, Color color = AppColors.ink}) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(fontFamily: AppTheme.uiFont, fontSize: size, fontWeight: weight, color: color),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width - 260);
    painter.paint(canvas, Offset((width - painter.width) / 2, y));
  }

  text(S.certificateTitle, 130, 110, weight: FontWeight.w900, color: const Color(0xFFE63946));
  text(S.appName, 270, 44);
  text(S.certificateAwardedTo, 360, 40, weight: FontWeight.w600);
  text(childName, 420, 96, weight: FontWeight.w900, color: AppColors.grape);
  text(S.certificateBody, 560, 40, weight: FontWeight.w600);
  text(S.certificateLevel(level), 620, 64, weight: FontWeight.w900);
  text(S.certificateDate(date), 940, 34, weight: FontWeight.w600);

  try {
    final picture = await vg.loadPicture(const SvgAssetLoader('assets/svg/bi_cheering.svg'), null);
    canvas.save();
    canvas.translate(width - 430, height - 470);
    canvas.scale(320 / picture.size.width);
    canvas.drawPicture(picture.picture);
    canvas.restore();
    picture.picture.dispose();
  } catch (_) {
    // The certificate is still valid without the drawing.
  }

  final image = await recorder.endRecording().toImage(width.toInt(), height.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}
