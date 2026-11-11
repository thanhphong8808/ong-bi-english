// lib/core/services/platform_bridge.dart
import 'dart:async';

import 'package:flutter/services.dart';

/// Progress event from a long-running native file operation.
class FileProgress {
  const FileProgress({
    required this.op,
    required this.tag,
    required this.done,
    required this.total,
  });

  final String op; // extract | sha256 | import
  final String tag;
  final int done;
  final int total;
}

/// Thin wrapper over the Kotlin DeviceBridge.
class DevicePlatform {
  static const MethodChannel _channel = MethodChannel('ongbi/device');

  Future<Map<String, Object?>> getDeviceInfo() async {
    final raw = await _channel.invokeMapMethod<String, Object?>('getDeviceInfo');
    return raw ?? const <String, Object?>{};
  }

  /// True on Wi-Fi or Ethernet.
  Future<bool> isUnmeteredNetwork() async {
    final value = await _channel.invokeMethod<bool>('isUnmeteredNetwork');
    return value ?? false;
  }

  Future<int> freeBytes(String path) async {
    final value = await _channel.invokeMethod<int>('freeBytes', {'path': path});
    return value ?? -1;
  }

  static const MethodChannel _screen = MethodChannel('ongbi/screen');

  /// Keeps the screen on while large model files download, so the phone
  /// does not fall asleep and stall a 3 GB transfer. Best effort.
  Future<void> keepScreenOn(bool on) async {
    try {
      await _screen.invokeMethod<void>('keepOn', {'on': on});
    } catch (_) {
      // Not critical.
    }
  }
}

/// Thin wrapper over the Kotlin FilesBridge.
class FilesPlatform {
  static const MethodChannel _channel = MethodChannel('ongbi/files');
  static const EventChannel _events = EventChannel('ongbi/files/progress');

  Stream<FileProgress>? _progress;

  Stream<FileProgress> get progress {
    return _progress ??= _events.receiveBroadcastStream().map((event) {
      final map = Map<String, Object?>.from(event as Map);
      return FileProgress(
        op: (map['op'] as String?) ?? '',
        tag: (map['tag'] as String?) ?? '',
        done: (map['done'] as num?)?.toInt() ?? 0,
        total: (map['total'] as num?)?.toInt() ?? 0,
      );
    }).asBroadcastStream();
  }

  Future<void> extractTarBz2({
    required String archive,
    required String destDir,
    required String tag,
  }) async {
    await _channel.invokeMethod<Object?>('extractTarBz2', {
      'archive': archive,
      'destDir': destDir,
      'tag': tag,
    });
  }

  Future<String> sha256(String path, {required String tag}) async {
    final value = await _channel.invokeMethod<String>('sha256', {'path': path, 'tag': tag});
    return value ?? '';
  }

  /// Opens the system file picker and copies the chosen file to [dest].
  /// Returns the picked file name, or null when the parent cancelled.
  Future<String?> pickAndImport({required String dest, required String tag}) async {
    final raw = await _channel.invokeMapMethod<String, Object?>('pickAndImport', {
      'dest': dest,
      'tag': tag,
    });
    if (raw == null) {
      return null;
    }
    return (raw['name'] as String?) ?? '';
  }

  /// Saves a file into Download/OngBiEnglish and returns its display path.
  Future<String> saveToDownloads({
    required String name,
    required String mime,
    required Uint8List bytes,
  }) async {
    final path = await _channel.invokeMethod<String>('saveToDownloads', {
      'name': name,
      'mime': mime,
      'bytes': bytes,
    });
    return path ?? name;
  }

  /// Lets the parent pick a text file (a backup). Null when cancelled.
  Future<String?> pickText() => _channel.invokeMethod<String>('pickText');
}

/// Daily study reminder (local notification only).
class ReminderPlatform {
  static const MethodChannel _channel = MethodChannel('ongbi/reminder');

  Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> schedule({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await _channel.invokeMethod<Object?>('schedule', {
      'hour': hour,
      'minute': minute,
      'title': title,
      'body': body,
    });
  }

  Future<void> cancel() async {
    await _channel.invokeMethod<Object?>('cancel');
  }
}
