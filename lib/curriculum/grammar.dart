// lib/curriculum/grammar.dart
//
// Grammar lessons (assets/grammar/grammar.json, built by
// tool/grammar/build_grammar.py): a short spoken explanation in Vietnamese,
// a table, examples and practice. Practice is "pick the missing word" or
// "put the words in order". Also the tense overview and the verb table.
// Pure Dart.
import 'dart:convert';
import 'dart:math';

class GrammarStage {
  const GrammarStage({required this.stage, required this.nameVi, required this.nameEn, required this.emoji});

  final int stage;
  final String nameVi;
  final String nameEn;
  final String emoji;
}

class GrammarExample {
  const GrammarExample(this.en, this.vi);

  final String en;
  final String vi;
}

enum GrammarTaskKind { choose, order }

/// One practice question.
class GrammarTask {
  const GrammarTask.choose({
    required this.question,
    required this.answer,
    required this.options,
    required this.vi,
    required this.whyVi,
    this.lessonId = '',
  })  : kind = GrammarTaskKind.choose,
        words = const [];

  const GrammarTask.order({required this.words, required this.vi, this.lessonId = ''})
      : kind = GrammarTaskKind.order,
        question = '',
        answer = '',
        options = const [],
        whyVi = '';

  final GrammarTaskKind kind;

  /// "She ___ my mum." Two blanks take a comma-separated answer.
  final String question;
  final String answer;
  final List<String> options;

  /// Words of the sentence in the right order (order tasks).
  final List<String> words;
  final String vi;
  final String whyVi;
  final String lessonId;

  GrammarTask withLesson(String id) => kind == GrammarTaskKind.choose
      ? GrammarTask.choose(question: question, answer: answer, options: options, vi: vi, whyVi: whyVi, lessonId: id)
      : GrammarTask.order(words: words, vi: vi, lessonId: id);

  /// A hint in brackets after the sentence, "(gần, một cái)".
  static final RegExp _hint = RegExp(r'\s*\(([^)]*)\)\s*$');

  /// The question without its bracketed hint.
  String get questionText => question.replaceAll(_hint, '').trim();

  /// The bracketed hint, or empty.
  String get hint => _hint.firstMatch(question)?.group(1)?.trim() ?? '';

  /// The finished English sentence, to show and say after answering.
  String get sentence {
    if (kind == GrammarTaskKind.order) {
      final text = words.join(' ');
      return vi.trim().endsWith('?') ? '$text?' : '$text.';
    }
    final parts = answer.split(',').map((s) => s.trim()).toList();
    var out = questionText;
    for (final part in parts) {
      out = out.replaceFirst('___', part);
    }
    return out;
  }

  /// Whether [picked] (the words tapped, in order) is the right sentence.
  bool orderIsRight(List<String> picked) {
    if (picked.length != words.length) {
      return false;
    }
    for (var i = 0; i < words.length; i++) {
      if (picked[i] != words[i]) {
        return false;
      }
    }
    return true;
  }
}

class GrammarLesson {
  const GrammarLesson({
    required this.id,
    required this.stage,
    required this.emoji,
    required this.titleEn,
    required this.titleVi,
    required this.explainVi,
    required this.tableHead,
    required this.tableRows,
    required this.examples,
    required this.practice,
  });

  final String id;
  final int stage;
  final String emoji;
  final String titleEn;
  final String titleVi;

  /// Short sentences Bi says, one after another.
  final List<String> explainVi;
  final List<String> tableHead;
  final List<List<String>> tableRows;
  final List<GrammarExample> examples;
  final List<GrammarTask> practice;
}

class GrammarTense {
  const GrammarTense({
    required this.id,
    required this.emoji,
    required this.nameEn,
    required this.nameVi,
    required this.useVi,
    required this.yes,
    required this.no,
    required this.ask,
    required this.signals,
    required this.example,
    required this.lessonId,
  });

  final String id;
  final String emoji;
  final String nameEn;
  final String nameVi;
  final String useVi;
  final String yes;
  final String no;
  final String ask;
  final String signals;
  final GrammarExample example;
  final String lessonId;
}

class GrammarVerb {
  const GrammarVerb({
    required this.base,
    required this.third,
    required this.ing,
    required this.past,
    required this.pastParticiple,
    required this.vi,
    required this.emoji,
    required this.irregular,
  });

  final String base;

  /// he / she / it form: plays, goes.
  final String third;
  final String ing;
  final String past;
  final String pastParticiple;
  final String vi;
  final String emoji;
  final bool irregular;
}

class GrammarBook {
  const GrammarBook({required this.stages, required this.lessons, required this.tenses, required this.verbs});

  final List<GrammarStage> stages;
  final List<GrammarLesson> lessons;
  final List<GrammarTense> tenses;
  final List<GrammarVerb> verbs;

  static const GrammarBook empty = GrammarBook(stages: [], lessons: [], tenses: [], verbs: []);

  GrammarLesson? lesson(String id) {
    for (final l in lessons) {
      if (l.id == id) {
        return l;
      }
    }
    return null;
  }

  List<GrammarLesson> ofStage(int stage) => lessons.where((l) => l.stage == stage).toList();

  /// The app level (0-5) from which a stage is suggested.
  static int levelForStage(int stage) => stage.clamp(1, 5).toInt();

  /// A mixed test: [count] questions from [fromLessons] (all lessons when
  /// empty), spread over the lessons, mostly "pick the word", shuffled.
  List<GrammarTask> mixedTest({List<String> fromLessons = const [], int count = 12, Random? random}) {
    final rng = random ?? Random();
    final pool = fromLessons.isEmpty ? lessons : lessons.where((l) => fromLessons.contains(l.id)).toList();
    if (pool.isEmpty) {
      return const [];
    }
    final perLesson = [
      for (final l in pool)
        ([for (final t in l.practice) t.withLesson(l.id)]..shuffle(rng)),
    ]..shuffle(rng);
    final out = <GrammarTask>[];
    var round = 0;
    while (out.length < count) {
      var added = false;
      for (final tasks in perLesson) {
        if (round < tasks.length && out.length < count) {
          // Mostly choose tasks: an order task only every fourth question.
          final task = tasks[round];
          if (task.kind == GrammarTaskKind.order && out.length % 4 != 3) {
            continue;
          }
          out.add(task);
          added = true;
        }
      }
      if (!added && round > 12) {
        break;
      }
      round++;
    }
    return out..shuffle(rng);
  }

  static GrammarBook parse(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    List<String> strings(Object? v) => [for (final s in (v as List? ?? const [])) '$s'];
    final stages = [
      for (final s in data['stages'] as List)
        GrammarStage(
          stage: (s as Map)['stage'] as int,
          nameVi: s['name_vi'] as String,
          nameEn: s['name_en'] as String,
          emoji: s['emoji'] as String,
        ),
    ];
    final lessons = <GrammarLesson>[];
    for (final raw in data['lessons'] as List) {
      final l = raw as Map;
      final table = l['table'] as Map? ?? const {};
      final practice = <GrammarTask>[];
      for (final p in l['practice'] as List) {
        final m = p as Map;
        if (m['kind'] == 'order') {
          practice.add(GrammarTask.order(words: strings(m['words']), vi: m['vi'] as String));
        } else {
          practice.add(GrammarTask.choose(
            question: m['q'] as String,
            answer: m['answer'] as String,
            options: strings(m['options']),
            vi: m['vi'] as String,
            whyVi: m['why_vi'] as String? ?? '',
          ));
        }
      }
      lessons.add(GrammarLesson(
        id: l['id'] as String,
        stage: l['stage'] as int,
        emoji: l['emoji'] as String,
        titleEn: l['title_en'] as String,
        titleVi: l['title_vi'] as String,
        explainVi: strings(l['explain_vi']),
        tableHead: strings(table['head']),
        tableRows: [for (final r in (table['rows'] as List? ?? const [])) strings(r)],
        examples: [
          for (final e in l['examples'] as List) GrammarExample((e as Map)['en'] as String, e['vi'] as String),
        ],
        practice: practice,
      ));
    }
    final tenses = [
      for (final raw in data['tenses'] as List)
        GrammarTense(
          id: (raw as Map)['id'] as String,
          emoji: raw['emoji'] as String,
          nameEn: raw['name_en'] as String,
          nameVi: raw['name_vi'] as String,
          useVi: raw['use_vi'] as String,
          yes: raw['yes'] as String,
          no: raw['no'] as String,
          ask: raw['ask'] as String,
          signals: raw['signals'] as String,
          example: GrammarExample((raw['example'] as Map)['en'] as String, raw['example']['vi'] as String),
          lessonId: raw['lesson'] as String,
        ),
    ];
    final verbs = [
      for (final raw in data['verbs'] as List)
        GrammarVerb(
          base: (raw as Map)['base'] as String,
          third: raw['s'] as String,
          ing: raw['ing'] as String,
          past: raw['past'] as String,
          pastParticiple: raw['pp'] as String,
          vi: raw['vi'] as String,
          emoji: raw['emoji'] as String,
          irregular: raw['irregular'] as bool? ?? false,
        ),
    ];
    return GrammarBook(stages: stages, lessons: lessons, tenses: tenses, verbs: verbs);
  }
}

/// Score of a practice round, 0..1, from right answers out of [total].
double grammarScore(int right, int total) => total <= 0 ? 0 : (right / total).clamp(0.0, 1.0).toDouble();

/// Stars for a practice score, 1-3.
int grammarStars(double score) => score >= 0.9 ? 3 : (score >= 0.6 ? 2 : 1);
