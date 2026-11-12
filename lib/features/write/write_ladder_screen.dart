// lib/features/write/write_ladder_screen.dart
//
// "Viết từ": one row of sets per level, easy to hard. Levels open with the
// child's level; inside a level each set opens when the one before is
// passed (80 %).
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/kid_scaffold.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/providers.dart';
import '../../curriculum/write_ladder.dart';
import '../../l10n/strings_vi.dart';
import '../../widgets/item_picture.dart';

/// Best test score of each set, per child.
class WriteScores {
  const WriteScores._();

  static const String key = 'write_best';

  static Future<Map<String, double>> load(AppServices services, int profileId) async {
    final raw = await services.db.settingsRepo.read(key, profileId: profileId);
    if (raw == null || raw.isEmpty) {
      return {};
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {for (final e in map.entries) e.key: (e.value as num).toDouble()};
    } catch (_) {
      return {};
    }
  }

  /// Keeps the best score; returns the updated map.
  static Future<Map<String, double>> save(AppServices services, int profileId, String setId, double score) async {
    final best = await load(services, profileId);
    if (score > (best[setId] ?? -1)) {
      best[setId] = score;
      await services.db.settingsRepo.write(key, jsonEncode(best), profileId: profileId);
    }
    return best;
  }
}

/// Route argument for /write/set.
class WriteSetArgs {
  const WriteSetArgs({required this.sets, required this.index});

  /// All sets of the group, so "next set" works from the result screen.
  final List<WriteSet> sets;
  final int index;

  WriteSet get set => sets[index];
}

class WriteLadderScreen extends ConsumerStatefulWidget {
  const WriteLadderScreen({super.key});

  @override
  ConsumerState<WriteLadderScreen> createState() => _WriteLadderScreenState();
}

class _WriteLadderScreenState extends ConsumerState<WriteLadderScreen> {
  Map<String, double> _best = const {};
  int _level = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final services = ref.read(appServicesProvider);
    final profile = await ref.read(activeProfileProvider.future);
    final best = await WriteScores.load(services, profile.id);
    if (mounted) {
      setState(() {
        _best = best;
        _level = profile.level;
        _loaded = true;
      });
    }
  }

  Future<void> _open(List<WriteSet> sets, int index) async {
    await context.push(AppRoutes.writeSet, extra: WriteSetArgs(sets: sets, index: index));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(appServicesProvider);
    final curriculum = services.curriculum;
    final parentSets = WriteLadder.forParentWords(curriculum);
    return KidScaffold(
      instructionVi: S.writeLadderSpoken,
      showBack: true,
      child: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              children: [
                if (parentSets.isNotEmpty) _group(S.writeGroupParent, parentSets, open: true),
                for (var level = 0; level <= 5; level++)
                  _group(S.writeGroupTitle(level), WriteLadder.forLevel(curriculum, level), open: level <= _level),
              ],
            ),
    );
  }

  Widget _group(String title, List<WriteSet> sets, {required bool open}) {
    if (sets.isEmpty) {
      return const SizedBox.shrink();
    }
    final passed = sets.where((s) => (_best[s.id] ?? 0) >= WriteLadder.passScore).length;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
              if (open) Text('$passed / ${sets.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              if (!open) const Icon(Icons.lock_rounded),
            ],
          ),
          if (!open)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(S.writeGroupLocked, style: TextStyle(fontSize: 16)),
            )
          else
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: sets.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) => _SetCard(
                  set: sets[i],
                  number: i + 1,
                  best: _best[sets[i].id],
                  open: WriteLadder.isOpen(sets, i, _best),
                  onTap: () => _open(sets, i),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SetCard extends StatelessWidget {
  const _SetCard({required this.set, required this.number, required this.best, required this.open, required this.onTap});

  final WriteSet set;
  final int number;
  final double? best;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stars = WriteLadder.stars(best);
    return Opacity(
      opacity: open ? 1 : 0.45,
      child: SizedBox(
        width: 150,
        child: PictureCard(
          onTap: open ? onTap : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 2,
                children: [for (final item in set.items.take(5)) ItemPicture(item: item, size: 30)],
              ),
              const SizedBox(height: 6),
              if (!open)
                const Icon(Icons.lock_rounded, size: 30)
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var s = 0; s < 3; s++)
                      Icon(
                        s < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: s < stars ? AppColors.honeyDeep : AppColors.ink.withValues(alpha: 0.4),
                        size: 28,
                      ),
                  ],
                ),
              Text('$number', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}
