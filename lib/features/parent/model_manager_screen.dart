// lib/features/parent/model_manager_screen.dart
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/services/model_catalog.dart';
import '../../core/services/model_downloader.dart';
import '../../l10n/strings_vi.dart';
import '../setup/pack_tile.dart';

/// Parent tool: sizes, re-download, manual import, delete, clear audio cache.
class ModelManagerScreen extends ConsumerStatefulWidget {
  const ModelManagerScreen({super.key});

  @override
  ConsumerState<ModelManagerScreen> createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends ConsumerState<ModelManagerScreen> {
  late final List<ModelPack> _packs;
  int _modelBytes = 0;
  int _cacheBytes = 0;

  @override
  void initState() {
    super.initState();
    final services = ref.read(appServicesProvider);
    // The English fallback voice is offered here as well.
    _packs = [...ModelCatalog.packsFor(services.profile), ModelCatalog.piperEn];
    services.downloader.refresh(_packs);
    _measure();
  }

  Future<void> _measure() async {
    final services = ref.read(appServicesProvider);
    var total = 0;
    for (final pack in _packs) {
      total += await services.downloader.installedBytes(pack);
    }
    final cache = await services.audioCache.sizeBytes();
    if (mounted) {
      setState(() {
        _modelBytes = total;
        _cacheBytes = cache;
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on ModelDownloadException {
      // The tile shows the reason.
    }
    await _measure();
  }

  Future<void> _clearCache() async {
    await ref.read(appServicesProvider).audioCache.clear();
    await _measure();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(S.modelsCacheCleared)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloader = ref.watch(appServicesProvider).downloader;
    return Scaffold(
      appBar: AppBar(title: const Text(S.parentModels)),
      body: SafeArea(
        child: ValueListenableBuilder<Map<String, PackStatus>>(
          valueListenable: downloader.statuses,
          builder: (context, statuses, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                Text(
                  '${S.modelsStorage}: ${S.megabytes(_modelBytes)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(child: Text('${S.modelsAudioCache}: ${S.megabytes(_cacheBytes)}')),
                    OutlinedButton(onPressed: _clearCache, child: const Text(S.modelsClearCache)),
                  ],
                ),
                const SizedBox(height: 8),
                for (final pack in _packs)
                  PackTile(
                    pack: pack,
                    status: statuses[pack.id] ?? const PackStatus(phase: PackPhase.missing),
                    onDownload: () => _run(() => downloader.download(pack)),
                    onImport: () => _run(() async {
                      await downloader.importManually(pack);
                    }),
                    onDelete: () => _run(() => downloader.delete(pack)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
