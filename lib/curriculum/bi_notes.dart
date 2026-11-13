// lib/curriculum/bi_notes.dart
//
// "Sổ tay của Bi": a few safe things the child told Bi (favourite colour,
// animal, food, a pet's name, what they did today), so Bi can ask about them
// the next day. Kept on the phone only, shown to parents, who can delete any
// line or switch the notebook off. Never an address, a school, a phone
// number, a full name or anything with digits. Pure Dart.
import 'dart:convert';

import 'basic_words.dart';

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

  String encode() => jsonEncode({
    for (final n in _notes.values) n.key: {'v': n.value, 't': n.day},
  });

  /// One line for the model's instructions, e.g. "favourite animal: cats".
  String describeEn() => [for (final n in all) '${_phrasesEn[n.key] ?? n.key}: ${n.value}'].join('; ');

  /// Words the child may name, by notebook key, for the "I like ..." reading
  /// that works without the model. Checked in this order ("orange" is a
  /// colour first).
  static const Map<String, Set<String>> _known = {
    'animal': {
      'dog',
      'cat',
      'bird',
      'fish',
      'duck',
      'cow',
      'pig',
      'horse',
      'hen',
      'chicken',
      'sheep',
      'goat',
      'mouse',
      'frog',
      'monkey',
      'tiger',
      'bear',
      'giraffe',
      'hippo',
      'lion',
      'elephant',
      'rabbit',
      'bunny',
      'panda',
      'penguin',
      'dolphin',
      'whale',
      'shark',
      'owl',
      'kangaroo',
      'turtle',
      'zebra',
      'snake',
      'camel',
      'puppy',
      'kitten',
      'hamster',
      'parrot',
      'butterfly',
      'bee',
      'ant',
      'fox',
      'deer',
      'crocodile',
      'octopus',
      'unicorn',
      'dinosaur',
      'dragon',
    },
    'colour': {'red', 'blue', 'yellow', 'green', 'orange', 'pink', 'purple', 'black', 'white', 'brown', 'grey', 'gray'},
    'fruit': {
      'apple',
      'banana',
      'grape',
      'mango',
      'pear',
      'lemon',
      'watermelon',
      'pineapple',
      'coconut',
      'strawberry',
      'cherry',
      'peach',
      'papaya',
      'durian',
      'lychee',
    },
    'food': {
      'rice',
      'bread',
      'noodle',
      'pho',
      'cake',
      'pizza',
      'soup',
      'egg',
      'cheese',
      'chips',
      'burger',
      'candy',
      'sweet',
      'cookie',
      'biscuit',
      'chocolate',
      'ice cream',
      'spaghetti',
      'sushi',
      'meat',
      'mooncake',
    },
    'toy': {
      'ball',
      'doll',
      'car',
      'robot',
      'teddy',
      'teddy bear',
      'kite',
      'puzzle',
      'block',
      'lego',
      'train',
      'plane',
      'boat',
      'truck',
      'drum',
      'yo-yo',
      'balloon',
    },
  };

  static const Set<String> _sameInPlural = {
    'fish',
    'sheep',
    'deer',
    'rice',
    'bread',
    'pho',
    'cheese',
    'chips',
    'meat',
    'lego',
    'soup',
    'chocolate',
    'spaghetti',
    'sushi',
    'candy',
  };

  static final RegExp _likeRe = RegExp(r"\bi (?:really )?(?:like|love)s? (?:a |an |the |my )?([a-z][a-z -]*)");
  static final RegExp _favouriteRe = RegExp(
    r"\bmy fav(?:ou?rite)? (colou?r|animal|food|fruit|toy) is (?:a |an |the )?([a-z][a-z -]*)",
  );

  /// "cat" -> "cats" so Bi can say "I remember you like cats!".
  static String plural(String word) {
    if (_sameInPlural.contains(word) || word.endsWith('s') || word.contains(' ')) {
      return word;
    }
    if (word == 'mouse') {
      return 'mice';
    }
    if (word.endsWith('y') && !RegExp('[aeiou]y\$').hasMatch(word)) {
      return '${word.substring(0, word.length - 1)}ies';
    }
    if (word.endsWith('x') || word.endsWith('ch') || word.endsWith('sh') || word == 'mango') {
      return '${word}es';
    }
    return '${word}s';
  }

  static Set<String> _singulars(String w) => {
    w,
    if (w.endsWith('s')) w.substring(0, w.length - 1),
    if (w.endsWith('es')) w.substring(0, w.length - 2),
    if (w.endsWith('ies')) '${w.substring(0, w.length - 3)}y',
    if (w == 'mice') 'mouse',
  };

  static String? _keyFor(String phrase) {
    final forms = _singulars(phrase);
    for (final e in _known.entries) {
      if (forms.any(e.value.contains)) {
        return e.key;
      }
    }
    return null;
  }

  /// A fact read straight from what the child said ("I like cats",
  /// "My favourite colour is blue"), without the model. Null when nothing
  /// fits.
  static (String, String)? fromChild(String said) {
    final t = said.toLowerCase().replaceAll(RegExp(r"[^a-z' -]"), ' ').replaceAll(RegExp(r'\s+'), ' ');
    final fav = _favouriteRe.firstMatch(t);
    if (fav != null) {
      final key = fav.group(1)!.startsWith('col') ? 'colour' : fav.group(1)!;
      final value = fav.group(2)!.trim().split(' ').take(2).join(' ');
      if (_keyFor(value) == key || key == 'colour' && _known['colour']!.contains(value)) {
        return (key, key == 'animal' ? plural(value) : value);
      }
      return null;
    }
    final like = _likeRe.firstMatch(t);
    if (like == null) {
      return null;
    }
    final words = like.group(1)!.trim().split(' ');
    // "ice cream", "teddy bear" before "ice", "teddy".
    for (final phrase in [if (words.length > 1) '${words[0]} ${words[1]}', words[0]]) {
      final key = _keyFor(phrase);
      if (key != null) {
        return (key, key == 'animal' ? plural(phrase) : phrase);
      }
    }
    return null;
  }

  /// True when the child really said [value]: each of its words (or a
  /// plural/singular form) is in [said], which holds what the child said and
  /// the corrected English sentence. Stops the model from writing down
  /// things the child never told Bi. A "today" or "wish" line needs one
  /// grounded word, since Bi retells it in its own words.
  static bool grounded(String key, String value, String said) {
    final heard = <String>{};
    for (final w in RegExp("[a-z']+").allMatches(said.toLowerCase())) {
      final word = w.group(0)!;
      heard
        ..add(word)
        ..add(plural(word));
      if (word.endsWith('s')) {
        heard.add(word.substring(0, word.length - 1));
      }
      if (word.endsWith('ies')) {
        heard.add('${word.substring(0, word.length - 3)}y');
      }
    }
    const small = {'a', 'an', 'the', 'my', 'to', 'and', 'of', 'in', 'on', 'with', 'go', 'play', 'playing'};
    final words = [
      for (final w in RegExp("[a-z']+").allMatches(value.toLowerCase())) w.group(0)!,
    ].where((w) => !small.contains(w)).toList();
    if (words.isEmpty) {
      return false;
    }
    final found = words.where((w) => wordVariants(w).any(heard.contains)).length;
    return (key == 'today' || key == 'wish') ? found >= 1 : found == words.length;
  }

  /// The fact to keep after one turn: the model's NOTE when the child really
  /// said it, else what "I like ..." in the child's words gives, else null.
  static (String, String)? choose((String, String)? modelNote, String said) {
    if (modelNote != null &&
        validate(modelNote.$1, modelNote.$2) != null &&
        grounded(modelNote.$1, modelNote.$2, said)) {
      final (key, value) = modelNote;
      return (key, key == 'animal' && !value.contains(' ') ? plural(value.toLowerCase()) : value);
    }
    return fromChild(said);
  }

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
