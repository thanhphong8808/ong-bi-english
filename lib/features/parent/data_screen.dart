// lib/features/parent/data_screen.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../core/services/backup_service.dart';
import '../../l10n/strings_vi.dart';

/// Backup to the Download folder and restore on another phone.
class DataScreen extends ConsumerStatefulWidget {
  const DataScreen({super.key});

  @override
  ConsumerState<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends ConsumerState<DataScreen> {
  bool _busy = false;

  Future<void> _run(Future<String> Function() action) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final message = await action();
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } on BackupException catch (e) {
      if (e.code != 'cancelled') {
        messenger.showSnackBar(SnackBar(content: Text(S.backupError(e.code))));
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text(S.backupFailed)));
    }
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.read(appServicesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(S.dataTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(S.dataIntro),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.save_alt_rounded),
              label: const Text(S.backupExport),
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                        final path = await services.backup.exportToDownloads();
                        return '${S.backupDone}\n$path';
                      }),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.restore_rounded),
              label: const Text(S.restore),
              onPressed: _busy
                  ? null
                  : () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text(S.restore),
                          content: const Text(S.restoreConfirm),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text(S.cancel)),
                            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text(S.ok)),
                          ],
                        ),
                      );
                      if (ok != true) {
                        return;
                      }
                      await _run(() async {
                        await services.backup.restoreFromPicker();
                        await ref.read(parentSettingsProvider.notifier).reload();
                        ref.invalidate(activeProfileProvider);
                        return S.restoreDone;
                      });
                    },
            ),
            const SizedBox(height: 24),
            const Text(S.dataPrivacy, style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
