// lib/core/services/llm_service.dart
import 'dart:async';

import 'package:flutter/services.dart';

class LlmException implements Exception {
  const LlmException(this.message);
  final String message;

  @override
  String toString() => 'LlmException($message)';
}

/// Dart side of the LiteRT-LM bridge (Gemma 4 E2B / E4B).
///
/// Lifecycle rule: load only when the "Talk with Bi" screen opens and call
/// [unload] when it closes, to save RAM and battery and keep the phone cool.
/// Nothing outside that feature may depend on this service.
class LlmService {
  static const MethodChannel _channel = MethodChannel('ongbi/llm');
  static const EventChannel _events = EventChannel('ongbi/llm/stream');

  Stream<Map<String, Object?>>? _stream;
  int _nextId = 1;
  String? _backend;

  /// "gpu" or "cpu" once a model is loaded.
  String? get backend => _backend;
  bool get isLoaded => _backend != null;

  Stream<Map<String, Object?>> get _eventStream {
    return _stream ??= _events
        .receiveBroadcastStream()
        .map((event) => Map<String, Object?>.from(event as Map))
        .asBroadcastStream();
  }

  /// Loads the model, trying the GPU first when [preferGpu] is set and
  /// falling back to the CPU when GPU initialisation fails.
  Future<String> load({required String modelPath, required bool preferGpu}) async {
    final attempts = preferGpu ? const [true, false] : const [false];
    Object? lastError;
    for (final useGpu in attempts) {
      try {
        final raw = await _channel.invokeMapMethod<String, Object?>('load', {
          'modelPath': modelPath,
          'useGpu': useGpu,
        });
        _backend = (raw?['backend'] as String?) ?? (useGpu ? 'gpu' : 'cpu');
        return _backend!;
      } on PlatformException catch (e) {
        lastError = e.message ?? e.code;
      } on MissingPluginException catch (e) {
        lastError = e.message ?? 'bridge missing';
        break;
      }
    }
    _backend = null;
    throw LlmException('load failed: $lastError');
  }

  /// Starts a fresh conversation with the given system prompt.
  Future<void> startConversation(String systemPrompt) async {
    try {
      await _channel.invokeMethod<Object?>('startConversation', {'systemPrompt': systemPrompt});
    } on PlatformException catch (e) {
      throw LlmException(e.message ?? e.code);
    }
  }

  /// Sends one user turn and streams the reply as text chunks.
  Stream<String> send(String text) {
    final id = _nextId++;
    late final StreamController<String> controller;
    StreamSubscription<Map<String, Object?>>? sub;

    controller = StreamController<String>(
      onListen: () {
        sub = _eventStream.where((e) => e['id'] == id).listen((event) {
          switch (event['type']) {
            case 'chunk':
              controller.add((event['text'] as String?) ?? '');
            case 'done':
              controller.close();
            case 'error':
              controller.addError(LlmException((event['text'] as String?) ?? 'error'));
              controller.close();
          }
        });
        _channel.invokeMethod<Object?>('send', {'id': id, 'text': text}).catchError((Object e) {
          if (!controller.isClosed) {
            controller.addError(LlmException(e.toString()));
            controller.close();
          }
          return null;
        });
      },
      onCancel: () async {
        await sub?.cancel();
      },
    );
    return controller.stream;
  }

  /// Convenience: the whole reply as one string.
  Future<String> reply(String text) async {
    final buffer = StringBuffer();
    await for (final chunk in send(text)) {
      buffer.write(chunk);
    }
    return buffer.toString();
  }

  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<Object?>('cancel');
    } on PlatformException {
      // Nothing was running.
    }
  }

  /// Releases the model from memory. Safe to call when nothing is loaded.
  Future<void> unload() async {
    try {
      await _channel.invokeMethod<Object?>('unload');
    } on PlatformException {
      // Already unloaded.
    } on MissingPluginException {
      // Bridge unavailable (tests).
    }
    _backend = null;
  }
}
