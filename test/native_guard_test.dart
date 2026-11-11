// test/native_guard_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ong_bi_english/core/services/native_guard.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('native_guard_test');
  });

  tearDown(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  File marker(String engine) => File('${dir.path}/inflight_$engine');

  test('a marker exists only while the engine is busy, nested calls included', () async {
    final guard = NativeGuard(dir.path);
    await guard.start(build: '1', nativeCrash: false);
    guard.begin(NativeGuard.tts);
    guard.begin(NativeGuard.tts);
    expect(marker(NativeGuard.tts).existsSync(), isTrue);
    guard.end(NativeGuard.tts);
    expect(marker(NativeGuard.tts).existsSync(), isTrue);
    guard.end(NativeGuard.tts);
    expect(marker(NativeGuard.tts).existsSync(), isFalse);

    await guard.run(NativeGuard.ink, () async {
      expect(marker(NativeGuard.ink).existsSync(), isTrue);
    });
    expect(marker(NativeGuard.ink).existsSync(), isFalse);
  });

  test('run clears the marker when the call throws', () async {
    final guard = NativeGuard(dir.path);
    await guard.start(build: '1', nativeCrash: false);
    var threw = false;
    try {
      await guard.run<void>(NativeGuard.llm, () async => throw StateError('boom'));
    } on StateError {
      threw = true;
    }
    expect(threw, isTrue);
    expect(marker(NativeGuard.llm).existsSync(), isFalse);
  });

  test('after a native crash the busy engine is switched off for this build', () async {
    final first = NativeGuard(dir.path);
    await first.start(build: '7', nativeCrash: false);
    first.begin(NativeGuard.tts); // the process "dies" here

    final second = NativeGuard(dir.path);
    final newly = await second.start(build: '7', nativeCrash: true);
    expect(newly, {NativeGuard.tts});
    expect(second.isDisabled(NativeGuard.tts), isTrue);
    expect(second.isDisabled(NativeGuard.stt), isFalse);
    expect(marker(NativeGuard.tts).existsSync(), isFalse);

    // Still off on the following start, without a new crash.
    final third = NativeGuard(dir.path);
    expect(await third.start(build: '7', nativeCrash: false), isEmpty);
    expect(third.isDisabled(NativeGuard.tts), isTrue);
  });

  test('a marker without a native crash switches nothing off', () async {
    final first = NativeGuard(dir.path);
    await first.start(build: '7', nativeCrash: false);
    first.begin(NativeGuard.llm); // swiped away mid-reply

    final second = NativeGuard(dir.path);
    expect(await second.start(build: '7', nativeCrash: false), isEmpty);
    expect(second.disabled, isEmpty);
    expect(marker(NativeGuard.llm).existsSync(), isFalse);
  });

  test('a new build and the parent button switch engines back on', () async {
    final first = NativeGuard(dir.path);
    await first.start(build: '7', nativeCrash: false);
    first.begin(NativeGuard.stt);
    final second = NativeGuard(dir.path);
    await second.start(build: '7', nativeCrash: true);
    expect(second.isDisabled(NativeGuard.stt), isTrue);

    final updated = NativeGuard(dir.path);
    await updated.start(build: '8', nativeCrash: false);
    expect(updated.disabled, isEmpty);

    final again = NativeGuard(dir.path);
    again.begin(NativeGuard.ink);
    final afterCrash = NativeGuard(dir.path);
    await afterCrash.start(build: '8', nativeCrash: true);
    expect(afterCrash.isDisabled(NativeGuard.ink), isTrue);
    await afterCrash.enableAll();
    final later = NativeGuard(dir.path);
    await later.start(build: '8', nativeCrash: false);
    expect(later.disabled, isEmpty);
  });

  test('the disabled guard never touches the disk', () async {
    final guard = NativeGuard.disabled();
    expect(await guard.start(build: '1', nativeCrash: true), isEmpty);
    guard.begin(NativeGuard.tts);
    guard.end(NativeGuard.tts);
    expect(dir.listSync(), isEmpty);
  });
}
