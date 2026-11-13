// lib/curriculum/daily_hello.dart
//
// "Chào Bi mỗi ngày": a three-minute talk every day that follows the child's
// real day: how they feel, Bi's garden news, two small questions about
// their day, the pocket phrase of the day and a tiny mission to say
// something in English to the family tonight. Yesterday's mission is asked
// about the next morning.
//
// Built as a talk script in the same format as assets/talk/*.txt, so the
// guided talk screen plays it with karaoke, meanings, pictures and the mic.
// Pure Dart.
import 'bi_world.dart';
import 'pocket_phrases.dart';

class HelloOption {
  const HelloOption(this.emoji, this.en, this.vi, this.reply, {this.noteKey, this.noteValue});

  final String emoji;
  final String en;
  final String vi;
  final BiLine reply;

  /// What Bi notes down in its notebook when the child picks this answer.
  final String? noteKey;
  final String? noteValue;
}

class HelloQuestion {
  const HelloQuestion(this.id, this.pic, this.question, this.options, {this.minLevel = 0, this.noteKey});

  final String id;
  final String pic;
  final BiLine question;
  final List<HelloOption> options;
  final int minLevel;

  /// Skipped while Bi already knows this about the child.
  final String? noteKey;
}

class HelloMission {
  const HelloMission(this.id, this.en, this.vi);

  final String id;
  final String en;
  final String vi;
}

/// One day's hello, ready to play.
class DailyHelloPlan {
  const DailyHelloPlan({
    required this.scriptId,
    required this.text,
    required this.mission,
    required this.phrase,
    required this.notes,
    required this.checksMission,
  });

  final String scriptId;

  /// The talk script (assets/talk format).
  final String text;
  final HelloMission mission;
  final PocketPhrase phrase;

  /// Option English text -> (note key, value) for Bi's notebook.
  final Map<String, (String, String)> notes;

  /// True when the talk asks about yesterday's mission.
  final bool checksMission;
}

class DailyHello {
  const DailyHello._();

  static const String topic = 'hello';

  static const List<HelloMission> missions = [
    HelloMission('love', 'Say "I love you, Mum!" to Mum.', 'Nói "I love you, Mum!" với mẹ nhé.'),
    HelloMission('night', 'Say "Good night, Dad!" to Dad at bedtime.', 'Trước khi ngủ, nói "Good night, Dad!" với bố nhé.'),
    HelloMission('thanks', 'Say "Thank you!" when someone helps you.', 'Khi ai đó giúp cậu, hãy nói "Thank you!" nhé.'),
    HelloMission('count', 'Count to five in English with Dad.', 'Đếm từ một đến năm bằng tiếng Anh cùng bố nhé.'),
    HelloMission('yummy', 'Say "Dinner is yummy!" at dinner.', 'Trong bữa tối, nói "Dinner is yummy!" nhé.'),
    HelloMission('help', 'Ask Mum: "Can I help you?"', 'Hỏi mẹ: "Can I help you?" nhé.'),
    HelloMission('home', 'Say "I\'m home!" when you come home.', 'Khi về đến nhà, nói "I\'m home!" nhé.'),
    HelloMission('red', 'Find something red and tell Mum: "It\'s red!"', 'Tìm một đồ vật màu đỏ rồi nói với mẹ: "It\'s red!" nhé.'),
    HelloMission('grandma', 'Ask Grandma: "How are you?"', 'Hỏi bà: "How are you?" nhé.'),
    HelloMission('play', 'Say "Let\'s play!" to a friend.', 'Rủ bạn chơi bằng câu "Let\'s play!" nhé.'),
    HelloMission('please', 'Say "Yes, please!" or "No, thank you." at dinner.', 'Trong bữa ăn, nói "Yes, please!" hoặc "No, thank you." nhé.'),
    HelloMission('morning', 'Say "Good morning!" to your family tomorrow.', 'Sáng mai nói "Good morning!" với cả nhà nhé.'),
    HelloMission('animal', 'Tell Dad the name of an animal in English.', 'Nói với bố tên một con vật bằng tiếng Anh nhé.'),
    HelloMission('dreams', 'Say "Sweet dreams!" to Mum at bedtime.', 'Trước khi ngủ, nói "Sweet dreams!" với mẹ nhé.'),
  ];

  static HelloMission? missionById(String id) {
    for (final m in missions) {
      if (m.id == id) {
        return m;
      }
    }
    return null;
  }

  static const List<HelloQuestion> questions = [
    HelloQuestion('breakfast', '🍳', BiLine('What did you eat for breakfast?', 'Sáng nay cậu ăn gì?'), [
      HelloOption('🍜', 'I ate noodles.', 'Tớ ăn phở.', BiLine('Noodles! Yummy!', 'Phở à! Ngon quá!'),
          noteKey: 'food', noteValue: 'noodles'),
      HelloOption('🥖', 'I ate bread.', 'Tớ ăn bánh mì.', BiLine('Bread! I love bread too!', 'Bánh mì à! Tớ cũng thích bánh mì!'),
          noteKey: 'food', noteValue: 'bread'),
      HelloOption('🍚', 'I ate rice.', 'Tớ ăn cơm.', BiLine('Rice gives you power!', 'Cơm cho cậu thật nhiều sức!'),
          noteKey: 'food', noteValue: 'rice'),
      HelloOption('🥛', 'I drank milk.', 'Tớ uống sữa.', BiLine('Milk makes you strong!', 'Sữa giúp cậu khoẻ mạnh!')),
    ]),
    HelloQuestion('play', '🎈', BiLine('What do you want to play today?', 'Hôm nay cậu muốn chơi gì?'), [
      HelloOption('⚽', 'I want to play football.', 'Tớ muốn đá bóng.', BiLine('Kick, kick, goal!', 'Sút, sút, vào!'),
          noteKey: 'game', noteValue: 'football'),
      HelloOption('🧩', 'I want to do puzzles.', 'Tớ muốn chơi xếp hình.', BiLine('I love puzzles too!', 'Tớ cũng thích xếp hình!'),
          noteKey: 'game', noteValue: 'puzzles'),
      HelloOption('🎨', 'I want to draw.', 'Tớ muốn vẽ tranh.', BiLine('Draw a bee for me, please!', 'Vẽ tặng tớ một chú ong nhé!'),
          noteKey: 'game', noteValue: 'drawing'),
      HelloOption('🚲', 'I want to ride my bike.', 'Tớ muốn đạp xe.', BiLine('Wow! Be careful and have fun!', 'Oa! Cẩn thận và chơi vui nhé!'),
          noteKey: 'game', noteValue: 'riding a bike'),
    ]),
    HelloQuestion('animal', '🐾', BiLine("What's your favourite animal?", 'Cậu thích con vật nào nhất?'), [
      HelloOption('🐶', 'I like dogs.', 'Tớ thích chó.', BiLine('Woof, woof! Dogs are great!', 'Gâu gâu! Chó đáng yêu lắm!'),
          noteKey: 'animal', noteValue: 'dogs'),
      HelloOption('🐱', 'I like cats.', 'Tớ thích mèo.', BiLine('Meow! Cats are so soft!', 'Meo meo! Mèo mềm mại quá!'),
          noteKey: 'animal', noteValue: 'cats'),
      HelloOption('🐘', 'I like elephants.', 'Tớ thích voi.', BiLine('Elephants are big and kind!', 'Voi to và hiền lắm!'),
          noteKey: 'animal', noteValue: 'elephants'),
      HelloOption('🐰', 'I like rabbits.', 'Tớ thích thỏ.', BiLine('Hop, hop! Rabbits are cute!', 'Nhảy, nhảy! Thỏ dễ thương quá!'),
          noteKey: 'animal', noteValue: 'rabbits'),
    ], noteKey: 'animal'),
    HelloQuestion('colour', '🎨', BiLine("What's your favourite colour?", 'Cậu thích màu gì nhất?'), [
      HelloOption('🔴', 'I like red.', 'Tớ thích màu đỏ.', BiLine('Red like a strawberry!', 'Đỏ như quả dâu tây!'),
          noteKey: 'colour', noteValue: 'red'),
      HelloOption('🔵', 'I like blue.', 'Tớ thích màu xanh dương.', BiLine('Blue like the sky!', 'Xanh như bầu trời!'),
          noteKey: 'colour', noteValue: 'blue'),
      HelloOption('💛', 'I like yellow.', 'Tớ thích màu vàng.', BiLine('Me too! Yellow like honey!', 'Tớ cũng thế! Vàng như mật ong!'),
          noteKey: 'colour', noteValue: 'yellow'),
      HelloOption('💚', 'I like green.', 'Tớ thích màu xanh lá.', BiLine('Green like the leaves!', 'Xanh như lá cây!'),
          noteKey: 'colour', noteValue: 'green'),
    ], noteKey: 'colour'),
    HelloQuestion('weather', '⛅', BiLine("What's the weather like today?", 'Hôm nay trời thế nào?'), [
      HelloOption('☀️', "It's sunny.", 'Trời nắng.', BiLine('Sunny days are happy days!', 'Ngày nắng là ngày vui!')),
      HelloOption('🌧️', "It's rainy.", 'Trời mưa.', BiLine("Don't forget your umbrella!", 'Nhớ mang ô nhé!')),
      HelloOption('☁️', "It's cloudy.", 'Trời nhiều mây.', BiLine('The clouds look like cotton!', 'Mây trông như bông gòn!')),
      HelloOption('💨', "It's windy.", 'Trời có gió.', BiLine('Whoosh! Hold your hat!', 'Vù vù! Giữ chặt mũ nhé!')),
    ]),
    HelloQuestion('fruit', '🍓', BiLine('Which fruit do you like?', 'Cậu thích quả gì?'), [
      HelloOption('🥭', 'I like mangoes.', 'Tớ thích xoài.', BiLine('Mangoes are so sweet!', 'Xoài ngọt lắm!'),
          noteKey: 'fruit', noteValue: 'mangoes'),
      HelloOption('🍌', 'I like bananas.', 'Tớ thích chuối.', BiLine('Bananas are yummy!', 'Chuối ngon tuyệt!'),
          noteKey: 'fruit', noteValue: 'bananas'),
      HelloOption('🍉', 'I like watermelon.', 'Tớ thích dưa hấu.', BiLine('Watermelon is so juicy!', 'Dưa hấu mọng nước quá!'),
          noteKey: 'fruit', noteValue: 'watermelon'),
      HelloOption('🍎', 'I like apples.', 'Tớ thích táo.', BiLine('Crunch, crunch! Apples!', 'Rộp rộp! Táo giòn quá!'),
          noteKey: 'fruit', noteValue: 'apples'),
    ], noteKey: 'fruit'),
    HelloQuestion('toy', '🧸', BiLine("What's your favourite toy?", 'Đồ chơi cậu thích nhất là gì?'), [
      HelloOption('🧸', 'My teddy bear.', 'Gấu bông của tớ.', BiLine('A teddy bear is a good friend!', 'Gấu bông là người bạn tốt!'),
          noteKey: 'toy', noteValue: 'teddy bear'),
      HelloOption('🚗', 'My toy car.', 'Ô tô đồ chơi của tớ.', BiLine('Vroom, vroom!', 'Brừm, brừm!'),
          noteKey: 'toy', noteValue: 'toy car'),
      HelloOption('🪁', 'My kite.', 'Con diều của tớ.', BiLine('Up, up in the sky!', 'Bay cao, bay cao lên trời!'),
          noteKey: 'toy', noteValue: 'kite'),
      HelloOption('🧱', 'My blocks.', 'Bộ xếp hình của tớ.', BiLine("Let's build a big tower!", 'Mình xây một toà tháp thật cao nhé!'),
          noteKey: 'toy', noteValue: 'blocks'),
    ], noteKey: 'toy'),
    HelloQuestion('help', '🧹', BiLine('How can you help at home today?', 'Hôm nay cậu giúp gì ở nhà?'), [
      HelloOption('🧹', 'I can sweep the floor.', 'Tớ quét nhà.', BiLine('What a big helper!', 'Cậu giỏi giúp việc quá!')),
      HelloOption('🍽️', 'I can set the table.', 'Tớ dọn bát đũa.', BiLine('Thank you! Dinner time!', 'Cảm ơn cậu! Đến giờ ăn tối rồi!')),
      HelloOption('🌱', 'I can water the plants.', 'Tớ tưới cây.', BiLine('The plants say thank you!', 'Cây cối cảm ơn cậu đấy!')),
      HelloOption('🧺', 'I can tidy my toys.', 'Tớ cất đồ chơi.', BiLine('Wow, so tidy!', 'Oa, gọn gàng quá!')),
    ]),
    HelloQuestion('go', '🗺️', BiLine('Where do you want to go?', 'Cậu muốn đi đâu?'), [
      HelloOption('🏞️', 'To the park.', 'Đi công viên.', BiLine('The park is so much fun!', 'Công viên vui lắm!'),
          noteKey: 'place', noteValue: 'the park'),
      HelloOption('🦁', 'To the zoo.', 'Đi sở thú.', BiLine('Roar! Say hello to the lions!', 'Gầm gừ! Chào các bạn sư tử nhé!'),
          noteKey: 'place', noteValue: 'the zoo'),
      HelloOption('🏖️', 'To the beach.', 'Đi biển.', BiLine('Sand and waves! Yay!', 'Cát và sóng biển! Tuyệt!'),
          noteKey: 'place', noteValue: 'the beach'),
      HelloOption('👵', "To Grandma's house.", 'Sang nhà bà.', BiLine('Give Grandma a big hug!', 'Ôm bà thật chặt nhé!'),
          noteKey: 'place', noteValue: "Grandma's house"),
    ], minLevel: 1),
    HelloQuestion('sleep', '🌙', BiLine('Did you sleep well?', 'Đêm qua cậu ngủ ngon không?'), [
      HelloOption('😊', 'Yes, I did.', 'Có, tớ ngủ ngon.', BiLine('Great! Now you have lots of energy!', 'Tuyệt! Giờ cậu tràn đầy năng lượng!')),
      HelloOption('😪', 'No, I didn\'t.', 'Không, tớ ngủ không ngon.', BiLine('Oh. Go to bed early tonight, okay?', 'Ôi. Tối nay đi ngủ sớm nhé!')),
      HelloOption('💭', 'I had a dream.', 'Tớ nằm mơ.', BiLine('A dream! I dream about flowers.', 'Nằm mơ à! Tớ hay mơ thấy hoa.')),
    ]),
  ];

  static String _greeting(DateTime now, String name) {
    if (now.hour < 11) {
      return 'bi: Good morning, $name! | Chào buổi sáng, $name!';
    }
    if (now.hour < 17) {
      return 'bi: Good afternoon, $name! | Chào buổi chiều, $name!';
    }
    return 'bi: Good evening, $name! | Chào buổi tối, $name!';
  }

  /// Names go into the script text: keep them away from its syntax.
  static String _clean(String text) =>
      text.replaceAll('|', ' ').replaceAll('->', ' ').replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _date(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  /// Builds today's hello.
  ///
  /// [knownNotes] are the keys Bi already knows (their questions are left
  /// for later); [missionToCheck] is the last mission, asked about when it
  /// was given on an earlier day and not checked yet.
  static DailyHelloPlan build({
    required String childName,
    required int level,
    required DateTime now,
    required PocketProgress pocket,
    Set<String> knownNotes = const {},
    HelloMission? missionToCheck,
  }) {
    final name = _clean(childName).isEmpty ? 'friend' : _clean(childName);
    final day = BiWorld.dayNumber(now);
    final news = BiWorld.newsFor(now);
    final out = StringBuffer()
      ..writeln('=== chat hello_${_date(now)}')
      ..writeln('topic: $topic')
      ..writeln('emoji: 🌞')
      ..writeln('title: Hello, Bi! | Chào Bi mỗi ngày')
      ..writeln('level: 0')
      ..writeln('roles: bi=Bi|Bi|🐝, kid=Me|Bé|🧒')
      ..writeln()
      ..writeln('[start]')
      ..writeln('pic: 🌞')
      ..writeln(_greeting(now, name))
      ..writeln('bi: How are you today? | Hôm nay cậu thấy thế nào?')
      ..writeln('? kid')
      ..writeln("- 😄 I'm happy! | Tớ vui lắm! -> f_happy")
      ..writeln("- 😴 I'm sleepy. | Tớ buồn ngủ. -> f_sleepy")
      ..writeln("- 🙂 I'm okay. | Tớ bình thường. -> f_ok")
      ..writeln("- 😢 I'm sad. | Tớ buồn. -> f_sad")
      ..writeln('[f_happy]')
      ..writeln("bi: Yay! I'm happy too! | Tuyệt! Tớ cũng vui!")
      ..writeln('-> news')
      ..writeln('[f_sleepy]')
      ..writeln("bi: Me too! Let's stretch. Up, up, up! | Tớ cũng thế! Mình vươn vai nào. Lên, lên, lên!")
      ..writeln('-> news')
      ..writeln('[f_ok]')
      ..writeln("bi: Okay! Let's have fun together. | Được rồi! Mình cùng chơi vui nhé.")
      ..writeln('-> news')
      ..writeln('[f_sad]')
      ..writeln("bi: Oh no. I'm here with you. | Ôi. Có tớ ở đây với cậu nè.")
      ..writeln('bi: Tell Mum or Dad. A big hug helps! | Cậu kể với bố mẹ nhé. Một cái ôm thật chặt sẽ đỡ hơn!')
      ..writeln('-> news')
      ..writeln('[news]')
      ..writeln('pic: 🌻')
      ..writeln('bi: Guess what? ${news.en} | Cậu biết không? ${news.vi}');

    final checks = missionToCheck != null;
    if (missionToCheck != null) {
      out
        ..writeln('[mission_check]')
        ..writeln('pic: 🎯')
        ..writeln("bi: Yesterday's mission: ${missionToCheck.en} | Nhiệm vụ hôm qua: ${missionToCheck.vi}")
        ..writeln('bi: Did you do it? | Cậu làm chưa?')
        ..writeln('? kid')
        ..writeln('- 🙋 Yes, I did! | Rồi, tớ làm rồi! -> m_yes')
        ..writeln('- 🙊 Not yet. | Chưa ạ. -> m_no')
        ..writeln('[m_yes]')
        ..writeln('bi: Wow! You are a star! | Oa! Cậu giỏi quá!')
        ..writeln('-> q0')
        ..writeln('[m_no]')
        ..writeln("bi: That's okay. You can try today! | Không sao đâu. Hôm nay cậu thử nhé!")
        ..writeln('-> q0');
    }

    // Two questions of the day; ones whose answer Bi already knows wait.
    final open = questions.where((q) => q.minLevel <= level).toList();
    final fresh = open.where((q) => q.noteKey == null || !knownNotes.contains(q.noteKey)).toList();
    final pool = fresh.length >= 2 ? fresh : open;
    final first = pool[(day * 2) % pool.length];
    var second = pool[(day * 2 + 1) % pool.length];
    if (second.id == first.id) {
      second = pool[(day * 2 + 2) % pool.length];
    }
    final notes = <String, (String, String)>{};
    final chosen = [first, second];
    for (var i = 0; i < chosen.length; i++) {
      final q = chosen[i];
      final next = i == 0 ? 'q1' : 'phrase';
      out
        ..writeln('[q$i]')
        ..writeln('pic: ${q.pic}')
        ..writeln('bi: ${q.question.en} | ${q.question.vi}')
        ..writeln('? kid');
      for (var j = 0; j < q.options.length; j++) {
        final o = q.options[j];
        out.writeln('- ${o.emoji} ${o.en} | ${o.vi} -> q${i}_$j');
        if (o.noteKey != null && o.noteValue != null) {
          notes[o.en] = (o.noteKey!, o.noteValue!);
        }
      }
      for (var j = 0; j < q.options.length; j++) {
        final o = q.options[j];
        out
          ..writeln('[q${i}_$j]')
          ..writeln('bi: ${o.reply.en} | ${o.reply.vi}')
          ..writeln('-> $next');
      }
    }

    final phrase = PocketPhrases.phraseOfDay(level, pocket, day);
    final mission = missions[day % missions.length];
    out
      ..writeln('[phrase]')
      ..writeln('pic: 🎒')
      ..writeln("bi: Here is today's pocket phrase. | Đây là câu bỏ túi hôm nay.")
      ..writeln('bi: ${phrase.situationEn} | ${phrase.situationVi}')
      ..writeln('kid: ${phrase.en} | ${phrase.vi}')
      ..writeln('bi: Great! Put it in your pocket! | Tuyệt! Cất câu này vào túi nhé!')
      ..writeln('[mission]')
      ..writeln('pic: 🎯')
      ..writeln('bi: Your mission for today: | Nhiệm vụ hôm nay của cậu:')
      ..writeln('bi: ${mission.en} | ${mission.vi}')
      ..writeln('bi: See you tomorrow! Bye-bye! | Hẹn gặp cậu ngày mai! Tạm biệt!')
      ..writeln('-> end');

    return DailyHelloPlan(
      scriptId: 'hello_${_date(now)}',
      text: out.toString(),
      mission: mission,
      phrase: phrase,
      notes: notes,
      checksMission: checks,
    );
  }
}
