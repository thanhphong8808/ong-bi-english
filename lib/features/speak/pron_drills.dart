// lib/features/speak/pron_drills.dart
//
// Drills for typical pronunciation difficulties of Vietnamese children.
// Each drill: a spoken Vietnamese tip from Bi, then words or sentences to
// listen to and repeat. Content is original.

class PronDrill {
  const PronDrill({
    required this.focus,
    required this.titleVi,
    required this.tipVi,
    required this.emoji,
    required this.practice,
  });

  final String focus;
  final String titleVi;

  /// Spoken by Bi before the practice.
  final String tipVi;
  final String emoji;

  /// Listen-and-repeat targets, easiest first.
  final List<String> practice;
}

const Map<String, PronDrill> pronDrills = {
  'final_consonant': PronDrill(
    focus: 'final_consonant',
    titleVi: 'Âm cuối',
    tipVi: 'Tiếng Anh rất thích âm cuối. Cậu nhớ đọc rõ âm cuối nhé, ví dụ "cat" có âm t ở cuối, '
        '"five" có âm v ở cuối. Nghe tớ đọc rồi nói theo nha!',
    emoji: '🐱',
    practice: ['cat', 'five', 'book', 'dog', 'bus', 'cup'],
  ),
  'ending_s': PronDrill(
    focus: 'ending_s',
    titleVi: 'Đuôi s',
    tipVi: 'Khi có nhiều đồ vật, tiếng Anh thêm âm s ở cuối, nghe như tiếng rắn kêu xì. '
        'Một con mèo là "cat", hai con mèo là "cats". Cậu thử nhé!',
    emoji: '🐍',
    practice: ['cats', 'books', 'dogs', 'apples', 'I like cats.', 'two balls'],
  ),
  'ending_ed': PronDrill(
    focus: 'ending_ed',
    titleVi: 'Đuôi ed',
    tipVi: 'Chuyện đã xảy ra rồi thì nhiều từ có đuôi ed. Nó đọc nhẹ như t hoặc đ ở cuối, '
        'ví dụ "played", "jumped". Đừng bỏ âm cuối nhé!',
    emoji: '⏪',
    practice: ['played', 'jumped', 'walked', 'I played football.', 'She jumped high.'],
  ),
  'th_sound': PronDrill(
    focus: 'th_sound',
    titleVi: 'Âm th',
    tipVi: 'Âm th tiếng Anh khác th tiếng Việt. Cậu đặt nhẹ đầu lưỡi giữa hai hàm răng rồi thổi hơi ra, '
        'như khi nói "three", "think". Với "this", "that" thì cổ họng rung nhẹ.',
    emoji: '👅',
    practice: ['three', 'think', 'thank you', 'this', 'that', 'mother'],
  ),
  'cluster': PronDrill(
    focus: 'cluster',
    titleVi: 'Cụm phụ âm',
    tipVi: 'Có từ có hai, ba phụ âm đi liền nhau. Cậu đọc liền một hơi, đừng chèn thêm âm ơ vào giữa. '
        'Ví dụ "blue" chứ không phải "bơ-lu".',
    emoji: '🔵',
    practice: ['blue', 'green', 'play', 'school', 'street', 'frog'],
  ),
  'sh_s': PronDrill(
    focus: 'sh_s',
    titleVi: 'Âm sh và s',
    tipVi: 'Âm sh giống như khi mình bảo em bé im lặng: suỵt. Âm s thì như tiếng rắn: xì. '
        'Nghe tớ đọc "she" và "see" nhé.',
    emoji: '🤫',
    practice: ['she', 'see', 'shoe', 'ship', 'sheep', 'fish'],
  ),
  'r_sound': PronDrill(
    focus: 'r_sound',
    titleVi: 'Âm r',
    tipVi: 'Âm r tiếng Anh không rung lưỡi và không đọc thành d. Cậu cong nhẹ lưỡi lên, '
        'môi tròn một chút, như "red", "run".',
    emoji: '🔴',
    practice: ['red', 'run', 'rabbit', 'rain', 'carrot', 'very'],
  ),
  'l_n': PronDrill(
    focus: 'l_n',
    titleVi: 'Âm l và n',
    tipVi: 'Âm l thì đầu lưỡi chạm sau răng trên và hơi đi ra hai bên lưỡi. Âm n thì hơi đi ra mũi. '
        'Nghe "light" và "night" nhé.',
    emoji: '💡',
    practice: ['light', 'night', 'lemon', 'nose', 'long', 'no'],
  ),
  'stress': PronDrill(
    focus: 'stress',
    titleVi: 'Trọng âm',
    tipVi: 'Từ tiếng Anh có một phần đọc mạnh hơn, gọi là trọng âm. Ví dụ "BA-na-na" thì đọc là ba-NA-na, '
        '"TI-ger" thì đọc mạnh ở đầu. Nghe tớ nhé!',
    emoji: '🥁',
    practice: ['tiger', 'banana', 'elephant', 'teacher', 'computer', 'tomato'],
  ),
  'question_intonation': PronDrill(
    focus: 'question_intonation',
    titleVi: 'Giọng câu hỏi',
    tipVi: 'Câu hỏi có hay không thì cuối câu mình lên giọng, như đang thắc mắc. '
        'Ví dụ "Is it a cat?" lên giọng ở cuối.',
    emoji: '❓',
    practice: ['Is it a cat?', 'Do you like apples?', 'Can you swim?', 'Are you happy?'],
  ),
};
