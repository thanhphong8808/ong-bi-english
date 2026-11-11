// lib/features/rewards/sticker_album_screen.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../core/db/repositories.dart';
import '../../core/providers.dart';
import '../../l10n/strings_vi.dart';
import '../../widgets/item_picture.dart';
import '../daily_lesson/activities/activity_base.dart';
import 'stickers.dart';

final _ownedProvider = FutureProvider.autoDispose<List<Reward>>((ref) async {
  final services = ref.watch(appServicesProvider);
  final profile = await ref.watch(activeProfileProvider.future);
  return services.db.rewardRepo.forProfile(profile.id);
});

/// The child's sticker collection. Grey shapes show what is still to win.
class StickerAlbumScreen extends ConsumerStatefulWidget {
  const StickerAlbumScreen({super.key});

  @override
  ConsumerState<StickerAlbumScreen> createState() => _StickerAlbumScreenState();
}

class _StickerAlbumScreenState extends ConsumerState<StickerAlbumScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appServicesProvider).speech.sayVi(S.stickerAlbumSpoken).catchError((Object _) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final owned = {for (final r in ref.watch(_ownedProvider).value ?? const <Reward>[]) r.stickerId};
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  KidIconButton(icon: Icons.arrow_back_rounded, size: 60, onPressed: () => context.pop()),
                  const SizedBox(width: 16),
                  const EmojiText('🎁', size: 40),
                  const SizedBox(width: 8),
                  Text('${owned.length} / ${stickers.length}',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            Expanded(
              child: GridView.count(
                crossAxisCount: 4,
                padding: const EdgeInsets.all(12),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  for (final sticker in stickers)
                    Container(
                      decoration: BoxDecoration(
                        color: owned.contains(sticker.id) ? AppColors.white : const Color(0xFFEDE6D2),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.ink, width: 2),
                      ),
                      child: Center(
                        child: owned.contains(sticker.id)
                            ? EmojiText(sticker.emoji, size: 52)
                            : const Opacity(opacity: 0.25, child: EmojiText('❔', size: 40)),
                      ),
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
