// lib/curriculum/curriculum_loader.dart
import 'dart:convert';

import 'package:flutter/services.dart';

import 'models.dart';

/// Loads every unit file listed in assets/curriculum/index.json.
class CurriculumLoader {
  const CurriculumLoader._();

  static const String indexPath = 'assets/curriculum/index.json';

  static Future<Curriculum> load([AssetBundle? bundle]) async {
    final assets = bundle ?? rootBundle;
    final index = jsonDecode(await assets.loadString(indexPath));
    final files = index is Map<String, dynamic> ? (index['units'] as List? ?? const []) : const [];
    final units = <Unit>[];
    for (final file in files) {
      final raw = jsonDecode(await assets.loadString('assets/curriculum/$file'));
      if (raw is Map<String, dynamic>) {
        units.add(Unit.fromJson(raw));
      }
    }
    return Curriculum(units);
  }
}
