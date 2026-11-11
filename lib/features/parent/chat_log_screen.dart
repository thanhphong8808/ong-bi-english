// lib/features/parent/chat_log_screen.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../core/db/repositories.dart';
import '../../core/providers.dart';
import '../../l10n/strings_vi.dart';

final _logsProvider = FutureProvider.autoDispose<List<ChatLog>>((ref) async {
  final services = ref.watch(appServicesProvider);
  final profile = await ref.watch(activeProfileProvider.future);
  return services.db.chatLogRepo.forProfile(profile.id);
});

/// Transcript of "Talk with Bi", newest first. Safety events are marked.
class ChatLogScreen extends ConsumerWidget {
  const ChatLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(_logsProvider).value ?? const <ChatLog>[];
    final flagged = logs.where((l) => l.flagged).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text(S.chatLogsTitle),
        actions: [
          IconButton(
            tooltip: S.chatLogsClear,
            icon: const Icon(Icons.delete_sweep_rounded),
            onPressed: logs.isEmpty
                ? null
                : () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text(S.chatLogsClearConfirm),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text(S.cancel)),
                          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text(S.delete)),
                        ],
                      ),
                    );
                    if (ok == true) {
                      final profile = await ref.read(activeProfileProvider.future);
                      await ref.read(appServicesProvider).db.chatLogRepo.clearProfile(profile.id);
                      ref.invalidate(_logsProvider);
                    }
                  },
          ),
        ],
      ),
      body: SafeArea(
        child: logs.isEmpty
            ? const Center(child: Text(S.chatLogsEmpty))
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (flagged > 0)
                    Card(
                      color: const Color(0xFFFFE8C2),
                      child: ListTile(
                        leading: const Icon(Icons.flag_rounded),
                        title: Text(S.flaggedCount(flagged)),
                      ),
                    ),
                  for (final log in logs)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        log.flagged
                            ? Icons.flag_rounded
                            : (log.role == 'bi' ? Icons.emoji_nature_rounded : Icons.child_care_rounded),
                        color: log.flagged ? AppColors.berry : AppColors.ink,
                      ),
                      title: Text(log.content),
                      subtitle: Text(
                        '${S.roleLabel(log.role)} · ${log.createdAt.day}/${log.createdAt.month} '
                        '${log.createdAt.hour.toString().padLeft(2, '0')}:${log.createdAt.minute.toString().padLeft(2, '0')}',
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
