// lib/features/tests/level_up_screen.dart
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/providers.dart';
import '../../l10n/strings_vi.dart';
import '../../widgets/bi_mascot.dart';
import '../daily_lesson/activities/activity_base.dart';
import '../parent/parent_gate_dialog.dart';
import 'certificate.dart';
import '../../widgets/motion.dart';

/// Passing a level test: confetti, Bi grows and changes outfit, and the
/// parent can save a certificate image to the Download folder.
class LevelUpScreen extends ConsumerStatefulWidget {
  const LevelUpScreen({super.key, required this.level});

  /// The new level.
  final int level;

  @override
  ConsumerState<LevelUpScreen> createState() => _LevelUpScreenState();
}

class _LevelUpScreenState extends ConsumerState<LevelUpScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _confetti =
      AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    loopUnlessReducedMotion(_confetti, context, stillValue: 0.5);
  }
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appServicesProvider).speech.sayVi(S.levelUpSpoken).catchError((Object _) {});
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _saveCertificate() async {
    if (_saving || !await showParentGate(context) || !mounted) {
      return;
    }
    setState(() => _saving = true);
    final services = ref.read(appServicesProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final profile = await ref.read(activeProfileProvider.future);
      final bytes = await renderCertificate(
        childName: profile.name,
        level: (widget.level - 1).clamp(0, 5).toInt(),
        date: DateTime.now(),
      );
      final path = await services.files.saveToDownloads(
        name: 'ongbi-giay-khen-cap-${widget.level - 1}-${DateTime.now().millisecondsSinceEpoch}.png',
        mime: 'image/png',
        bytes: bytes,
      );
      messenger.showSnackBar(SnackBar(content: Text('${S.certificateSaved}\n$path')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text(S.certificateFailed)));
    }
    if (mounted) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _confetti,
              builder: (context, _) => CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_confetti.value)),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BiMascot(mood: BiMood.cheering, size: 260, level: widget.level),
                  Text(S.levelUpTitle, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  Text(S.levelName(widget.level), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 30),
                  KidIconButton(
                    icon: Icons.home_rounded,
                    size: 110,
                    color: AppColors.honey,
                    label: S.rewardHome,
                    onPressed: () => context.go(AppRoutes.home),
                  ),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: _saving ? null : _saveCertificate,
                    icon: const Icon(Icons.workspace_premium_rounded),
                    label: const Text(S.certificateSave),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t);

  final double t;

  static const _colors = [AppColors.honey, AppColors.berry, AppColors.sky, AppColors.leaf, AppColors.grape];

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(7);
    for (var i = 0; i < 60; i++) {
      final x = random.nextDouble() * size.width;
      final speed = 0.5 + random.nextDouble();
      final y = ((t * speed + random.nextDouble()) % 1.0) * (size.height + 40) - 20;
      final paint = Paint()..color = _colors[i % _colors.length];
      canvas.save();
      canvas.translate(x + math.sin(t * 6 + i) * 12, y);
      canvas.rotate(t * 8 + i);
      canvas.drawRect(const Rect.fromLTWH(-6, -3, 12, 6), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}

