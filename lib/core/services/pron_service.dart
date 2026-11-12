// lib/core/services/pron_service.dart
//
// Loads the bundled pronunciation dictionary once, in the background.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../curriculum/models.dart';
import '../../curriculum/pron_lexicon.dart';

class PronService {
  PronService(this.curriculum);

  static const String asset = 'assets/pron/ipa_en_us.txt.gz';

  final Curriculum curriculum;

  /// Curriculum words only until the dictionary has loaded.
  late final ValueNotifier<PronLexicon> lexicon = ValueNotifier<PronLexicon>(PronLexicon(const [], extra: _extra()));

  Future<void>? _loading;

  Map<String, String> _extra() => {
        for (final unit in curriculum.units)
          for (final item in unit.items)
            if (item.type == ItemType.word && item.ipa.isNotEmpty && !item.en.contains(' ')) item.en.toLowerCase(): item.ipa,
      };

  /// Safe to call many times; failures leave the curriculum-only lexicon.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final data = await rootBundle.load(asset);
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final lines = await Isolate.run(() {
        final text = utf8.decode(GZipCodec().decode(bytes));
        return text.split('\n').where((l) => l.isNotEmpty).toList(growable: false);
      });
      lexicon.value = PronLexicon(lines, extra: _extra());
    } catch (_) {
      // Pronunciation is a bonus: the words are still shown.
    }
  }
}
