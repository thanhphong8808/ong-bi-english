// lib/core/services/native_guard.dart
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Keeps one faulty native engine from trapping the child in a crash loop.
///
/// The voices, speech recognition, handwriting and Gemma run native code. If
/// one of them crashes the whole process on a particular phone (for example
/// an instruction the CPU does not support), every lesson would crash again.
///
/// Before each native call a tiny marker file is written and it is removed
/// when the call returns. When the app then dies from a native crash, the
/// marker survives. On the next start that engine is switched off for this
/// app build and the app falls back: the phone's own voice instead of the
/// built-in voices, speaking practice without scores, tracing without word
/// recognition, "Talk with Bi" resting. A parent can switch it back on in
/// Diagnostics, and installing a new build clears the list.
class NativeGuard {
  NativeGuard(this._dir);

  /// A guard that never writes anything (tests, or when storage fails).
  NativeGuard.disabled() : _dir = null;

  final String? _dir;

  static const String tts = 'tts';
  static const String stt = 'stt';
  static const String ink = 'ink';
  static const String llm = 'llm';
  static const String llmGpu = 'llm_gpu';

  final Map<String, int> _busy = <String, int>{};
  final Set<String> _disabled = <String>{};
  String _build = '';

  /// Engines switched off for this build.
  Set<String> get disabled => Set<String>.unmodifiable(_disabled);

  bool isDisabled(String engine) => _disabled.contains(engine);

  File _marker(String engine) => File(p.join(_dir!, 'inflight_$engine'));

  File get _state => File(p.join(_dir!, 'native_guard.json'));

  /// Call once at start-up. [build] identifies the installed build;
  /// [nativeCrash] tells whether the previous run ended in a native crash.
  /// Returns the engines switched off just now.
  Future<Set<String>> start({required String build, required bool nativeCrash}) async {
    final newly = <String>{};
    final dir = _dir;
    if (dir == null) {
      return newly;
    }
    _build = build;
    try {
      await Directory(dir).create(recursive: true);
      if (await _state.exists()) {
        final map = jsonDecode(await _state.readAsString()) as Map<String, dynamic>;
        if (map['build'] == build) {
          _disabled.addAll(((map['disabled'] as List?) ?? const []).cast<String>());
        }
      }
      await for (final entity in Directory(dir).list()) {
        final name = p.basename(entity.path);
        if (entity is! File || !name.startsWith('inflight_')) {
          continue;
        }
        final engine = name.substring('inflight_'.length);
        // A marker without a native crash only means the app was closed
        // mid-call (swiped away, phone restarted): nothing to switch off.
        if (nativeCrash && _disabled.add(engine)) {
          newly.add(engine);
        }
        await entity.delete();
      }
      await _save();
    } catch (_) {
      // The guard is a safety net; it must never stop the app from starting.
    }
    return newly;
  }

  /// Marks [engine] busy. Calls nest: the marker stays until the last [end].
  void begin(String engine) {
    final count = (_busy[engine] ?? 0) + 1;
    _busy[engine] = count;
    if (count == 1 && _dir != null) {
      try {
        _marker(engine).writeAsStringSync('');
      } catch (_) {
        // Best effort.
      }
    }
  }

  void end(String engine) {
    final count = (_busy[engine] ?? 1) - 1;
    if (count > 0) {
      _busy[engine] = count;
      return;
    }
    _busy.remove(engine);
    if (_dir != null) {
      try {
        _marker(engine).deleteSync();
      } catch (_) {
        // Already gone.
      }
    }
  }

  /// Runs [body] with [engine] marked busy.
  Future<T> run<T>(String engine, Future<T> Function() body) async {
    begin(engine);
    try {
      return await body();
    } finally {
      end(engine);
    }
  }

  /// Switches every engine back on (parent action in Diagnostics).
  Future<void> enableAll() async {
    _disabled.clear();
    await _save();
  }

  Future<void> _save() async {
    if (_dir == null) {
      return;
    }
    try {
      await _state.writeAsString(jsonEncode({'build': _build, 'disabled': _disabled.toList()}));
    } catch (_) {
      // Best effort.
    }
  }
}
