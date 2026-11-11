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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppColors.ink, width: 3),
              boxShadow: const [
                BoxShadow(color: AppColors.ink, offset: Offset(0, 6)),
              ],
            ),
            child: Row(
              children: [
                Text(
                  widget.emoji,
                  style: const TextStyle(fontFamily: AppTheme.emojiFont, fontSize: 64),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
