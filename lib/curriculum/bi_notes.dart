// lib/curriculum/bi_notes.dart
//
// "Sổ tay của Bi": a few safe things the child told Bi (favourite colour,
// animal, food, a pet's name, what they did today), so Bi can ask about them
// the next day. Kept on the phone only, shown to parents, who can delete any
// line or switch the notebook off. Never an address, a school, a phone
// number, a full name or anything with digits. Pure Dart.
import 'dart:convert';

class BiNote {
  const BiNote(this.key, this.value, this.day);

  final String key;
  final String value;

  /// Day number when Bi wrote it down.
  final int day;
}

class BiNotes {
  BiNotes(this._notes);

  factory BiNotes.decode(String? raw) {
    final notes = <String, BiNote>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in map.entries) {
          final v = e.value as Map<String, dynamic>;
          final value = '${v['v'] ?? ''}';
          final clean = validate(e.key, value);
          if (clean != null) {
            notes[e.key] = BiNote(e.key, clean, (v['t'] as num?)?.toInt() ?? 0);
          }
        }
      } catch (_) {
        // A damaged notebook starts empty.
      }
    }
    return BiNotes(notes);
  }

  static const String key = 'bi_notes';
  static const String offKey = 'bi_notes_off';

  /// Allowed keys with the label parents see.
  static const Map<String, String> labelsVi = {
    'colour': 'Màu yêu thích',
    'animal': 'Con vật yêu thích',
    'food': 'Món ăn yêu thích',
    'fruit': 'Hoa quả yêu thích',
    'toy': 'Đồ chơi yêu thích',
    'game': 'Trò chơi yêu thích',
    'place': 'Nơi bé muốn đến',
    'pet': 'Thú cưng',
    'pet_name': 'Tên thú cưng',
    'hobby': 'Sở thích',
    'today': 'Chuyện bé kể hôm nay',
    'wish': 'Điều bé mong',
  };

  /// How Bi talks about each key in its instructions.
  static const Map<String, String> _phrasesEn = {
    'colour': 'favourite colour',
    'animal': 'favourite animal',
    'food': 'favourite food',
    'fruit': 'favourite fruit',
    'toy': 'favourite toy',
    'game': 'favourite game',
    'place': 'place they want to go',
    'pet': 'pet',
    'pet_name': "pet's name",
    'hobby': 'hobby',
    'today': 'what they did recently',
    'wish': 'what they wish for',
  };

  static final RegExp _shape = RegExp(r"^[A-Za-z][A-Za-z' -]*$");

  final Map<String, BiNote> _notes;

  List<BiNote> get all => _notes.values.toList()..sort((a, b) => a.key.compareTo(b.key));

  Set<String> get keys => _notes.keys.toSet();

  bool get isEmpty => _notes.isEmpty;

  String? operator [](String key) => _notes[key]?.value;

  /// The cleaned value, or null when [key] or [value] may not be kept.
  static String? validate(String key, String value) {
    if (!labelsVi.containsKey(key)) {
      return null;
    }
    var v = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    v = v.replaceAll(RegExp(r'[.!?,;:]+$'), '');
    if (v.isEmpty || v == '-' || !_shape.hasMatch(v)) {
      return null;
    }
    final words = v.split(' ').length;
    final maxWords = (key == 'today' || key == 'wish') ? 8 : 4;
    if (words > maxWords || v.length > 60) {
      return null;
    }
    if (key == 'pet_name') {
      if (words > 1 || v.length > 12) {
        return null;
      }
      return v[0].toUpperCase() + v.substring(1).toLowerCase();
    }
    return v;
  }

  /// Stores [value] under [key] when it passes [validate]. Returns true when
  /// something new was written.
  bool put(String key, String value, int day) {
    final clean = validate(key, value);
    if (clean == null || _notes[key]?.value == clean) {
      return false;
    }
    _notes[key] = BiNote(key, clean, day);
    return true;
  }

  void remove(String key) => _notes.remove(key);

  String encode() => jsonEncode({for (final n in _notes.values) n.key: {'v': n.value, 't': n.day}});

  /// One line for the model's instructions, e.g. "favourite animal: cats".
  String describeEn() =>
      [for (final n in all) '${_phrasesEn[n.key] ?? n.key}: ${n.value}'].join('; ');

  /// Parses a model line "key=value" (or "key: value").
  static (String, String)? parseLine(String line) {
    final t = line.trim();
    if (t.isEmpty || t == '-') {
      return null;
    }
    final sep = t.contains('=') ? t.indexOf('=') : t.indexOf(':');
    if (sep <= 0) {
      return null;
    }
    final k = t.substring(0, sep).trim().toLowerCase().replaceAll(' ', '_').replaceAll('favourite_', '');
    final v = t.substring(sep + 1).trim();
    return (k == 'color' ? 'colour' : k, v);
  }
}
