// lib/core/services/model_downloader.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../config/app_config.dart';
import '../db/repositories.dart';
import 'model_catalog.dart';
import 'platform_bridge.dart';

enum PackPhase {
  missing,
  downloading,
  verifying,
  extracting,
  importing,
  installed,
  failed,
  needsManual,
}

class PackStatus {
  const PackStatus({
    required this.phase,
    this.done = 0,
    this.total = 0,
    this.errorCode = '',
    this.checksumVerified = true,
  });

  final PackPhase phase;
  final int done;
  final int total;

  /// Stable code mapped to a Vietnamese message by the UI.
  final String errorCode;
  final bool checksumVerified;

  double? get fraction => total > 0 ? (done / total).clamp(0.0, 1.0).toDouble() : null;

  bool get busy =>
      phase == PackPhase.downloading ||
      phase == PackPhase.verifying ||
      phase == PackPhase.extracting ||
      phase == PackPhase.importing;
}

/// Failure with a stable code: no_wifi, no_space, login_required, `http_NNN`,
/// network, checksum, incomplete_pack, cancelled.
class ModelDownloadException implements Exception {
  const ModelDownloadException(this.code, [this.detail = '']);

  final String code;
  final String detail;

  @override
  String toString() => 'ModelDownloadException($code, $detail)';
}

class _Retryable implements Exception {
  const _Retryable(this.detail);
  final String detail;
}

/// Downloads, verifies, extracts and imports model packs.
///
/// This is the only class in the app that opens a network connection.
class ModelDownloader {
  static const int _flushEveryBytes = 8 * 1024 * 1024;

  ModelDownloader({
    required this.modelsRoot,
    required this.modelRepo,
    required this.device,
    required this.files,
  }) {
    _progressSub = files.progress.listen(_onNativeProgress);
  }

  final String modelsRoot;
  final ModelRepo modelRepo;
  final DevicePlatform device;
  final FilesPlatform files;

  /// Status per pack id. Widgets listen with ValueListenableBuilder.
  final ValueNotifier<Map<String, PackStatus>> statuses =
      ValueNotifier<Map<String, PackStatus>>(const <String, PackStatus>{});

  StreamSubscription<FileProgress>? _progressSub;
  final Set<String> _cancelled = <String>{};

  String packDir(ModelPack pack) => p.join(modelsRoot, pack.id);

  String get _incomingDir => p.join(modelsRoot, '.incoming');

  String _partPath(ModelPack pack) => p.join(_incomingDir, '${pack.fileName}.part');

  void dispose() {
    _progressSub?.cancel();
    statuses.dispose();
  }

  bool _screenKeptOn = false;

  void _set(String id, PackStatus status) {
    statuses.value = {...statuses.value, id: status};
    final busy = statuses.value.values.any((s) => s.busy);
    if (busy != _screenKeptOn) {
      _screenKeptOn = busy;
      unawaited(device.keepScreenOn(busy));
    }
  }

  void _onNativeProgress(FileProgress event) {
    final current = statuses.value[event.tag];
    if (current == null || !current.busy) {
      return;
    }
    final PackPhase phase;
    switch (event.op) {
      case 'extract':
        phase = PackPhase.extracting;
      case 'import':
        phase = PackPhase.importing;
      default:
        phase = PackPhase.verifying;
    }
    _set(event.tag, PackStatus(phase: phase, done: event.done, total: event.total));
  }

  Future<bool> isInstalled(ModelPack pack) async {
    final dir = packDir(pack);
    for (final relative in pack.requiredFiles) {
      if (!await File(p.join(dir, relative)).exists()) {
        return false;
      }
    }
    return true;
  }

  /// Re-reads the disk and publishes installed / missing for the given packs.
  Future<void> refresh(Iterable<ModelPack> packs) async {
    for (final pack in packs) {
      final current = statuses.value[pack.id];
      if (current != null && current.busy) {
        continue;
      }
      if (await isInstalled(pack)) {
        final row = await modelRepo.byId(pack.id);
        _set(
          pack.id,
          PackStatus(
            phase: PackPhase.installed,
            checksumVerified: row?.checksumVerified ?? false,
          ),
        );
      } else if (current == null ||
          current.phase == PackPhase.installed ||
          current.phase == PackPhase.missing) {
        _set(pack.id, const PackStatus(phase: PackPhase.missing));
      }
    }
  }

  Future<bool> allInstalled(Iterable<ModelPack> packs) async {
    for (final pack in packs) {
      if (!await isInstalled(pack)) {
        return false;
      }
    }
    return true;
  }

  void cancel(ModelPack pack) {
    _cancelled.add(pack.id);
  }

  /// Downloads every missing pack in order. Returns the ids that failed.
  Future<List<String>> downloadAll(Iterable<ModelPack> packs) async {
    final failed = <String>[];
    for (final pack in packs) {
      if (await isInstalled(pack)) {
        continue;
      }
      try {
        await download(pack);
      } on ModelDownloadException catch (e) {
        failed.add(pack.id);
        if (e.code == 'no_wifi' || e.code == 'no_space') {
          break; // the remaining packs would fail the same way
        }
      }
    }
    return failed;
  }

  /// Downloads one pack over Wi-Fi with resume, then verifies and installs it.
  Future<void> download(ModelPack pack) async {
    final current = statuses.value[pack.id];
    if (current != null && current.busy) {
      return;
    }
    _cancelled.remove(pack.id);
    try {
      await _requireWifi();
      await _requireSpace(pack);
      await Directory(_incomingDir).create(recursive: true);
      final part = File(_partPath(pack));

      var attempt = 0;
      while (true) {
        try {
          await _fetch(pack, part);
          break;
        } on _Retryable catch (e) {
          attempt++;
          if (attempt > AppConfig.downloadMaxRetries) {
            throw ModelDownloadException('network', e.detail);
          }
          final wait = AppConfig.downloadRetryBaseSeconds * attempt;
          await Future<void>.delayed(Duration(seconds: wait));
          await _requireWifi();
        }
      }
      await _verifyAndInstall(pack, part, source: 'download');
    } on ModelDownloadException catch (e) {
      final phase = e.code == 'login_required' ? PackPhase.needsManual : PackPhase.failed;
      _set(pack.id, PackStatus(phase: phase, errorCode: e.code));
      rethrow;
    } catch (e) {
      _set(pack.id, const PackStatus(phase: PackPhase.failed, errorCode: 'network'));
      throw ModelDownloadException('network', e.toString());
    }
  }

  /// Lets the parent pick an already-downloaded file (for example from the
  /// Download folder). Returns false when the picker was cancelled.
  Future<bool> importManually(ModelPack pack) async {
    final current = statuses.value[pack.id];
    if (current != null && current.busy) {
      return false;
    }
    try {
      await Directory(_incomingDir).create(recursive: true);
      final part = File(_partPath(pack));
      if (await part.exists()) {
        await part.delete();
      }
      _set(pack.id, const PackStatus(phase: PackPhase.importing));
      final name = await files.pickAndImport(dest: part.path, tag: pack.id);
      if (name == null) {
        await refresh([pack]);
        return false;
      }
      await _verifyAndInstall(pack, part, source: 'manual');
      return true;
    } on ModelDownloadException catch (e) {
      _set(pack.id, PackStatus(phase: PackPhase.failed, errorCode: e.code));
      rethrow;
    } catch (e) {
      _set(pack.id, const PackStatus(phase: PackPhase.failed, errorCode: 'incomplete_pack'));
      throw ModelDownloadException('incomplete_pack', e.toString());
    }
  }

  Future<void> delete(ModelPack pack) async {
    final dir = Directory(packDir(pack));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    final part = File(_partPath(pack));
    if (await part.exists()) {
      await part.delete();
    }
    await modelRepo.remove(pack.id);
    _set(pack.id, const PackStatus(phase: PackPhase.missing));
  }

  Future<int> installedBytes(ModelPack pack) async {
    final dir = Directory(packDir(pack));
    if (!await dir.exists()) {
      return 0;
    }
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  // ---------------------------------------------------------------------------

  Future<void> _requireWifi() async {
    if (!await device.isUnmeteredNetwork()) {
      throw const ModelDownloadException('no_wifi');
    }
  }

  Future<void> _requireSpace(ModelPack pack) async {
    await Directory(modelsRoot).create(recursive: true);
    final free = await device.freeBytes(modelsRoot);
    if (free < 0) {
      return; // unknown, let the download try
    }
    // Archives need room for the compressed file plus the extracted tree.
    final factor = pack.kind == PackKind.tarBz2 ? 2.4 : 1.05;
    final needed =
        (pack.bytes * factor).round() + AppConfig.freeSpaceSafetyMarginMb * 1024 * 1024;
    if (free < needed) {
      throw const ModelDownloadException('no_space');
    }
  }

  /// One HTTP attempt. Resumes from the size of the .part file.
  Future<void> _fetch(ModelPack pack, File part) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: AppConfig.downloadConnectTimeoutSeconds);
    IOSink? sink;
    try {
      var offset = await part.exists() ? await part.length() : 0;
      final request = await client.getUrl(Uri.parse(pack.url));
      request.followRedirects = true;
      request.maxRedirects = 8;
      request.headers.set(HttpHeaders.userAgentHeader, 'OngBiEnglish/1 (model setup)');
      if (offset > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
      }
      final response = await request.close();
      final code = response.statusCode;

      if (code == HttpStatus.unauthorized || code == HttpStatus.forbidden) {
        await response.drain<void>();
        throw const ModelDownloadException('login_required');
      }
      if (code == HttpStatus.requestedRangeNotSatisfiable) {
        // The .part file is already complete.
        await response.drain<void>();
        return;
      }
      if (code >= 500) {
        await response.drain<void>();
        throw _Retryable('http $code');
      }
      if (code != HttpStatus.ok && code != HttpStatus.partialContent) {
        await response.drain<void>();
        throw ModelDownloadException('http_$code');
      }

      int total;
      if (code == HttpStatus.ok) {
        offset = 0; // server ignored the range: start over
        total = response.contentLength;
      } else {
        total = response.contentLength >= 0 ? offset + response.contentLength : -1;
      }
      if (total <= 0) {
        total = pack.bytes;
      }

      sink = part.openWrite(mode: offset > 0 ? FileMode.append : FileMode.write);
      var received = offset;
      var lastFlushed = offset;
      var lastUpdate = DateTime.now();
      _set(pack.id, PackStatus(phase: PackPhase.downloading, done: received, total: total));

      final stream = response.timeout(
        const Duration(seconds: AppConfig.downloadIdleTimeoutSeconds),
      );
      await for (final chunk in stream) {
        if (_cancelled.contains(pack.id)) {
          throw const ModelDownloadException('cancelled');
        }
        sink.add(chunk);
        received += chunk.length;
        // Let the disk catch up now and then, so a fast network cannot pile
        // gigabytes of unwritten data into memory.
        if (received - lastFlushed >= _flushEveryBytes) {
          lastFlushed = received;
          await sink.flush();
        }
        final now = DateTime.now();
        if (now.difference(lastUpdate).inMilliseconds >= 300) {
          lastUpdate = now;
          _set(pack.id, PackStatus(phase: PackPhase.downloading, done: received, total: total));
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;

      final onDisk = await part.length();
      if (response.contentLength >= 0 && onDisk < total) {
        throw _Retryable('short read $onDisk of $total');
      }
      _set(pack.id, PackStatus(phase: PackPhase.downloading, done: onDisk, total: total));
    } on SocketException catch (e) {
      throw _Retryable(e.message);
    } on HttpException catch (e) {
      throw _Retryable(e.message);
    } on HandshakeException catch (e) {
      throw _Retryable(e.message);
    } on TimeoutException catch (_) {
      throw const _Retryable('timeout');
    } finally {
      if (sink != null) {
        try {
          await sink.flush();
          await sink.close();
        } catch (_) {
          // The stream already failed; the .part file stays for resume.
        }
      }
      client.close(force: true);
    }
  }

  /// Hash published by Hugging Face for LFS files (the x-linked-etag header).
  Future<String?> _publishedSha256(ModelPack pack) async {
    if (!pack.isHuggingFace) {
      return null;
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: AppConfig.downloadConnectTimeoutSeconds);
    try {
      final request = await client.headUrl(Uri.parse(pack.url));
      request.followRedirects = false;
      final response = await request.close();
      await response.drain<void>();
      final raw = response.headers.value('x-linked-etag') ?? '';
      final cleaned = raw.replaceAll('"', '').trim().toLowerCase();
      final isSha = RegExp(r'^[0-9a-f]{64}$').hasMatch(cleaned);
      return isSha ? cleaned : null;
    } catch (_) {
      return null; // offline manual import: no published hash available
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _verifyAndInstall(
    ModelPack pack,
    File part, {
    required String source,
  }) async {
    if (!await part.exists()) {
      throw const ModelDownloadException('incomplete_pack', 'downloaded file is missing');
    }
    final size = await part.length();
    _set(pack.id, PackStatus(phase: PackPhase.verifying, done: 0, total: size));
    final actual = (await files.sha256(part.path, tag: pack.id)).toLowerCase();

    final published = await _publishedSha256(pack);
    final expected = published ?? pack.sha256;
    var verified = false;
    if (expected != null) {
      verified = expected == actual;
      // A hash published by the host for this exact file must match.
      // A pinned hash can go stale when upstream republishes an archive, so a
      // mismatch there is recorded (shown to the parent) while the bzip2 CRCs
      // and the required-file check below still guard against corruption.
      if (!verified && published != null) {
        await part.delete();
        throw const ModelDownloadException('checksum');
      }
    }

    final target = Directory(packDir(pack));
    final staging = Directory(p.join(_incomingDir, '${pack.id}_staging'));
    if (await staging.exists()) {
      await staging.delete(recursive: true);
    }
    await staging.create(recursive: true);

    try {
      if (pack.kind == PackKind.tarBz2) {
        _set(pack.id, PackStatus(phase: PackPhase.extracting, done: 0, total: size));
        await files.extractTarBz2(archive: part.path, destDir: staging.path, tag: pack.id);
      } else {
        await part.rename(p.join(staging.path, pack.fileName));
      }

      for (final relative in pack.requiredFiles) {
        if (!await File(p.join(staging.path, relative)).exists()) {
          throw ModelDownloadException('incomplete_pack', 'missing $relative');
        }
      }
      for (final relative in pack.pruneAfterInstall) {
        final path = p.join(staging.path, relative);
        final type = await FileSystemEntity.type(path);
        if (type == FileSystemEntityType.directory) {
          await Directory(path).delete(recursive: true);
        } else if (type == FileSystemEntityType.file) {
          await File(path).delete();
        }
      }

      if (await target.exists()) {
        await target.delete(recursive: true);
      }
      await staging.rename(target.path);
    } on ModelDownloadException {
      rethrow;
    } catch (e) {
      // Extraction failed: the archive is corrupt, so drop it and start clean.
      if (await part.exists()) {
        await part.delete();
      }
      throw ModelDownloadException('incomplete_pack', e.toString());
    } finally {
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
    }

    if (await part.exists()) {
      await part.delete();
    }
    await modelRepo.upsert(
      packId: pack.id,
      directory: target.path,
      bytes: await installedBytes(pack),
      sha256: actual,
      checksumVerified: verified,
      source: source,
    );
    _set(pack.id, PackStatus(phase: PackPhase.installed, checksumVerified: verified));
  }
}
