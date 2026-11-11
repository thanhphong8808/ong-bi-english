// lib/features/rewards/reward_screen.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/providers.dart';
import '../../l10n/strings_vi.dart';
import '../../widgets/bi_mascot.dart';
import '../../widgets/item_picture.dart';
import '../daily_lesson/activities/activity_base.dart';
import 'stickers.dart';

class RewardArgs {
  const RewardArgs({required this.stars, this.stickerId});

  final int stars;
  final String? stickerId;
}

/// End of a lesson: stars, a new sticker and a cheering Bi.
class RewardScreen extends ConsumerStatefulWidget {
  const RewardScreen({super.key, required this.args});

  final RewardArgs args;

  @override
  ConsumerState<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends ConsumerState<RewardScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pop =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appServicesProvider).speech.sayVi(S.rewardSpoken).catchError((Object _) {});
    });
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sticker = widget.args.stickerId == null ? null : stickerById(widget.args.stickerId!);
    final level = ref.watch(activeProfileProvider).value?.level ?? 0;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BiMascot(mood: BiMood.cheering, size: 220, level: level),
              Text(S.rewardTitle, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EmojiText('⭐', size: 48),
                  Text(' +${widget.args.stars}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
                ],
              ),
              if (sticker != null) ...[
                const SizedBox(height: 16),
                ScaleTransition(
                  scale: CurvedAnimation(parent: _pop, curve: Curves.elasticOut),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.honeyDeep, width: 6),
                    ),
                    child: EmojiText(sticker.emoji, size: 110),
                  ),
                ),
                const SizedBox(height: 8),
                Text(sticker.nameVi, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ],
              const SizedBox(height: 30),
              KidIconButton(
                icon: Icons.home_rounded,
                size: 110,
                color: AppColors.honey,
                label: S.rewardHome,
                onPressed: () => context.go(AppRoutes.home),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
