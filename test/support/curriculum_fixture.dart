// test/support/curriculum_fixture.dart
//
// Loads the real curriculum from assets/ with dart:io, so tests check the
// content that ships in the APK (tests run from the project root).
import 'dart:convert';
import 'dart:io';

import 'package:ong_bi_english/curriculum/models.dart';

Curriculum? _cached;

Curriculum loadCurriculum() {
  return _cached ??= () {
    final index = jsonDecode(File('assets/curriculum/index.json').readAsStringSync()) as Map<String, dynamic>;
    final units = <Unit>[
      for (final file in index['units'] as List)
        Unit.fromJson(jsonDecode(File('assets/curriculum/$file').readAsStringSync()) as Map<String, dynamic>),
    ];
    return Curriculum(units);
  }();
}
