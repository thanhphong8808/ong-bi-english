// lib/widgets/giant_button.dart
import 'package:material_ui/material_ui.dart';

import '../app/theme.dart';
import '../core/config/app_config.dart';

/// A very large picture button for kid mode: one big emoji and 2-3 words.
class GiantButton extends StatefulWidget {
  const GiantButton({
    super.key,
    required this.emoji,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  State<GiantButton> createState() => _GiantButtonState();
}

class _GiantButtonState extends State<GiantButton> {
  bool _down = false;

  /// The pastel tile behind the emoji for each accent colour.
  static Color _tint(Color c) {
    if (c == AppColors.sky) return AppColors.skySoft;
    if (c == AppColors.leaf) return AppColors.leafSoft;
    if (c == AppColors.berry) return AppColors.berrySoft;
    if (c == AppColors.grape) return AppColors.grapeSoft;
    return AppColors.honeySoft;
  }

  void _setDown(bool value) {
    if (mounted) {
      setState(() => _down = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => _setDown(true),
        onTapCancel: () => _setDown(false),
        onTapUp: (_) => _setDown(false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _down ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 90),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppConfig.giantButtonMinSize,
              minWidth: AppConfig.giantButtonMinSize,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _tint(widget.color),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    widget.emoji,
                    style: const TextStyle(fontFamily: AppTheme.emojiFont, fontSize: 52, height: 1.1),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_forward_rounded, color: AppColors.white, size: 24),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
