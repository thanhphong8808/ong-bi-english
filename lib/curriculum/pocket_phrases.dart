// lib/curriculum/pocket_phrases.dart
//
// "Câu bỏ túi": about 80 ready-made sentences a child uses every day, plus
// rescue sentences for when they get stuck ("Say it again, please", "I don't
// know", "How do you say this in English?"). Each one comes with a small
// situation Bi sets up, so the child practises using it, not only saying it.
// Reviews follow a simple Leitner schedule. Pure Dart.
import 'dart:convert';

class PhraseGroup {
  const PhraseGroup(this.id, this.emoji, this.vi);

  final String id;
  final String emoji;
  final String vi;
}

class PocketPhrase {
  const PocketPhrase(this.id, this.group, this.level, this.emoji, this.en, this.vi, this.situationEn, this.situationVi);

  final String id;
  final String group;

  /// 0-2: the lowest child level the phrase is offered at.
  final int level;
  final String emoji;
  final String en;
  final String vi;

  /// Bi sets the scene, ending with "What do you say?".
  final String situationEn;
  final String situationVi;

  bool get rescue => group == 'rescue';
}

class PocketPhrases {
  const PocketPhrases._();

  static const List<PhraseGroup> groups = [
    PhraseGroup('rescue', '🆘', 'Câu cứu nguy'),
    PhraseGroup('hello', '👋', 'Chào hỏi'),
    PhraseGroup('needs', '🙋', 'Khi cần gì'),
    PhraseGroup('feelings', '😊', 'Cảm xúc'),
    PhraseGroup('play', '🧸', 'Khi chơi'),
    PhraseGroup('school', '🏫', 'Ở lớp'),
    PhraseGroup('home', '🏠', 'Ở nhà'),
    PhraseGroup('ask', '❓', 'Hỏi bạn'),
  ];

  static const String _say = 'What do you say?';
  static const String _sayVi = 'Cậu nói gì nhỉ?';
  static const String _ask = 'What do you ask?';
  static const String _askVi = 'Cậu hỏi thế nào nhỉ?';

  static const List<PocketPhrase> all = [
    // Rescue phrases: what to say when stuck.
    PocketPhrase('r_again', 'rescue', 0, '🔁', 'Say it again, please.', 'Cậu nói lại nhé.',
        "Oops! You didn't hear Bi. $_say", 'Ối! Cậu chưa nghe rõ Bi nói. $_sayVi'),
    PocketPhrase('r_dontknow', 'rescue', 0, '🤷', "I don't know.", 'Tớ không biết.',
        "That's a very hard question! $_say", 'Câu hỏi khó quá! $_sayVi'),
    PocketPhrase('r_slowly', 'rescue', 0, '🐢', 'Slowly, please.', 'Cậu nói chậm thôi.',
        'Bi talks too fast! $_say', 'Bi nói nhanh quá! $_sayVi'),
    PocketPhrase('r_think', 'rescue', 0, '🤔', 'Let me think.', 'Để tớ nghĩ đã.',
        'Bi asks a question. You need time. $_say', 'Bi hỏi một câu. Cậu cần nghĩ một chút. $_sayVi'),
    PocketPhrase('r_whatsthis', 'rescue', 0, '👉', "What's this?", 'Cái này là gì?',
        'You see a funny thing. You want to know. $_ask', 'Cậu thấy một thứ lạ. Cậu muốn biết. $_askVi'),
    PocketPhrase('r_wait', 'rescue', 0, '✋', 'Wait a minute, please.', 'Đợi tớ một chút nhé.',
        'You are not ready yet. $_say', 'Cậu chưa sẵn sàng. $_sayVi'),
    PocketPhrase('r_dontunderstand', 'rescue', 1, '😕', "I don't understand.", 'Tớ không hiểu.',
        "You don't understand Bi. $_say", 'Cậu không hiểu Bi nói gì. $_sayVi'),
    PocketPhrase('r_help', 'rescue', 1, '🆘', 'Can you help me, please?', 'Cậu giúp tớ được không?',
        'Your shoe is untied. You need help. $_say', 'Dây giày của cậu bị tuột. Cậu cần giúp. $_sayVi'),
    PocketPhrase('r_howsay', 'rescue', 1, '💬', 'How do you say this in English?', 'Cái này tiếng Anh nói thế nào?',
        'You want to know an English word. $_ask', 'Cậu muốn biết một từ tiếng Anh. $_askVi'),
    PocketPhrase('r_mean', 'rescue', 2, '❓', 'What does it mean?', 'Nghĩa là gì vậy?',
        'You hear a new word. $_ask', 'Cậu nghe thấy một từ mới. $_askVi'),

    // Hello and manners.
    PocketPhrase('h_hello', 'hello', 0, '👋', 'Hello!', 'Xin chào!',
        'You meet your friend. $_say', 'Cậu gặp bạn. $_sayVi'),
    PocketPhrase('h_morning', 'hello', 0, '🌅', 'Good morning!', 'Chào buổi sáng!',
        'It is morning. You see your teacher. $_say', 'Buổi sáng, cậu gặp cô giáo. $_sayVi'),
    PocketPhrase('h_bye', 'hello', 0, '👋', 'Goodbye! See you!', 'Tạm biệt! Hẹn gặp lại!',
        "It's time to go home. $_say", 'Đến giờ về nhà rồi. $_sayVi'),
    PocketPhrase('h_thanks', 'hello', 0, '🙏', 'Thank you!', 'Cảm ơn!',
        'Mum gives you a cake. $_say', 'Mẹ cho cậu một cái bánh. $_sayVi'),
    PocketPhrase('h_welcome', 'hello', 0, '😊', "You're welcome.", 'Không có gì.',
        'Your friend says "Thank you!". $_say', 'Bạn nói "Cảm ơn!" với cậu. $_sayVi'),
    PocketPhrase('h_sorry', 'hello', 0, '😔', "I'm sorry.", 'Tớ xin lỗi.',
        "Oops! You step on your friend's foot. $_say", 'Ối! Cậu giẫm vào chân bạn. $_sayVi'),
    PocketPhrase('h_yesplease', 'hello', 0, '🙏', 'Yes, please!', 'Vâng, cho con với ạ!',
        'Grandma asks: "Do you want some fruit?" You want some. $_say',
        'Bà hỏi: "Cháu ăn hoa quả không?" Cậu muốn ăn. $_sayVi'),
    PocketPhrase('h_nothanks', 'hello', 0, '🙅', 'No, thank you.', 'Thôi ạ, con cảm ơn.',
        'Grandma asks: "More rice?" You are full. $_say', 'Bà hỏi: "Ăn thêm cơm nhé?" Cậu no rồi. $_sayVi'),
    PocketPhrase('h_night', 'hello', 0, '🌙', 'Good night!', 'Chúc ngủ ngon!',
        "It's bedtime. $_say", 'Đến giờ đi ngủ rồi. $_sayVi'),
    PocketPhrase('h_excuse', 'hello', 1, '✋', 'Excuse me.', 'Xin lỗi cho con hỏi.',
        'You want to ask the teacher something. What do you say first?', 'Cậu muốn hỏi cô giáo. Cậu nói gì trước nhỉ?'),
    PocketPhrase('h_nicemeet', 'hello', 1, '🤝', 'Nice to meet you!', 'Rất vui được gặp cậu!',
        'You meet a new friend. $_say', 'Cậu gặp một người bạn mới. $_sayVi'),
    PocketPhrase('h_howareyou', 'hello', 1, '🙂', 'How are you?', 'Ông có khoẻ không ạ?',
        'You see Grandpa. You want to ask about him. $_ask', 'Cậu gặp ông. Cậu muốn hỏi thăm ông. $_askVi'),

    // Needs.
    PocketPhrase('n_hungry', 'needs', 0, '😋', "I'm hungry.", 'Con đói.',
        'Your tummy goes rumble, rumble! $_say', 'Bụng cậu kêu ùng ục! $_sayVi'),
    PocketPhrase('n_thirsty', 'needs', 0, '💧', "I'm thirsty.", 'Con khát nước.',
        "It's very hot. You want water. $_say", 'Trời nóng quá. Cậu muốn uống nước. $_sayVi'),
    PocketPhrase('n_more', 'needs', 0, '🍚', 'More, please!', 'Cho con thêm nữa ạ!',
        'The noodles are yummy. You want more. $_say', 'Mì ngon quá. Cậu muốn ăn thêm. $_sayVi'),
    PocketPhrase('n_tired', 'needs', 0, '😴', "I'm tired.", 'Con mệt rồi.',
        'You played all day. $_say', 'Cậu chơi cả ngày rồi. $_sayVi'),
    PocketPhrase('n_cold', 'needs', 0, '🥶', "I'm cold.", 'Con lạnh.',
        'Brrr! The wind is cold. $_say', 'Brrr! Gió lạnh quá. $_sayVi'),
    PocketPhrase('n_hot', 'needs', 0, '🥵', "I'm hot.", 'Con nóng quá.',
        'The sun is very hot. $_say', 'Nắng gắt quá. $_sayVi'),
    PocketPhrase('n_hurt', 'needs', 0, '🤕', 'It hurts!', 'Đau quá!',
        'You fall down. Your knee hurts. $_say', 'Cậu bị ngã. Đầu gối đau. $_sayVi'),
    PocketPhrase('n_water', 'needs', 1, '🥛', 'Can I have some water, please?', 'Cho con xin ít nước được không ạ?',
        'You are thirsty. Ask Mum for water. $_say', 'Cậu khát nước. Cậu xin mẹ nước nhé. $_sayVi'),
    PocketPhrase('n_toilet', 'needs', 1, '🚽', 'May I go to the toilet?', 'Con đi vệ sinh được không ạ?',
        'You are in class. You need the toilet. $_say', 'Cậu đang ở lớp và muốn đi vệ sinh. $_sayVi'),
    PocketPhrase('n_apple', 'needs', 1, '🍎', 'Can I have an apple, please?', 'Cho con một quả táo được không ạ?',
        'You see red apples. You want one. $_say', 'Cậu thấy táo đỏ. Cậu muốn một quả. $_sayVi'),
    PocketPhrase('n_outside', 'needs', 1, '🛝', 'I want to play outside.', 'Con muốn ra ngoài chơi.',
        'The sun is out! What do you want?', 'Trời nắng đẹp! Cậu muốn làm gì?'),
    PocketPhrase('n_finished', 'needs', 1, '✅', "I'm finished.", 'Con ăn xong rồi.',
        'You eat all your rice. $_say', 'Cậu ăn hết cơm rồi. $_sayVi'),

    // Feelings.
    PocketPhrase('f_happy', 'feelings', 0, '😄', "I'm happy!", 'Con vui lắm!',
        "It's your birthday! How do you feel?", 'Hôm nay sinh nhật cậu! Cậu thấy thế nào?'),
    PocketPhrase('f_sad', 'feelings', 0, '😢', "I'm sad.", 'Con buồn.',
        'Your toy is broken. How do you feel?', 'Đồ chơi của cậu bị hỏng. Cậu thấy thế nào?'),
    PocketPhrase('f_scared', 'feelings', 0, '😨', "I'm scared.", 'Con sợ.',
        'Boom! Thunder! How do you feel?', 'Đùng! Sấm to quá! Cậu thấy thế nào?'),
    PocketPhrase('f_love', 'feelings', 0, '❤️', 'I love you, Mum!', 'Con yêu mẹ!',
        'Mum gives you a big hug. $_say', 'Mẹ ôm cậu thật chặt. $_sayVi'),
    PocketPhrase('f_like', 'feelings', 0, '👍', 'I like it!', 'Con thích lắm!',
        'You try a new cake. It is yummy! $_say', 'Cậu ăn thử bánh mới. Ngon quá! $_sayVi'),
    PocketPhrase('f_dontlike', 'feelings', 0, '👎', "I don't like it.", 'Con không thích.',
        'You try a bitter vegetable. Yuck! $_say', 'Cậu ăn thử rau đắng. Eo ơi! $_sayVi'),
    PocketPhrase('f_okay', 'feelings', 0, '🙂', "I'm okay.", 'Con không sao.',
        'Mum asks: "Are you okay?" You are fine. $_say', 'Mẹ hỏi: "Con có sao không?" Cậu không sao. $_sayVi'),
    PocketPhrase('f_wow', 'feelings', 0, '😮', 'Wow! Cool!', 'Ồ! Hay quá!',
        'You see a big rainbow! $_say', 'Cậu thấy cầu vồng thật to! $_sayVi'),
    PocketPhrase('f_excited', 'feelings', 1, '🤩', "I'm so excited!", 'Con háo hức quá!',
        'Tomorrow you go to the zoo! How do you feel?', 'Ngày mai cậu đi sở thú! Cậu thấy thế nào?'),
    PocketPhrase('f_angry', 'feelings', 1, '😠', "I'm angry.", 'Con giận rồi.',
        'Your friend takes your toy. How do you feel?', 'Bạn lấy đồ chơi của cậu. Cậu thấy thế nào?'),

    // Play.
    PocketPhrase('p_letsplay', 'play', 0, '🧸', "Let's play!", 'Mình chơi đi!',
        'You see your friend. You want to play. $_say', 'Cậu gặp bạn và muốn chơi cùng. $_sayVi'),
    PocketPhrase('p_myturn', 'play', 0, '☝️', "It's my turn.", 'Đến lượt tớ.',
        'You are playing a game. Now it is you! $_say', 'Cậu đang chơi trò chơi. Đến cậu rồi! $_sayVi'),
    PocketPhrase('p_yourturn', 'play', 0, '👉', "It's your turn.", 'Đến lượt cậu.',
        'You finish. Now it is your friend. $_say', 'Cậu chơi xong. Giờ đến bạn. $_sayVi'),
    PocketPhrase('p_metoo', 'play', 0, '🙋', 'Me too!', 'Tớ cũng vậy!',
        'Your friend says: "I like ice cream!" You like it too. $_say',
        'Bạn nói: "Tớ thích kem!" Cậu cũng thích. $_sayVi'),
    PocketPhrase('p_goodjob', 'play', 0, '👏', 'Good job!', 'Giỏi lắm!',
        'Your friend draws a nice cat. $_say', 'Bạn vẽ một chú mèo rất đẹp. $_sayVi'),
    PocketPhrase('p_go', 'play', 0, '🏁', 'Ready, steady, go!', 'Chuẩn bị, sẵn sàng, chạy!',
        'You and your friend want to race. $_say', 'Cậu với bạn muốn thi chạy. $_sayVi'),
    PocketPhrase('p_iwin', 'play', 0, '🏆', 'Yay! I win!', 'Yeah! Tớ thắng rồi!',
        'You finish first! $_say', 'Cậu về đích đầu tiên! $_sayVi'),
    PocketPhrase('p_again', 'play', 0, '🔁', 'One more time!', 'Thêm một lần nữa!',
        'The game is so fun. You want to play again. $_say', 'Trò chơi vui quá. Cậu muốn chơi lại. $_sayVi'),
    PocketPhrase('p_where', 'play', 0, '🙈', 'Where are you?', 'Cậu ở đâu thế?',
        "You play hide and seek. You can't find your friend. $_say", 'Cậu chơi trốn tìm mà không tìm thấy bạn. $_sayVi'),
    PocketPhrase('p_comeon', 'play', 0, '🏃', 'Come on!', 'Nhanh lên nào!',
        'Your friend is slow. You want them to hurry. $_say', 'Bạn đi chậm quá. Cậu muốn bạn nhanh lên. $_sayVi'),
    PocketPhrase('p_join', 'play', 1, '🙌', 'Can I play too?', 'Tớ chơi cùng được không?',
        'Some kids are playing ball. You want to play. $_ask', 'Các bạn đang chơi bóng. Cậu muốn chơi cùng. $_askVi'),
    PocketPhrase('p_share', 'play', 1, '🤝', "Let's share.", 'Mình chia nhau nhé.',
        'You have two cookies. Your friend has none. $_say', 'Cậu có hai cái bánh, bạn không có cái nào. $_sayVi'),

    // School.
    PocketPhrase('s_here', 'school', 0, '🙋', "I'm here!", 'Con có mặt!',
        'The teacher calls your name. $_say', 'Cô giáo gọi tên cậu. $_sayVi'),
    PocketPhrase('s_done', 'school', 0, '📝', "I'm done, teacher!", 'Con làm xong rồi ạ!',
        'You finish your drawing. What do you tell the teacher?', 'Cậu vẽ xong rồi. Cậu nói gì với cô?'),
    PocketPhrase('s_look', 'school', 0, '🖼️', 'Look at my picture!', 'Nhìn tranh của tớ này!',
        'You draw a nice dog. You want your friend to see. $_say', 'Cậu vẽ một chú chó đẹp và muốn bạn xem. $_sayVi'),
    PocketPhrase('s_question', 'school', 1, '✋', 'I have a question.', 'Con có câu hỏi ạ.',
        'You want to ask the teacher. $_say', 'Cậu muốn hỏi cô giáo. $_sayVi'),
    PocketPhrase('s_borrow', 'school', 1, '✏️', 'Can I borrow your pencil?', 'Cho tớ mượn bút chì được không?',
        "You don't have a pencil. Your friend has two. $_ask", 'Cậu không có bút chì, bạn có hai cái. $_askVi'),
    PocketPhrase('s_repeat', 'school', 1, '👂', 'Can you say that again, please?', 'Cô nói lại được không ạ?',
        "You didn't hear the teacher. $_ask", 'Cậu không nghe rõ cô nói. $_askVi'),
    PocketPhrase('s_needhelp', 'school', 1, '🤗', 'Do you need help?', 'Cậu cần giúp không?',
        'Your friend drops the crayons. $_ask', 'Bạn làm rơi bút màu. $_askVi'),
    PocketPhrase('s_word', 'school', 2, '📖', 'What does this word mean?', 'Từ này nghĩa là gì ạ?',
        'You see a new word in your book. $_ask', 'Cậu thấy một từ mới trong sách. $_askVi'),

    // Home.
    PocketPhrase('o_home', 'home', 0, '🏠', "I'm home!", 'Con về rồi!',
        'You come back from school. $_say', 'Cậu đi học về. $_sayVi'),
    PocketPhrase('o_brushed', 'home', 0, '🪥', 'I brushed my teeth.', 'Con đánh răng rồi.',
        'Mum asks: "Did you brush your teeth?" You did. $_say',
        'Mẹ hỏi: "Con đánh răng chưa?" Cậu đánh rồi. $_sayVi'),
    PocketPhrase('o_yummy', 'home', 0, '🍲', 'Dinner is yummy!', 'Bữa tối ngon quá!',
        'Dad cooks a nice dinner. $_say', 'Bố nấu bữa tối thật ngon. $_sayVi'),
    PocketPhrase('o_teddy', 'home', 0, '🔍', 'Where is my teddy?', 'Gấu bông của con đâu rồi?',
        "You can't find your teddy bear. $_ask", 'Cậu không tìm thấy gấu bông. $_askVi'),
    PocketPhrase('o_hug', 'home', 1, '🤗', 'Can I have a hug?', 'Ôm con một cái được không ạ?',
        'You feel sleepy and want a hug from Mum. $_say', 'Cậu buồn ngủ và muốn mẹ ôm. $_sayVi'),
    PocketPhrase('o_help', 'home', 1, '🧹', 'Can I help you?', 'Con giúp mẹ được không ạ?',
        'Mum is cooking. You want to help. $_say', 'Mẹ đang nấu ăn. Cậu muốn giúp. $_sayVi'),
    PocketPhrase('o_cartoons', 'home', 1, '📺', 'Can I watch cartoons?', 'Con xem hoạt hình được không ạ?',
        'You finished your homework. $_ask', 'Cậu làm xong bài rồi. $_askVi'),
    PocketPhrase('o_story', 'home', 1, '📖', 'Read me a story, please.', 'Đọc truyện cho con nghe đi ạ.',
        "It's bedtime. You want a story. $_say", 'Đến giờ đi ngủ. Cậu muốn nghe truyện. $_sayVi'),

    // Asking friends.
    PocketPhrase('a_name', 'ask', 0, '🙂', "What's your name?", 'Bạn tên là gì?',
        'You meet a new friend. You want to know the name. $_ask', 'Cậu gặp bạn mới và muốn biết tên. $_askVi'),
    PocketPhrase('a_old', 'ask', 0, '🎂', 'How old are you?', 'Bạn mấy tuổi?',
        "You want to know your friend's age. $_ask", 'Cậu muốn biết bạn mấy tuổi. $_askVi'),
    PocketPhrase('a_like', 'ask', 0, '❓', 'What do you like?', 'Cậu thích gì?',
        'You want to know what Bi likes. $_ask', 'Cậu muốn biết Bi thích gì. $_askVi'),
    PocketPhrase('a_play', 'ask', 0, '🧩', 'Do you want to play?', 'Bạn có muốn chơi không?',
        'You want to play with a new kid. $_ask', 'Cậu muốn rủ một bạn mới chơi. $_askVi'),
    PocketPhrase('a_colour', 'ask', 0, '🎨', 'What colour is it?', 'Nó màu gì vậy?',
        'You want to know the colour of a flower. $_ask', 'Cậu muốn biết bông hoa màu gì. $_askVi'),
    PocketPhrase('a_toilet', 'ask', 1, '📍', 'Where is the toilet?', 'Nhà vệ sinh ở đâu ạ?',
        'You are at a new place. You need the toilet. $_ask', 'Cậu đến một nơi lạ và cần đi vệ sinh. $_askVi'),
    PocketPhrase('a_withyou', 'ask', 1, '🎈', 'Can I go with you?', 'Tớ đi cùng được không?',
        'Your friend is going to the playground. You want to go too. $_ask',
        'Bạn đi ra sân chơi. Cậu cũng muốn đi. $_askVi'),
    PocketPhrase('a_doing', 'ask', 1, '👀', 'What are you doing?', 'Cậu đang làm gì thế?',
        'You see your friend building something. $_ask', 'Cậu thấy bạn đang xây gì đó. $_askVi'),
  ];

  static PocketPhrase? byId(String id) {
    for (final p in all) {
      if (p.id == id) {
        return p;
      }
    }
    return null;
  }

  static List<PocketPhrase> ofGroup(String group) => all.where((p) => p.group == group).toList();

  /// Phrases a child at [level] can learn now.
  static List<PocketPhrase> forLevel(int level) => all.where((p) => p.level <= level).toList();

  /// The phrase of the day for the morning hello: unseen phrases first (in
  /// list order, rescue phrases early), then the one most overdue.
  static PocketPhrase phraseOfDay(int level, PocketProgress progress, int dayNumber) {
    final open = forLevel(level < 0 ? 0 : level);
    for (final p in open) {
      if (!progress.boxes.containsKey(p.id)) {
        return p;
      }
    }
    final due = progress.due(open, dayNumber);
    if (due.isNotEmpty) {
      return due.first;
    }
    return open[dayNumber % open.length];
  }

  /// Three phrases for the family this week (parents' weekly tips).
  static List<PocketPhrase> familyWeek(int level, int weekNumber) {
    final home = all.where((p) => p.level <= level + 1 && p.group != 'rescue' && p.group != 'school').toList();
    final out = <PocketPhrase>[];
    for (var i = 0; i < 3 && i < home.length; i++) {
      out.add(home[(weekNumber * 3 + i) % home.length]);
    }
    return out;
  }
}

/// Leitner boxes for pocket phrases, stored as JSON in the settings table.
class PocketProgress {
  PocketProgress(this.boxes, this.dueDay);

  factory PocketProgress.decode(String? raw) {
    final boxes = <String, int>{};
    final due = <String, int>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in map.entries) {
          final v = e.value as List;
          boxes[e.key] = (v[0] as num).toInt();
          due[e.key] = (v[1] as num).toInt();
        }
      } catch (_) {
        // A damaged value starts over.
      }
    }
    return PocketProgress(boxes, due);
  }

  static const String key = 'pocket_v1';

  /// Days until the next review, per box (1-5).
  static const List<int> intervals = [0, 1, 2, 4, 8, 16];

  final Map<String, int> boxes;
  final Map<String, int> dueDay;

  String encode() => jsonEncode({for (final id in boxes.keys) id: [boxes[id], dueDay[id] ?? 0]});

  int get collected => boxes.length;

  /// Phrases the child said well at least twice in a row (box 3 or more).
  int get mastered => boxes.values.where((b) => b >= 3).length;

  void answer(String id, {required bool good, required int today}) {
    final box = boxes[id] ?? 0;
    final next = good ? (box + 1).clamp(1, 5).toInt() : 1;
    boxes[id] = next;
    dueDay[id] = today + intervals[next];
  }

  /// Collected phrases due for review today, most overdue first.
  List<PocketPhrase> due(List<PocketPhrase> among, int today) {
    final list = [
      for (final p in among)
        if (boxes.containsKey(p.id) && (dueDay[p.id] ?? 0) <= today) p,
    ]..sort((a, b) => (dueDay[a.id] ?? 0).compareTo(dueDay[b.id] ?? 0));
    return list;
  }

  /// A practice round: due reviews first, then new phrases, up to [size].
  List<PocketPhrase> round(int level, int today, {int size = 5, String? group}) {
    var open = PocketPhrases.forLevel(level);
    if (group != null) {
      open = open.where((p) => p.group == group).toList();
    }
    final out = <PocketPhrase>[...due(open, today).take(size)];
    for (final p in open) {
      if (out.length >= size) {
        break;
      }
      if (!boxes.containsKey(p.id)) {
        out.add(p);
      }
    }
    if (out.isEmpty && open.isNotEmpty) {
      // Everything learnt and nothing due: a free review of the group.
      for (var i = 0; i < size && i < open.length; i++) {
        out.add(open[(today + i) % open.length]);
      }
    }
    return out;
  }
}
