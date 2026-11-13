// lib/curriculum/talk_scripts.dart
//
// Guided conversations with Bi: everyday topics, role-plays where the child
// picks a role, and fables with questions. Every line is bilingual and every
// turn of the child offers 1-3 answers to choose from, so a 6-year-old always
// knows what to say. Written in a small text format (assets/talk/*.txt):
//
//   @topic daily | 🌞 | Daily life | Hằng ngày | morning, breakfast, school
//
//   === chat good_morning                 (chat | role | story)
//   topic: daily
//   emoji: 🌅
//   title: Good morning | Chào buổi sáng
//   level: 0
//   roles: bi=Bi|Bi|🐝, kid=Me|Bé|🧒
//   moral: Slow and steady wins. | Chậm mà chắc.      (stories only)
//
//   [start]
//   pic: 🌅
//   scene: 1                              (stories: illustration number)
//   bi: Good morning! How are you? | Chào buổi sáng! Cậu thế nào?
//   ? kid
//   - 😀 I'm happy! | Tớ vui! -> happy
//   - 😴 I'm sleepy. | Tớ buồn ngủ.          (no arrow: the next block)
//   [happy]
//   bi: Great! | Tuyệt!
//   -> end
//
// A line said by the child's role is a turn with one answer (say it after
// Bi). In role-plays Bi plays every role the child did not pick, choosing at
// random where that role has options. Pure Dart.

class TalkTopic {
  const TalkTopic({required this.id, required this.emoji, required this.en, required this.vi, required this.words});

  final String id;
  final String emoji;
  final String en;
  final String vi;

  /// Words for free chat with Bi's brain about this topic.
  final List<String> words;
}

class TalkRole {
  const TalkRole({required this.id, required this.en, required this.vi, required this.emoji});

  final String id;
  final String en;
  final String vi;
  final String emoji;
}

sealed class TalkItem {
  const TalkItem();
}

/// A spoken line.
class TalkLine extends TalkItem {
  const TalkLine({required this.role, required this.en, required this.vi});

  final String role;
  final String en;
  final String vi;
}

/// The scene picture changes.
class TalkPicture extends TalkItem {
  const TalkPicture(this.emoji);

  final String emoji;
}

/// A story illustration, `assets/story_art/{script id}_{index}.webp` with a
/// two-digit index, shown when that picture is in the app (00 is the cover).
class TalkScene extends TalkItem {
  const TalkScene(this.index);

  final int index;
}

class TalkOption {
  const TalkOption({required this.emoji, required this.en, required this.vi, this.next});

  final String emoji;
  final String en;
  final String vi;

  /// Block to go to; null means the block after the current one.
  final String? next;
}

class TalkChoice {
  const TalkChoice({required this.role, required this.options});

  /// Who chooses: the child when it is the child's role, otherwise Bi.
  final String role;
  final List<TalkOption> options;
}

class TalkBlock {
  const TalkBlock({required this.id, required this.items, this.choice, this.next, this.fallthrough});

  final String id;
  final List<TalkItem> items;
  final TalkChoice? choice;

  /// Explicit "-> target" after the lines.
  final String? next;

  /// The block written after this one (used when there is no arrow).
  final String? fallthrough;

  /// Where the conversation goes after this block when there is no choice.
  String get after => next ?? fallthrough ?? TalkScript.end;
}

enum TalkKind { chat, role, story }

class TalkScript {
  const TalkScript({
    required this.kind,
    required this.id,
    required this.topic,
    required this.emoji,
    required this.titleEn,
    required this.titleVi,
    required this.level,
    required this.roles,
    required this.blocks,
    required this.startId,
    this.moralEn = '',
    this.moralVi = '',
  });

  static const String end = 'end';
  static const String kidRole = 'kid';
  static const String biRole = 'bi';

  final TalkKind kind;
  final String id;
  final String topic;
  final String emoji;
  final String titleEn;
  final String titleVi;
  final int level;
  final List<TalkRole> roles;
  final Map<String, TalkBlock> blocks;
  final String startId;
  final String moralEn;
  final String moralVi;

  TalkRole? role(String id) {
    for (final r in roles) {
      if (r.id == id) {
        return r;
      }
    }
    return null;
  }

  /// Roles the child can play (role-plays); chats and stories: the child.
  List<TalkRole> get playableRoles =>
      kind == TalkKind.role ? roles.where((r) => r.id != biRole).toList() : roles.where((r) => r.id == kidRole).toList();
}

class TalkLibrary {
  TalkLibrary({required this.topics, required this.scripts});

  static final TalkLibrary empty = TalkLibrary(topics: const [], scripts: const []);

  final List<TalkTopic> topics;
  final List<TalkScript> scripts;

  List<TalkScript> of(TalkKind kind, {String? topic}) =>
      scripts.where((s) => s.kind == kind && (topic == null || s.topic == topic)).toList();

  TalkTopic? topic(String id) {
    for (final t in topics) {
      if (t.id == id) {
        return t;
      }
    }
    return null;
  }

  TalkScript? script(String id) {
    for (final s in scripts) {
      if (s.id == id) {
        return s;
      }
    }
    return null;
  }
}

class TalkFormatException implements Exception {
  TalkFormatException(this.message);

  final String message;

  @override
  String toString() => 'TalkFormatException: $message';
}

/// Parses one or more talk files into a library.
class TalkParser {
  const TalkParser();

  TalkLibrary parse(List<String> files) {
    final topics = <TalkTopic>[];
    final scripts = <TalkScript>[];
    for (final text in files) {
      _parseFile(text, topics, scripts);
    }
    return TalkLibrary(topics: topics, scripts: scripts);
  }

  static (String, String) _bilingual(String text, String where) {
    final bar = text.indexOf('|');
    if (bar < 0) {
      throw TalkFormatException('$where: missing "| Vietnamese" in "$text"');
    }
    return (text.substring(0, bar).trim(), text.substring(bar + 1).trim());
  }

  void _parseFile(String text, List<TalkTopic> topics, List<TalkScript> scripts) {
    _ScriptBuilder? current;
    var lineNo = 0;
    for (final raw in text.split('\n')) {
      lineNo++;
      final line = raw.trim();
      final where = 'line $lineNo';
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }
      if (line.startsWith('@topic ')) {
        final f = line.substring(7).split('|').map((s) => s.trim()).toList();
        if (f.length < 4) {
          throw TalkFormatException('$where: @topic needs id | emoji | English | Vietnamese | words');
        }
        topics.add(TalkTopic(
          id: f[0],
          emoji: f[1],
          en: f[2],
          vi: f[3],
          words: f.length > 4 ? f[4].split(',').map((w) => w.trim()).where((w) => w.isNotEmpty).toList() : const [],
        ));
        continue;
      }
      if (line.startsWith('=== ')) {
        if (current != null) {
          scripts.add(current.build());
        }
        final parts = line.substring(4).trim().split(RegExp(r'\s+'));
        if (parts.length != 2) {
          throw TalkFormatException('$where: "=== kind id"');
        }
        final kind = TalkKind.values.where((k) => k.name == parts[0]).firstOrNull;
        if (kind == null) {
          throw TalkFormatException('$where: unknown kind ${parts[0]}');
        }
        current = _ScriptBuilder(kind, parts[1]);
        continue;
      }
      final b = current;
      if (b == null) {
        throw TalkFormatException('$where: text before the first "==="');
      }
      b.add(line, where);
    }
    if (current != null) {
      scripts.add(current.build());
    }
  }
}

class _ScriptBuilder {
  _ScriptBuilder(this.kind, this.id);

  final TalkKind kind;
  final String id;
  String topic = '';
  String emoji = '';
  String titleEn = '';
  String titleVi = '';
  int level = 0;
  final List<TalkRole> roles = [];
  String moralEn = '';
  String moralVi = '';

  final List<String> _order = [];
  final Map<String, List<TalkItem>> _items = {};
  final Map<String, String> _next = {};
  final Map<String, TalkChoice> _choices = {};
  String? _block;
  String? _choiceRole;
  List<TalkOption>? _options;

  void _closeChoice() {
    final role = _choiceRole;
    final options = _options;
    if (role != null && options != null && _block != null) {
      _choices[_block!] = TalkChoice(role: role, options: List.unmodifiable(options));
    }
    _choiceRole = null;
    _options = null;
  }

  void add(String line, String where) {
    if (line.startsWith('[') && line.endsWith(']')) {
      _closeChoice();
      final id = line.substring(1, line.length - 1).trim();
      if (_items.containsKey(id)) {
        throw TalkFormatException('$where: block [$id] twice in ${this.id}');
      }
      _block = id;
      _order.add(id);
      _items[id] = [];
      return;
    }
    if (_block == null) {
      _header(line, where);
      return;
    }
    final block = _block!;
    if (line.startsWith('->')) {
      _closeChoice();
      _next[block] = line.substring(2).trim();
      return;
    }
    if (line.startsWith('? ')) {
      _closeChoice();
      _choiceRole = line.substring(2).trim();
      _options = [];
      return;
    }
    if (line.startsWith('- ')) {
      final options = _options;
      if (options == null) {
        throw TalkFormatException('$where: option without "? role" in $id');
      }
      var body = line.substring(2).trim();
      String? next;
      final arrow = body.lastIndexOf('->');
      if (arrow >= 0) {
        next = body.substring(arrow + 2).trim();
        body = body.substring(0, arrow).trim();
      }
      final space = body.indexOf(' ');
      if (space < 0) {
        throw TalkFormatException('$where: option needs "emoji English | Vietnamese"');
      }
      final emoji = body.substring(0, space);
      final (en, vi) = TalkParser._bilingual(body.substring(space + 1), where);
      options.add(TalkOption(emoji: emoji, en: en, vi: vi, next: next));
      return;
    }
    if (_options != null) {
      throw TalkFormatException('$where: lines after options in [$block] of $id (start a new block)');
    }
    if (line.startsWith('pic:')) {
      _items[block]!.add(TalkPicture(line.substring(4).trim()));
      return;
    }
    if (line.startsWith('scene:')) {
      final index = int.tryParse(line.substring(6).trim());
      if (index == null || index < 0 || index > 20) {
        throw TalkFormatException('$where: "scene: <number 0-20>" in $id');
      }
      _items[block]!.add(TalkScene(index));
      return;
    }
    final colon = line.indexOf(':');
    if (colon <= 0) {
      throw TalkFormatException('$where: cannot read "$line" in $id');
    }
    final role = line.substring(0, colon).trim();
    final (en, vi) = TalkParser._bilingual(line.substring(colon + 1), where);
    _items[block]!.add(TalkLine(role: role, en: en, vi: vi));
  }

  void _header(String line, String where) {
    final colon = line.indexOf(':');
    if (colon <= 0) {
      throw TalkFormatException('$where: header "key: value" expected in $id');
    }
    final key = line.substring(0, colon).trim();
    final value = line.substring(colon + 1).trim();
    switch (key) {
      case 'topic':
        topic = value;
      case 'emoji':
        emoji = value;
      case 'title':
        final (en, vi) = TalkParser._bilingual(value, where);
        titleEn = en;
        titleVi = vi;
      case 'level':
        level = int.tryParse(value) ?? (throw TalkFormatException('$where: level must be a number'));
      case 'moral':
        final (en, vi) = TalkParser._bilingual(value, where);
        moralEn = en;
        moralVi = vi;
      case 'roles':
        for (final part in value.split(',')) {
          final eq = part.indexOf('=');
          if (eq <= 0) {
            throw TalkFormatException('$where: role "id=English|Vietnamese|emoji"');
          }
          final f = part.substring(eq + 1).split('|').map((s) => s.trim()).toList();
          if (f.length != 3) {
            throw TalkFormatException('$where: role "id=English|Vietnamese|emoji"');
          }
          roles.add(TalkRole(id: part.substring(0, eq).trim(), en: f[0], vi: f[1], emoji: f[2]));
        }
      default:
        throw TalkFormatException('$where: unknown header "$key" in $id');
    }
  }

  TalkScript build() {
    _closeChoice();
    if (_order.isEmpty) {
      throw TalkFormatException('$id has no blocks');
    }
    final blocks = <String, TalkBlock>{};
    for (var i = 0; i < _order.length; i++) {
      final id = _order[i];
      blocks[id] = TalkBlock(
        id: id,
        items: List.unmodifiable(_items[id]!),
        choice: _choices[id],
        next: _next[id],
        fallthrough: i + 1 < _order.length ? _order[i + 1] : null,
      );
    }
    return TalkScript(
      kind: kind,
      id: id,
      topic: topic,
      emoji: emoji,
      titleEn: titleEn,
      titleVi: titleVi,
      level: level,
      roles: List.unmodifiable(roles),
      blocks: blocks,
      startId: _order.first,
      moralEn: moralEn,
      moralVi: moralVi,
    );
  }
}

/// Where a choice's option leads (its arrow, or the block after).
String optionTarget(TalkBlock block, TalkOption option) => option.next ?? block.fallthrough ?? TalkScript.end;
