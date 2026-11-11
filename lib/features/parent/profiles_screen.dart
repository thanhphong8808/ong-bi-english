// lib/features/parent/profiles_screen.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/config/app_config.dart';
import '../../core/db/repositories.dart';
import '../../core/providers.dart';
import '../../l10n/strings_vi.dart';

final _profilesProvider = FutureProvider.autoDispose<List<Profile>>((ref) {
  return ref.watch(appServicesProvider).db.profileRepo.all();
});

/// Up to three child profiles on one phone; choose who is learning.
class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  Future<String?> _askName(BuildContext context, {String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(S.profileName),
        content: TextField(controller: controller, autofocus: true, maxLength: 40),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(S.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text(S.save)),
        ],
      ),
    );
    return name == null || name.isEmpty ? null : name;
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(_profilesProvider);
    ref.invalidate(activeProfileProvider);
    final profile = await ref.read(activeProfileProvider.future);
    await ref.read(appServicesProvider).studyClock.load(profile.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(_profilesProvider).value ?? const <Profile>[];
    final settings = ref.watch(parentSettingsProvider);
    final services = ref.read(appServicesProvider);
    final repo = services.db.profileRepo;
    final notifier = ref.read(parentSettingsProvider.notifier);
    final activeId = profiles.any((p) => p.id == settings.activeProfileId)
        ? settings.activeProfileId
        : (profiles.isNotEmpty ? profiles.first.id : 0);

    return Scaffold(
      appBar: AppBar(title: const Text(S.profilesTitle)),
      floatingActionButton: profiles.length < AppConfig.maxProfiles
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text(S.addProfile),
              onPressed: () async {
                final name = await _askName(context);
                if (name != null) {
                  await repo.create(name);
                  await _refresh(ref);
                }
              },
            )
          : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final p in profiles)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: Icon(
                          p.id == activeId ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        ),
                        title: Text(p.name, style: Theme.of(context).textTheme.titleMedium),
                        subtitle: Text('${S.certificateLevel(p.level)} · ⭐ ${p.stars}'),
                        onTap: () async {
                          await notifier.change((s) => s.copyWith(activeProfileId: p.id));
                          await _refresh(ref);
                        },
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.edit_rounded),
                            label: const Text(S.rename),
                            onPressed: () async {
                              final name = await _askName(context, initial: p.name);
                              if (name != null) {
                                await repo.rename(p.id, name);
                                await _refresh(ref);
                              }
                            },
                          ),
                          PopupMenuButton<int>(
                            tooltip: S.setLevel,
                            onSelected: (level) async {
                              await repo.setPosition(p.id, level: level, unitIndex: 0);
                              await repo.setPlacementDone(p.id, true);
                              await _refresh(ref);
                            },
                            itemBuilder: (context) => [
                              for (var l = 0; l < AppConfig.levelCount; l++)
                                PopupMenuItem(value: l, child: Text(S.certificateLevel(l))),
                            ],
                            child: const Padding(
                              padding: EdgeInsets.all(10),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.stairs_rounded),
                                SizedBox(width: 6),
                                Text(S.setLevel),
                              ]),
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.quiz_rounded),
                            label: Text(p.placementDone ? S.redoPlacement : S.skipPlacement),
                            onPressed: () async {
                              await repo.setPlacementDone(p.id, !p.placementDone);
                              await _refresh(ref);
                            },
                          ),
                          if (profiles.length > 1)
                            TextButton.icon(
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text(S.delete),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(S.deleteProfileConfirm(p.name)),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: const Text(S.cancel),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        child: const Text(S.delete),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  await repo.delete(p.id);
                                  if (p.id == activeId) {
                                    final rest = await repo.all();
                                    await notifier.change((s) => s.copyWith(activeProfileId: rest.first.id));
                                  }
                                  await _refresh(ref);
                                }
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const Text(S.profilesHint, style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
