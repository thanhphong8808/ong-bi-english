// lib/features/parent/parent_home_screen.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../core/providers.dart';
import '../../l10n/strings_vi.dart';

/// Entry of the parent area. Reached only through the parent gate.
class ParentHomeScreen extends ConsumerWidget {
  const ParentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(activeProfileProvider).value;
    Widget entry(IconData icon, String title, String route, {String? subtitle}) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: ListTile(
          leading: Icon(icon, size: 30),
          title: Text(title, style: Theme.of(context).textTheme.titleMedium),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push(route),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text(S.parentTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (profile != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${profile.name} · ${S.certificateLevel(profile.level)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            entry(Icons.insights_rounded, S.progressTitle, AppRoutes.parentProgress),
            entry(Icons.tune_rounded, S.parentSettings, AppRoutes.parentSettings),
            entry(Icons.people_alt_rounded, S.profilesTitle, AppRoutes.parentProfiles),
            entry(Icons.forum_rounded, S.chatLogsTitle, AppRoutes.parentChats),
            entry(Icons.save_alt_rounded, S.dataTitle, AppRoutes.parentData),
            entry(Icons.download_done_rounded, S.parentModels, AppRoutes.parentModels),
            entry(Icons.health_and_safety_outlined, S.parentDiagnostics, AppRoutes.parentDiagnostics),
            const SizedBox(height: 16),
            const Text(S.pinningHint, style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
