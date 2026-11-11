// test/assets_test.dart
//
// Every file the app loads at run time must exist and be declared in
// pubspec.yaml, otherwise it is silently left out of the APK.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/curriculum_fixture.dart';

/// Asset entries and font files declared in pubspec.yaml.
({List<String> assets, List<String> fonts}) declared() {
  final assets = <String>[];
  final fonts = <String>[];
  var section = '';
  for (final line in File('pubspec.yaml').readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed == 'assets:') {
      section = 'assets';
      continue;
    }
    if (trimmed == 'fonts:' && line.startsWith('  fonts:')) {
      section = 'fonts';
      continue;
    }
    if (section == 'assets' && trimmed.startsWith('- ')) {
      assets.add(trimmed.substring(2).trim());
    } else if (section == 'fonts' && trimmed.startsWith('- asset:')) {
      fonts.add(trimmed.substring('- asset:'.length).trim());
    } else if (section == 'fonts' && trimmed.startsWith('asset:')) {
      fonts.add(trimmed.substring('asset:'.length).trim());
    } else if (line.isNotEmpty && !line.startsWith(' ')) {
      section = '';
    }
  }
  return (assets: assets, fonts: fonts);
}

/// A file is bundled when it is listed itself or its own folder is listed
/// (Flutter does not include sub-folders of a listed folder).
bool isBundled(String path, List<String> assets) {
  final folder = path.substring(0, path.lastIndexOf('/') + 1);
  return assets.contains(path) || assets.contains(folder);
}

void main() {
  final d = declared();
  final c = loadCurriculum();

  test('the curriculum index and every unit file are bundled', () {
    expect(isBundled('assets/curriculum/index.json', d.assets), isTrue);
    final index = jsonDecode(File('assets/curriculum/index.json').readAsStringSync()) as Map<String, dynamic>;
    final files = (index['units'] as List).cast<String>();
    expect(files.length, c.units.length);
    for (final f in files) {
      expect(File('assets/curriculum/$f').existsSync(), isTrue, reason: f);
      expect(isBundled('assets/curriculum/$f', d.assets), isTrue, reason: f);
    }
  });

  test('no unit file is left out of the index', () {
    final index = jsonDecode(File('assets/curriculum/index.json').readAsStringSync()) as Map<String, dynamic>;
    final listed = (index['units'] as List).cast<String>().toSet();
    final onDisk = Directory('assets/curriculum')
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path.replaceFirst('assets/curriculum/', ''))
        .where((p) => p.endsWith('.json') && p != 'index.json')
        .toSet();
    expect(onDisk.difference(listed), isEmpty);
  });

  test('every picture referenced by the curriculum exists and is bundled', () {
    for (final item in c.units.expand((u) => u.items)) {
      final svg = item.image.svg;
      if (svg != null) {
        final path = 'assets/svg/$svg';
        expect(File(path).existsSync(), isTrue, reason: '${item.id} $path');
        expect(isBundled(path, d.assets), isTrue, reason: path);
      }
      if (item.picturable) {
        expect(item.image.isEmpty, isFalse, reason: '${item.id} ${item.en} is picturable but has no picture');
      }
    }
  });

  test('Bi has a picture for every mood and every outfit layer', () {
    for (final mood in const ['happy', 'listening', 'thinking', 'cheering', 'sleeping']) {
      expect(File('assets/svg/bi_$mood.svg').existsSync(), isTrue, reason: mood);
    }
    for (final layer in const ['cap', 'bow', 'glasses', 'scarf', 'grad']) {
      expect(File('assets/svg/outfit_$layer.svg').existsSync(), isTrue, reason: layer);
    }
    expect(isBundled('assets/svg/bi_happy.svg', d.assets), isTrue);
  });

  test('declared fonts exist and come with their licences', () {
    expect(d.fonts, isNotEmpty);
    for (final font in d.fonts) {
      expect(File(font).existsSync(), isTrue, reason: font);
    }
    for (final licence in const ['Andika-OFL.txt', 'Nunito-OFL.txt', 'NotoColorEmoji-OFL.txt']) {
      expect(File('assets/fonts/$licence').existsSync(), isTrue, reason: licence);
    }
  });

  test('every unit has enough questions and texts', () {
    for (final unit in c.units) {
      expect(unit.quizBank.length, greaterThanOrEqualTo(30), reason: unit.id);
      expect(unit.items, isNotEmpty, reason: unit.id);
      for (final item in unit.items) {
        expect(item.en.trim(), isNotEmpty, reason: item.id);
        expect(item.vi.trim(), isNotEmpty, reason: item.id);
      }
      if (unit.level >= 1) {
        expect(unit.dialogues.length, greaterThanOrEqualTo(2), reason: unit.id);
      }
      if (unit.level >= 2) {
        expect(unit.readings, isNotEmpty, reason: unit.id);
      }
    }
  });
}
