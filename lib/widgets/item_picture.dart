// lib/widgets/item_picture.dart
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../app/theme.dart';
import '../curriculum/models.dart';

/// The picture of a vocabulary item: an emoji or one of our own SVGs.
class ItemPicture extends StatelessWidget {
  const ItemPicture({super.key, required this.item, this.size = 96});

  final Item item;
  final double size;

  @override
  Widget build(BuildContext context) => EmojiOrSvg(image: item.image, size: size);
}

class EmojiOrSvg extends StatelessWidget {
  const EmojiOrSvg({super.key, required this.image, this.size = 96});

  final ItemImage image;
  final double size;

  @override
  Widget build(BuildContext context) {
    final svg = image.svg;
    if (svg != null) {
      return SvgPicture.asset('assets/svg/$svg', width: size, height: size);
    }
    return EmojiText(image.emoji ?? '❓', size: size);
  }
}

/// An emoji drawn with the bundled Noto Color Emoji font.
class EmojiText extends StatelessWidget {
  const EmojiText(this.emoji, {super.key, this.size = 64});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.2,
      height: size * 1.2,
      child: FittedBox(
        child: Text(emoji, style: const TextStyle(fontFamily: AppTheme.emojiFont, fontSize: 64, height: 1.1)),
      ),
    );
  }
}

/// A large tappable card holding a picture or word, used by the picking games.
class PictureCard extends StatelessWidget {
  const PictureCard({
    super.key,
    required this.child,
    required this.onTap,
    this.highlight = false,
    this.dimmed = false,
    this.round = false,
    this.color = AppColors.white,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool highlight;
  final bool dimmed;
  final bool round;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: dimmed ? 0.35 : 1,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(10),
          constraints: const BoxConstraints(minWidth: 96, minHeight: 96),
          decoration: BoxDecoration(
            color: highlight ? AppColors.honey : color,
            shape: round ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: round ? null : BorderRadius.circular(28),
            border: Border.all(color: highlight ? AppColors.leaf : AppColors.ink, width: highlight ? 6 : 3),
            boxShadow: const [BoxShadow(color: Color(0x33000000), offset: Offset(0, 4), blurRadius: 4)],
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Short burst of stars shown when the child gets something right.
class Sparkles extends StatefulWidget {
  const Sparkles({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<Sparkles> createState() => _SparklesState();
}

class _SparklesState extends State<Sparkles> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _controller.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(Sparkles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        widget.child,
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              if (t == 0 || t == 1) {
                return const SizedBox.shrink();
              }
              return Opacity(
                opacity: 1 - t,
                child: Transform.scale(
                  scale: 0.6 + t * 1.6,
                  child: const Text(
                    '✨⭐✨',
                    style: TextStyle(fontFamily: AppTheme.emojiFont, fontSize: 56),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Row of 0-3 stars.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.size = 40});

  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Opacity(
            opacity: i < stars ? 1 : 0.2,
            child: Text('⭐', style: TextStyle(fontFamily: AppTheme.emojiFont, fontSize: size)),
          ),
      ],
    );
  }
}
