// lib/features/setup/setup_screen.dart
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/providers.dart';
import '../../core/services/model_catalog.dart';
import '../../core/services/model_downloader.dart';
import '../../l10n/strings_vi.dart';
import '../../widgets/bi_mascot.dart';
import '../parent/parent_gate_dialog.dart';
import 'pack_tile.dart';

/// First-time setup, operated by a parent: downloads the model packs.
/// This is the only place in the app that uses the network.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  late final List<ModelPack> _packs;
  bool _gatePassed = false;
  bool _downloadingAll = false;
  bool _inkReady = false;
  bool _inkBusy = false;

  @override
  void initState() {
    super.initState();
    final services = ref.read(appServicesProvider);
    _packs = ModelCatalog.packsFor(services.profile);
    services.downloader.refresh(_packs);
    _refreshInk();
  }

  Future<void> _refreshInk() async {
    try {
      final ready = await ref.read(appServicesProvider).ink.isModelReady();
      if (mounted) {
        setState(() => _inkReady = ready);
      }
    } catch (_) {
      // ML Kit unavailable: handwriting of words stays off, tracing still works.
    }
  }

  /// Every network action first asks for the parent gate, once per visit.
  Future<bool> _ensureParent() async {
    if (_gatePassed) {
      return true;
    }
    final ok = await showParentGate(context);
    if (ok && mounted) {
      setState(() => _gatePassed = true);
    }
    return ok;
  }

  Future<void> _downloadAll() async {
    if (!await _ensureParent()) {
      return;
    }
    setState(() => _downloadingAll = true);
    final services = ref.read(appServicesProvider);
    await services.downloader.downloadAll(_packs);
    if (!_inkReady) {
      await _downloadInk(askGate: false);
    }
    if (mounted) {
      setState(() => _downloadingAll = false);
    }
  }

  Future<void> _downloadOne(ModelPack pack) async {
    if (!await _ensureParent()) {
      return;
    }
    try {
      await ref.read(appServicesProvider).downloader.download(pack);
    } on ModelDownloadException {
      // The tile shows the reason.
    }
  }

  Future<void> _importOne(ModelPack pack) async {
    if (!await _ensureParent()) {
      return;
    }
    try {
      await ref.read(appServicesProvider).downloader.importManually(pack);
    } on ModelDownloadException {
      // The tile shows the reason.
    }
  }

  Future<void> _downloadInk({bool askGate = true}) async {
    if (askGate && !await _ensureParent()) {
      return;
    }
    if (mounted) {
      setState(() => _inkBusy = true);
    }
    try {
      await ref.read(appServicesProvider).ink.downloadModel();
    } catch (_) {
      // Stays "not downloaded"; the parent can retry.
    }
    await _refreshInk();
    if (mounted) {
      setState(() => _inkBusy = false);
    }
  }

  Future<void> _finish() async {
    final services = ref.read(appServicesProvider);
    await ref.read(parentSettingsProvider.notifier).change((s) => s.copyWith(setupDone: true));
    await services.refreshCapabilities();
    // Ask for the microphone now, while a parent is holding the phone.
    try {
      await services.stt.hasMicPermission();
    } catch (_) {
      // The child can still learn; speaking is then practised without scores.
    }
    if (!mounted) {
      return;
    }
    final skip = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(S.placementQuestionTitle),
        content: const Text(S.placementQuestionBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text(S.placementSkipLevel0)),
          FilledButton(onPressed: () => Navigator.of(context).pop(false), child: const Text(S.placementDoIt)),
        ],
      ),
    );
    if (skip == true) {
      final profile = await ref.read(activeProfileProvider.future);
      await services.db.profileRepo.setPlacementDone(profile.id, true);
      ref.invalidate(activeProfileProvider);
    }
    if (mounted) {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(appServicesProvider);
    final info = services.profile.info;

    return Scaffold(
      appBar: AppBar(title: const Text(S.setupTitle)),
      body: SafeArea(
        child: ValueListenableBuilder<Map<String, PackStatus>>(
          valueListenable: services.downloader.statuses,
          builder: (context, statuses, _) {
            PackStatus statusOf(ModelPack pack) =>
                statuses[pack.id] ?? const PackStatus(phase: PackPhase.missing);

            final requiredReady = _packs
                .where((pack) => !pack.optional)
                .every((pack) => statusOf(pack).phase == PackPhase.installed);
            final anyBusy = _packs.any((pack) => statusOf(pack).busy) || _downloadingAll;
            final missing = _packs.where((pack) => statusOf(pack).phase != PackPhase.installed);
            final missingBytes = ModelCatalog.totalBytes(missing);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                Row(
                  children: [
                    BiMascot(mood: anyBusy ? BiMood.thinking : BiMood.happy, size: 96),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            S.setupForParents,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          const Text(S.setupIntro),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${S.setupDevice}: ${info.model} · ${info.chipLabel} · ${S.ramLabel(info.totalRamMb)}',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '${S.setupTotal}: ${S.setupApproxPrefix}${S.megabytes(missingBytes)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: anyBusy || missing.isEmpty ? null : _downloadAll,
                  icon: const Icon(Icons.wifi_rounded),
                  label: Text(anyBusy ? S.setupDownloading : S.setupDownloadAll),
                ),
                const SizedBox(height: 8),
                for (final pack in _packs)
                  PackTile(
                    pack: pack,
                    status: statusOf(pack),
                    onDownload: () => _downloadOne(pack),
                    onImport: () => _importOne(pack),
                  ),
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: Icon(
                      _inkReady ? Icons.check_circle_rounded : Icons.draw_outlined,
                    ),
                    title: const Text(S.setupInk),
                    subtitle: const Text(S.setupInkPurpose),
                    trailing: _inkBusy
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : (_inkReady
                            ? const Text(S.phaseInstalled)
                            : TextButton(
                                onPressed: _downloadInk,
                                child: const Text(S.setupDownloadOne),
                              )),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(S.setupSkipOptional, style: TextStyle(fontSize: 13)),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: requiredReady && !anyBusy ? _finish : null,
                  child: const Text(S.setupContinue),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
