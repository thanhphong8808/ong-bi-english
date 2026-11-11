// tool/coverage_report.dart
//
// Prints how much content each level and unit contains:
//   dart run tool/coverage_report.dart
import 'dart:convert';
import 'dart:io';

const String curriculumRoot = 'assets/curriculum';

class Counts {
  int units = 0;
  int words = 0;
  int letters = 0;
  int patterns = 0;
  int dialogues = 0;
  int readings = 0;
  int questions = 0;

  void add(Counts o) {
    units += o.units;
    words += o.words;
    letters += o.letters;
    patterns += o.patterns;
    dialogues += o.dialogues;
    readings += o.readings;
    questions += o.questions;
  }
}

int lengthOf(Map<String, dynamic> map, String key) {
  final value = map[key];
  return value is List ? value.length : 0;
}

String pad(Object value, [int width = 8]) => '$value'.padLeft(width);

String row(String label, Counts c) =>
    '${label.padRight(10)}${pad(c.words)}${pad(c.letters)}${pad(c.patterns)}${pad(c.dialogues)}'
    '${pad(c.readings)}${pad(c.questions)}';

void main() {
  final index = jsonDecode(File('$curriculumRoot/index.json').readAsStringSync()) as Map<String, dynamic>;
  final perLevel = <int, Counts>{};
  final total = Counts();
  stdout.writeln('${'Unit'.padRight(10)}${pad('Words')}${pad('Letters')}${pad('Pattern')}${pad('Dialog')}'
      '${pad('Reading')}${pad('Quiz')}');
  for (final file in index['units'] as List) {
    final unit = jsonDecode(File('$curriculumRoot/$file').readAsStringSync()) as Map<String, dynamic>;
    final items = (unit['items'] as List).cast<Map<String, dynamic>>();
    final c = Counts()
      ..units = 1
      ..words = items.where((i) => i['type'] != 'letter').length
      ..letters = items.where((i) => i['type'] == 'letter').length
      ..patterns = lengthOf(unit, 'patterns')
      ..dialogues = lengthOf(unit, 'dialogues')
      ..readings = lengthOf(unit, 'readings')
      ..questions = lengthOf(unit, 'quiz_bank');
    perLevel.putIfAbsent(unit['level'] as int, Counts.new).add(c);
    total.add(c);
    stdout.writeln(row('${unit['id']}', c));
  }
  stdout.writeln('');
  var cumulative = 0;
  final levels = perLevel.keys.toList()..sort();
  for (final level in levels) {
    final c = perLevel[level]!;
    cumulative += c.words;
    stdout.writeln('${row('Level $level', c)}   units: ${c.units}   cumulative words: $cumulative');
  }
  stdout.writeln('${row('TOTAL', total)}   units: ${total.units}');
}
