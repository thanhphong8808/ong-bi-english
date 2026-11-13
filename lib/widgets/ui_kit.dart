// lib/widgets/ui_kit.dart
//
// Building blocks of the soft card look: white cards on warm shadows,
// pastel icon tiles, honey pill buttons and slim progress bars.
import 'package:material_ui/material_ui.dart';

import '../app/theme.dart';

/// A white card with a soft shadow. Tappable when [onTap] is set.
class SoftCard extends StatefulWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.white,
    this.gradient,
    this.radius = 24,
    this.border,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Gradient? gradient;
  final double radius;
  final BoxBorder? border;
  final String? semanticLabel;

  @override
  State<SoftCard> createState() => _SoftCardState();
}

class _SoftCardState extends State<SoftCard> {
  bool _down = false;

  void _press(bool down) {
    if (widget.onTap != null && mounted) {
      setState(() => _down = down);
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = AnimatedScale(
      scale: _down ? 0.97 : 1,
      duration: const Duration(milliseconds: 90),
      child: Container(
        padding: widget.padding,
        decoration: BoxDecoration(
          color: widget.gradient == null ? widget.color : null,
          gradient: widget.gradient,
          borderRadius: BorderRadius.circular(widget.radius),
          border: widget.border,
          boxShadow: AppShadows.card,
        ),
        child: widget.child,
      ),
    );
    if (widget.onTap == null) {
      return card;
    }
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapCancel: () => _press(false),
        onTapUp: (_) => _press(false),
        onTap: widget.onTap,
        child: card,
      ),
    );
  }
}

/// A rounded pastel square holding one big emoji.
class IconTile extends StatelessWidget {
  const IconTile(this.emoji, {super.key, this.color = AppColors.honeySoft, this.size = 64, this.radius});

  final String emoji;
  final Color color;
  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius ?? size * 0.3)),
      child: Text(
        emoji,
        style: TextStyle(fontFamily: AppTheme.emojiFont, fontSize: size * 0.56, height: 1.1),
      ),
    );
  }
}

/// The honey "Tiếp tục" pill.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = AppColors.honey,
    this.textColor = AppColors.ink,
    this.big = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final Color textColor;
  final bool big;

  @override
  Widget build(BuildContext context) {
    // Its own accessibility node, so a button inside a card is not merged
    // into the card's text (TalkBack and taps then find the button itself).
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      child: Opacity(
        opacity: onPressed == null ? 0.45 : 1,
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(999),
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onPressed,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: big ? 26 : 18, vertical: big ? 14 : 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                boxShadow: onPressed == null ? null : AppShadows.glow(color),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: big ? 20 : 16, fontWeight: FontWeight.w900, color: textColor),
                  ),
                  if (icon != null) ...[const SizedBox(width: 6), Icon(icon, size: big ? 24 : 20, color: textColor)],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Slim rounded progress bar.
class SoftProgress extends StatelessWidget {
  const SoftProgress({super.key, required this.value, this.color = AppColors.honeyDeep, this.height = 10});

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Container(color: color.withValues(alpha: 0.16)),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0).toDouble(),
              child: Container(
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Học hôm nay"-style section heading with an optional trailing widget.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A rounded pill with an emoji and a short value (stars, minutes).
class StatPill extends StatelessWidget {
  const StatPill({super.key, required this.emoji, required this.text, this.color = AppColors.white});

  final String emoji;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999), boxShadow: AppShadows.soft),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontFamily: AppTheme.emojiFont, fontSize: 22)),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

/// One destination of the kid bottom bar.
class KidNavItem {
  const KidNavItem({required this.emoji, required this.label, required this.onTap});

  final String emoji;
  final String label;
  final VoidCallback onTap;
}

/// Bottom bar of the kid home: big emoji icons with one-word labels.
class KidBottomNav extends StatelessWidget {
  const KidBottomNav({super.key, required this.items, required this.current});

  final List<KidNavItem> items;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == current,
                label: items[i].label,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: items[i].onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: i == current ? AppColors.honeySoft : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            items[i].emoji,
                            style: const TextStyle(fontFamily: AppTheme.emojiFont, fontSize: 26, height: 1.15),
                          ),
                        ),
                        const SizedBox(height: 2),
                        ExcludeSemantics(
                          child: Text(
                            items[i].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: i == current ? FontWeight.w900 : FontWeight.w700,
                              color: i == current ? AppColors.ink : AppColors.inkSoft,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// White round button with a soft shadow (top bars).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.semanticLabel,
    this.size = 56,
    this.color = AppColors.white,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: AppShadows.soft, color: color),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: size * 0.52, color: AppColors.ink, semanticLabel: semanticLabel),
          ),
        ),
      ),
    );
  }
}
