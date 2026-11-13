// lib/features/setup/pack_tile.dart
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../core/services/model_catalog.dart';
import '../../core/services/model_downloader.dart';
import '../../l10n/strings_vi.dart';

/// One model pack with its size, status and actions. Used by the first-time
/// setup screen and by the parent model manager.
class PackTile extends StatelessWidget {
  const PackTile({
    super.key,
    required this.pack,
    required this.status,
    required this.onDownload,
    required this.onImport,
    this.onDelete,
  });

  final ModelPack pack;
  final PackStatus status;
  final VoidCallback onDownload;
  final VoidCallback onImport;

  /// Shown only in the model manager.
  final VoidCallback? onDelete;

  String get _sizeLabel {
    final size = S.megabytes(pack.bytes);
    return pack.sizeIsApproximate ? '${S.setupApproxPrefix}$size' : size;
  }

  String get _phaseLabel {
    switch (status.phase) {
      case PackPhase.missing:
        return S.phaseMissing;
      case PackPhase.downloading:
        return S.phaseDownloading;
      case PackPhase.verifying:
        return S.phaseVerifying;
      case PackPhase.extracting:
        return S.phaseExtracting;
      case PackPhase.importing:
        return S.phaseImporting;
      case PackPhase.installed:
        return S.phaseInstalled;
      case PackPhase.failed:
        return S.phaseFailed;
      case PackPhase.needsManual:
        return S.phaseNeedsManual;
    }
  }

  void _showManualHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(S.setupManualTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(S.setupManualBody),
              const SizedBox(height: 12),
              const Text(S.setupManualPage, style: TextStyle(fontWeight: FontWeight.w800)),
              // Plain selectable text on purpose: the app never opens links.
              SelectableText(pack.manualPageUrl),
              const SizedBox(height: 12),
              const Text(S.setupManualFile, style: TextStyle(fontWeight: FontWeight.w800)),
              SelectableText(pack.fileName),
              const SizedBox(height: 12),
              Text('${S.modelsLicense}: ${pack.license}', style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(S.close)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final installed = status.phase == PackPhase.installed;
    final failed = status.phase == PackPhase.failed || status.phase == PackPhase.needsManual;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line, width: 1.5),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pack.titleVi, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(pack.purposeVi, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_sizeLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(
                    pack.optional ? S.setupOptional : S.setupRequired,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                installed
                    ? Icons.check_circle_rounded
                    : (failed ? Icons.error_outline_rounded : Icons.cloud_download_outlined),
                color: installed ? AppColors.leaf : AppColors.ink,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status.busy && status.total > 0
                      ? '$_phaseLabel: ${S.megabytes(status.done)} / ${S.megabytes(status.total)}'
                      : _phaseLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (status.busy)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: status.fraction, minHeight: 10),
              ),
            ),
          if (failed)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(S.errorFor(status.errorCode), style: const TextStyle(fontSize: 13)),
            ),
          if (installed && !status.checksumVerified)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(S.checksumUnverified, style: TextStyle(fontSize: 12)),
            ),
          if (!status.busy)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (!installed)
                    FilledButton.tonal(onPressed: onDownload, child: const Text(S.setupDownloadOne)),
                  if (installed && onDelete != null)
                    OutlinedButton(onPressed: onDownload, child: const Text(S.modelsRedownload)),
                  OutlinedButton(onPressed: onImport, child: const Text(S.setupImport)),
                  TextButton(
                    onPressed: () => _showManualHelp(context),
                    child: const Text(S.setupManualTitle),
                  ),
                  if (installed && onDelete != null)
                    TextButton(onPressed: onDelete, child: const Text(S.modelsDelete)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
