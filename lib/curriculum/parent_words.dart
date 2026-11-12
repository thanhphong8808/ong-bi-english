// lib/curriculum/parent_words.dart
//
// Rules for the words parents add (pure Dart, shared by the screen and tests).

/// English word or short phrase: letters, spaces, apostrophes and hyphens.
final RegExp parentWordPattern = RegExp(r"^[A-Za-z][A-Za-z' \-]{0,39}$");

/// An optional example sentence in plain English.
final RegExp parentExamplePattern = RegExp(r"^[A-Za-z0-9 ,.!?'\-]{0,120}$");

String _squash(String text) => text.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Cleans the English word a parent typed; null when it cannot be used.
String? cleanParentWord(String text) {
  final value = _squash(text);
  return parentWordPattern.hasMatch(value) ? value : null;
}

/// Cleans an example sentence; null when it cannot be used ('' is fine).
String? cleanParentExample(String text) {
  final value = _squash(text);
  return parentExamplePattern.hasMatch(value) ? value : null;
}
