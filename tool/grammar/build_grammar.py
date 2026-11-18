#!/usr/bin/env python3
# tool/grammar/build_grammar.py
#
# Builds assets/grammar/grammar.json: grammar lessons with practice, the
# tense overview and the verb table. Self-authored; the order of the lessons
# follows the grammar lists of Cambridge Pre A1 Starters, A1 Movers and
# A2 Flyers (simple sentences first, then present, past, future, then more).
#
#   python3 tool/grammar/build_grammar.py
#
# Practice lines:
#   C  sentence with ___ | right | wrong | wrong | Vietnamese meaning | why (Vietnamese)
#   O  sentence to put in order | Vietnamese meaning
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'assets', 'grammar', 'grammar.json')

# ---------------------------------------------------------------------------
# Lessons: (id, stage, emoji, title_en, title_vi, explain_vi (spoken, short
# sentences), table (head, rows) or None, examples [(en, vi)], practice).
# ---------------------------------------------------------------------------
L = []


def lesson(id, stage, emoji, title_en, title_vi, explain, table, examples, practice):
    L.append(dict(id=id, stage=stage, emoji=emoji, title_en=title_en, title_vi=title_vi,
                  explain_vi=explain, table=table, examples=examples, practice=practice))


lesson('G01', 1, '🙋', 'am, is, are', 'Động từ "là": am, is, are', [
    'Trong tiếng Anh, chữ "là" có ba dạng: am, is và are.',
    'I đi với am. He, she, it đi với is.',
    'You, we, they đi với are.',
], (['Ai', 'là', 'Ví dụ'], [
    ['I', 'am', 'I am happy.'],
    ['He / She / It', 'is', 'She is my sister.'],
    ['You / We / They', 'are', 'We are friends.'],
]), [
    ('I am six.', 'Tớ sáu tuổi.'),
    ('He is a doctor.', 'Chú ấy là bác sĩ.'),
    ('They are cats.', 'Chúng là những con mèo.'),
], [
    'C I ___ a student. | am | is | are | Tớ là học sinh. | I luôn đi với am.',
    'C She ___ my mum. | is | am | are | Bà ấy là mẹ tớ. | She đi với is.',
    'C We ___ happy. | are | is | am | Chúng tớ vui. | We đi với are.',
    'C It ___ a dog. | is | are | am | Nó là một con chó. | It đi với is.',
    'C You ___ my friend. | are | is | am | Cậu là bạn tớ. | You đi với are.',
    'C They ___ in the park. | are | is | am | Họ ở trong công viên. | They đi với are.',
    'O I am seven | Tớ bảy tuổi.',
    'O He is my brother | Anh ấy là anh trai tớ.',
])

lesson('G02', 1, '🍎', 'a, an and plurals', 'a, an và số nhiều', [
    'Một đồ vật, mình nói a hoặc an.',
    'Từ bắt đầu bằng a, e, i, o, u thì dùng an: an apple, an egg.',
    'Từ hai cái trở lên thì thêm s: one cat, two cats.',
    'Từ tận cùng là s, sh, ch, x thì thêm es: one box, two boxes.',
], (['Một', 'Nhiều'], [
    ['a cat', 'two cats'],
    ['an apple', 'three apples'],
    ['a box', 'two boxes'],
    ['a child', 'two children'],
]), [
    ('I have a ball.', 'Tớ có một quả bóng.'),
    ('She has an orange.', 'Bạn ấy có một quả cam.'),
    ('I see three birds.', 'Tớ thấy ba con chim.'),
], [
    'C I have ___ egg. | an | a | two | Tớ có một quả trứng. | egg bắt đầu bằng e nên dùng an.',
    'C This is ___ book. | a | an | two | Đây là một quyển sách. | book bắt đầu bằng b nên dùng a.',
    'C I can see two ___. | dogs | dog | doges | Tớ thấy hai con chó. | Hai con thì thêm s: dogs.',
    'C There are three ___. | boxes | box | boxs | Có ba cái hộp. | box tận cùng là x nên thêm es.',
    'C She eats ___ apple. | an | a | some | Bạn ấy ăn một quả táo. | apple bắt đầu bằng a nên dùng an.',
    'C I have five ___. | pencils | pencil | penciles | Tớ có năm cái bút chì. | Năm cái thì thêm s.',
    'O I have an umbrella | Tớ có một cái ô.',
    'O We have two cats | Chúng tớ có hai con mèo.',
])

lesson('G03', 1, '👉', 'this, that, these, those', 'Cái này, cái kia: this, that, these, those', [
    'Đồ vật ở gần mình: một cái dùng this, nhiều cái dùng these.',
    'Đồ vật ở xa: một cái dùng that, nhiều cái dùng those.',
], (['', 'Gần', 'Xa'], [
    ['Một', 'this', 'that'],
    ['Nhiều', 'these', 'those'],
]), [
    ('This is my pen.', 'Đây là bút của tớ.'),
    ('That is a bird.', 'Kia là một con chim.'),
    ('These are my shoes.', 'Đây là giày của tớ.'),
], [
    'C ___ is my bag. (gần, một cái) | This | These | Those | Đây là cặp của tớ. | Gần và một cái: this.',
    'C ___ are my books. (gần, nhiều cái) | These | This | That | Đây là sách của tớ. | Gần và nhiều cái: these.',
    'C ___ is a plane. (xa, một cái) | That | Those | These | Kia là máy bay. | Xa và một cái: that.',
    'C ___ are stars. (xa, nhiều cái) | Those | That | This | Kia là những ngôi sao. | Xa và nhiều cái: those.',
    'C Is ___ your hat? (gần) | this | these | those | Đây có phải mũ của cậu không? | Một cái mũ ở gần: this.',
    'O These are my toys | Đây là đồ chơi của tớ.',
    'O That is my house | Kia là nhà của tớ.',
])

lesson('G04', 1, '🎒', 'have got, has got', 'Có: have got, has got', [
    'Muốn nói "có", mình dùng have got hoặc has got.',
    'I, you, we, they đi với have got.',
    'He, she, it đi với has got.',
    'Câu phủ định: haven\'t got, hasn\'t got.',
], (['Ai', 'có', 'không có'], [
    ['I / You / We / They', 'have got', "haven't got"],
    ['He / She / It', 'has got', "hasn't got"],
]), [
    ('I have got a kite.', 'Tớ có một con diều.'),
    ('She has got long hair.', 'Bạn ấy có tóc dài.'),
    ("He hasn't got a bike.", 'Bạn ấy không có xe đạp.'),
], [
    'C I ___ got a red bike. | have | has | am | Tớ có một chiếc xe đạp đỏ. | I đi với have.',
    'C She ___ got a cat. | has | have | is | Bạn ấy có một con mèo. | She đi với has.',
    'C We ___ got two balls. | have | has | are | Chúng tớ có hai quả bóng. | We đi với have.',
    'C The dog ___ got a long tail. | has | have | are | Con chó có cái đuôi dài. | The dog là it, đi với has.',
    "C He ___ got a pencil. | hasn't | haven't | isn't | Bạn ấy không có bút chì. | He đi với hasn't.",
    'O I have got a big family | Tớ có một gia đình lớn.',
    'O She has got blue eyes | Bạn ấy có mắt xanh.',
])

lesson('G05', 1, '💪', 'can, can\'t', 'Biết, có thể: can, can\'t', [
    'Muốn nói mình biết làm gì, dùng can và động từ.',
    'Không biết thì dùng can\'t.',
    'Can giống nhau với mọi người: I can, she can, they can.',
    'Hỏi thì đưa can lên đầu: Can you swim?',
], (['Câu', 'Ví dụ'], [
    ['Biết', 'I can swim.'],
    ['Không biết', "I can't fly."],
    ['Hỏi', 'Can you jump?'],
    ['Trả lời', "Yes, I can. / No, I can't."],
]), [
    ('Birds can fly.', 'Chim biết bay.'),
    ("Fish can't walk.", 'Cá không biết đi.'),
    ('Can you ride a bike?', 'Cậu có biết đi xe đạp không?'),
], [
    'C A fish ___ swim. | can | cans | is | Cá biết bơi. | can không bao giờ thêm s.',
    "C A cat ___ fly. | can't | can | isn't | Mèo không biết bay. | Không biết thì dùng can't.",
    'C ___ you sing? | Can | Do | Are | Cậu có biết hát không? | Hỏi thì đưa can lên đầu.',
    'C She can ___ very fast. | run | runs | running | Bạn ấy chạy rất nhanh. | Sau can là động từ nguyên mẫu.',
    "C Can you dance? Yes, I ___. | can | can't | do | Cậu biết nhảy không? Có, tớ biết. | Trả lời có: Yes, I can.",
    'O I can ride a bike | Tớ biết đi xe đạp.',
    'O Can you play football | Cậu có biết đá bóng không?',
])

lesson('G06', 1, '📦', 'there is, there are', 'Có cái gì ở đâu: there is, there are', [
    'Muốn nói ở đâu đó có cái gì, dùng there is hoặc there are.',
    'Một cái thì dùng there is. Nhiều cái thì dùng there are.',
], (['Một hay nhiều', 'Ví dụ'], [
    ['Một', 'There is a cat.'],
    ['Nhiều', 'There are two cats.'],
    ['Hỏi', 'Is there a cat? / Are there any cats?'],
]), [
    ('There is a bed in my room.', 'Trong phòng tớ có một cái giường.'),
    ('There are three apples.', 'Có ba quả táo.'),
], [
    'C There ___ a ball. | is | are | am | Có một quả bóng. | Một quả: there is.',
    'C There ___ four chairs. | are | is | am | Có bốn cái ghế. | Nhiều cái: there are.',
    'C There ___ a bird in the tree. | is | are | have | Có một con chim trên cây. | Một con: there is.',
    'C There ___ many fish in the sea. | are | is | has | Có nhiều cá ở biển. | Nhiều con: there are.',
    'C ___ there a park near your house? | Is | Are | Do | Gần nhà cậu có công viên không? | Một công viên: Is there.',
    'O There is a cake on the table | Có một cái bánh trên bàn.',
    'O There are two birds | Có hai con chim.',
])

lesson('G07', 1, '📍', 'in, on, under, next to', 'Ở đâu: in, on, under, next to', [
    'In là ở trong. On là ở trên. Under là ở dưới.',
    'Next to là ở bên cạnh. Behind là ở phía sau. In front of là ở phía trước.',
], (['Từ', 'Nghĩa', 'Ví dụ'], [
    ['in', 'ở trong', 'The cat is in the box.'],
    ['on', 'ở trên', 'The book is on the table.'],
    ['under', 'ở dưới', 'The ball is under the chair.'],
    ['next to', 'bên cạnh', 'The dog is next to the door.'],
    ['behind', 'phía sau', 'The boy is behind the tree.'],
    ['in front of', 'phía trước', 'The car is in front of the house.'],
]), [
    ('My bag is on the chair.', 'Cặp của tớ ở trên ghế.'),
    ('The fish are in the water.', 'Cá ở trong nước.'),
], [
    'C The cat is ___ the box. (ở trong) | in | on | under | Con mèo ở trong hộp. | Ở trong là in.',
    'C The cup is ___ the table. (ở trên) | on | in | under | Cái cốc ở trên bàn. | Ở trên là on.',
    'C The shoes are ___ the bed. (ở dưới) | under | on | in | Giày ở dưới giường. | Ở dưới là under.',
    'C I sit ___ my friend. (bên cạnh) | next to | under | in | Tớ ngồi cạnh bạn. | Bên cạnh là next to.',
    'C The ball is ___ the tree. (phía sau) | behind | on | in | Quả bóng ở sau cái cây. | Phía sau là behind.',
    'O The book is on the desk | Quyển sách ở trên bàn học.',
    'O The dog is under the table | Con chó ở dưới gầm bàn.',
])

lesson('G08', 1, '🧸', "my, your, his, her and 's", "Của ai: my, your, his, her và 's", [
    'My là của tớ. Your là của cậu.',
    'His là của bạn trai ấy. Her là của bạn gái ấy.',
    'Our là của chúng tớ. Their là của họ.',
    'Muốn nói của một người, thêm dấu phẩy trên và s: Mai\'s bag là cặp của Mai.',
], (['Người', 'Của người đó'], [
    ['I', 'my'], ['you', 'your'], ['he', 'his'], ['she', 'her'], ['we', 'our'], ['they', 'their'],
    ['Mai', "Mai's"],
]), [
    ('This is my dog.', 'Đây là con chó của tớ.'),
    ('Her name is Lan.', 'Tên bạn ấy là Lan.'),
    ("That is Tom's bike.", 'Kia là xe đạp của Tom.'),
], [
    'C I have a cat. ___ cat is white. | My | Your | Her | Tớ có con mèo. Mèo của tớ màu trắng. | Của tớ là my.',
    'C Lan has a doll. ___ doll is pretty. | Her | His | My | Lan có búp bê. Búp bê của bạn ấy đẹp. | Lan là bạn gái: her.',
    'C Nam has a kite. ___ kite is big. | His | Her | Their | Nam có diều. Diều của bạn ấy to. | Nam là bạn trai: his.',
    'C We have a garden. ___ garden is green. | Our | Their | My | Chúng tớ có vườn. Vườn của chúng tớ xanh. | Của chúng tớ là our.',
    "C This is ___ bag. (cặp của Minh) | Minh's | Minh | Minhs | Đây là cặp của Minh. | Thêm 's: Minh's.",
    'O What is your name | Cậu tên là gì?',
    'O This is my brother | Đây là anh trai tớ.',
])

lesson('G09', 1, '❓', 'what, where, who, how many', 'Từ để hỏi: what, where, who, how many', [
    'What là cái gì. Where là ở đâu. Who là ai.',
    'How many là bao nhiêu cái. How old là bao nhiêu tuổi.',
    'When là khi nào. Why là tại sao.',
], (['Từ hỏi', 'Nghĩa', 'Ví dụ'], [
    ['What', 'cái gì', 'What is this?'],
    ['Where', 'ở đâu', 'Where is my bag?'],
    ['Who', 'ai', 'Who is she?'],
    ['How many', 'bao nhiêu', 'How many cats are there?'],
    ['How old', 'mấy tuổi', 'How old are you?'],
    ['When', 'khi nào', 'When is your birthday?'],
]), [
    ('What colour is it?', 'Nó màu gì?'),
    ('Where is my teddy bear?', 'Gấu bông của tớ đâu rồi?'),
], [
    "C ___ is your name? | What | Where | Who | Cậu tên là gì? | Hỏi cái gì: what.",
    'C ___ is the cat? It is under the bed. | Where | What | Who | Con mèo đâu? Nó ở dưới giường. | Hỏi ở đâu: where.',
    'C ___ is he? He is my dad. | Who | What | Where | Chú ấy là ai? Đó là bố tớ. | Hỏi ai: who.',
    'C How ___ are you? I am six. | old | many | much | Cậu mấy tuổi? Tớ sáu tuổi. | Hỏi tuổi: how old.',
    'C How ___ birds are there? | many | old | is | Có bao nhiêu con chim? | Hỏi số lượng: how many.',
    'C ___ is your birthday? In May. | When | Who | What | Sinh nhật cậu khi nào? Tháng Năm. | Hỏi khi nào: when.',
    'O Where is my pencil | Bút chì của tớ đâu nhỉ?',
    'O How old is your sister | Em gái cậu mấy tuổi?',
])

lesson('G10', 2, '☀️', 'Present simple: I play', 'Thì hiện tại đơn: I play', [
    'Việc mình làm hằng ngày, làm thường xuyên, dùng thì hiện tại đơn.',
    'Với I, you, we, they, động từ giữ nguyên: I play, they play.',
    'Hay đi với các từ: every day, always, usually, sometimes.',
], (['Ai', 'Động từ', 'Ví dụ'], [
    ['I', 'play', 'I play football.'],
    ['You', 'eat', 'You eat rice.'],
    ['We', 'go', 'We go to school.'],
    ['They', 'like', 'They like cats.'],
]), [
    ('I get up at six every day.', 'Tớ dậy lúc sáu giờ mỗi ngày.'),
    ('We walk to school.', 'Chúng tớ đi bộ đến trường.'),
], [
    'C I ___ milk every morning. | drink | drinks | drinking | Sáng nào tớ cũng uống sữa. | I đi với động từ nguyên mẫu.',
    'C We ___ to school by bus. | go | goes | going | Chúng tớ đi học bằng xe buýt. | We đi với động từ nguyên mẫu.',
    'C They ___ in the park. | play | plays | playing | Họ chơi ở công viên. | They đi với động từ nguyên mẫu.',
    'C You ___ very well. | sing | sings | singing | Cậu hát rất hay. | You đi với động từ nguyên mẫu.',
    'C I ___ my teeth every day. | brush | brushes | brushing | Tớ đánh răng mỗi ngày. | I đi với động từ nguyên mẫu.',
    'O I like ice cream | Tớ thích kem.',
    'O We play together every day | Chúng tớ chơi cùng nhau mỗi ngày.',
])

lesson('G11', 2, '👧', 'Present simple: she plays', 'Hiện tại đơn với he, she, it: thêm s', [
    'Khi nói về một người khác như he, she, it, động từ phải thêm s.',
    'He plays. She likes. It runs.',
    'Động từ tận cùng là o, s, sh, ch, x thì thêm es: go thành goes, watch thành watches.',
    'Phụ âm và y thì đổi y thành ies: fly thành flies. Have thành has.',
], (['Động từ', 'He / She / It'], [
    ['play', 'plays'], ['like', 'likes'], ['go', 'goes'], ['watch', 'watches'],
    ['wash', 'washes'], ['fly', 'flies'], ['have', 'has'],
]), [
    ('She reads books.', 'Bạn ấy đọc sách.'),
    ('He goes to school.', 'Bạn ấy đi học.'),
    ('My cat sleeps a lot.', 'Con mèo của tớ ngủ nhiều.'),
], [
    'C She ___ the piano. | plays | play | playing | Cô ấy chơi đàn piano. | She thì thêm s: plays.',
    'C He ___ to school at seven. | goes | go | gos | Bạn ấy đi học lúc bảy giờ. | go tận cùng là o: goes.',
    'C My mum ___ TV in the evening. | watches | watch | watchs | Mẹ tớ xem TV buổi tối. | watch tận cùng là ch: watches.',
    'C The bird ___ high. | flies | fly | flys | Con chim bay cao. | fly đổi y thành ies: flies.',
    'C Lan ___ a red bike. | has | have | haves | Lan có một xe đạp đỏ. | Have với she thành has.',
    'C I ___ apples but my brother ___ bananas. | like, likes | likes, like | like, like | Tớ thích táo còn anh tớ thích chuối. | I giữ nguyên, my brother là he nên thêm s.',
    'O She brushes her teeth | Bạn ấy đánh răng.',
    'O My dad drives a car | Bố tớ lái ô tô.',
])

lesson('G12', 2, '🙅', "don't, doesn't, do, does", "Hiện tại đơn: phủ định và câu hỏi", [
    "Câu phủ định: I, you, we, they dùng don't. He, she, it dùng doesn't.",
    "Sau don't và doesn't, động từ trở về nguyên mẫu: She doesn't like, không phải doesn't likes.",
    'Câu hỏi: Do you like? Does she like?',
], (['', 'I / You / We / They', 'He / She / It'], [
    ['Phủ định', "I don't like fish.", "She doesn't like fish."],
    ['Hỏi', 'Do you like fish?', 'Does she like fish?'],
    ['Trả lời', "Yes, I do. / No, I don't.", "Yes, she does. / No, she doesn't."],
]), [
    ("I don't like onions.", 'Tớ không thích hành.'),
    ('Does he play football?', 'Bạn ấy có chơi bóng đá không?'),
], [
    "C I ___ like spiders. | don't | doesn't | not | Tớ không thích nhện. | I dùng don't.",
    "C She ___ eat meat. | doesn't | don't | isn't | Bạn ấy không ăn thịt. | She dùng doesn't.",
    'C ___ you like music? | Do | Does | Are | Cậu có thích nhạc không? | You dùng do.',
    'C ___ your dad cook? | Does | Do | Is | Bố cậu có nấu ăn không? | Your dad là he, dùng does.',
    "C He doesn't ___ cats. | like | likes | liking | Bạn ấy không thích mèo. | Sau doesn't là động từ nguyên mẫu.",
    "C Do you have a pet? No, I ___. | don't | doesn't | do | Cậu có thú cưng không? Không. | Trả lời không với I: No, I don't.",
    "O I don't like rain | Tớ không thích mưa.",
    'O Does she like dancing | Bạn ấy có thích nhảy không?',
])

lesson('G13', 2, '🏃', 'Present continuous: I am playing', 'Thì hiện tại tiếp diễn: đang làm', [
    'Việc đang xảy ra ngay lúc này, dùng am, is, are và động từ thêm ing.',
    'I am playing. She is reading. They are running.',
    'Động từ tận cùng là e thì bỏ e: dance thành dancing.',
    'Một số từ ngắn thì gấp đôi chữ cuối: run thành running, swim thành swimming.',
], (['Động từ', 'Thêm ing'], [
    ['play', 'playing'], ['read', 'reading'], ['dance', 'dancing'], ['write', 'writing'],
    ['run', 'running'], ['swim', 'swimming'], ['sit', 'sitting'],
]), [
    ('I am eating an apple now.', 'Bây giờ tớ đang ăn táo.'),
    ('The baby is sleeping.', 'Em bé đang ngủ.'),
    ('Look! They are dancing.', 'Nhìn kìa! Họ đang nhảy.'),
], [
    'C Look! The dog ___ running. | is | are | am | Nhìn kìa! Con chó đang chạy. | The dog là it: is.',
    'C I am ___ a picture now. | drawing | draw | draws | Bây giờ tớ đang vẽ tranh. | Đang làm: thêm ing.',
    'C They ___ playing football. | are | is | am | Họ đang đá bóng. | They đi với are.',
    'C She is ___ in the pool. | swimming | swiming | swims | Bạn ấy đang bơi trong bể. | swim gấp đôi m: swimming.',
    'C We are ___ a song. | singing | sing | sings | Chúng tớ đang hát. | Đang làm: thêm ing.',
    'C What ___ you doing? | are | is | do | Cậu đang làm gì thế? | You đi với are.',
    'O The cat is sleeping | Con mèo đang ngủ.',
    'O I am reading a book | Tớ đang đọc sách.',
])

lesson('G14', 2, '❤️', 'like, love, want + to / -ing', 'Thích làm gì: like + ing, want to', [
    'Thích làm gì: like hoặc love, rồi động từ thêm ing. I like swimming.',
    'Muốn làm gì: want to và động từ nguyên mẫu. I want to play.',
    'Lời mời lịch sự: Would you like to come?',
], (['Mẫu câu', 'Ví dụ'], [
    ['like + ing', 'I like reading.'],
    ['love + ing', 'She loves dancing.'],
    ['want to + động từ', 'I want to go home.'],
    ["would like to + động từ", "I'd like to drink water."],
]), [
    ('I love playing with my dog.', 'Tớ rất thích chơi với con chó.'),
    ('Do you want to draw?', 'Cậu có muốn vẽ không?'),
], [
    'C I like ___ books. | reading | read | reads | Tớ thích đọc sách. | Sau like thường thêm ing.',
    'C She wants ___ a cake. | to eat | eating | eats | Bạn ấy muốn ăn bánh. | Sau want là to và động từ.',
    'C He loves ___ football. | playing | play | plays | Bạn ấy rất thích đá bóng. | Sau love thường thêm ing.',
    'C Would you like ___ to my party? | to come | coming | come | Cậu có muốn đến dự tiệc của tớ không? | Sau would like là to và động từ.',
    'C We want ___ to the zoo. | to go | going | goes | Chúng tớ muốn đi sở thú. | Sau want là to và động từ.',
    'O I like singing songs | Tớ thích hát.',
    'O I want to be a doctor | Tớ muốn làm bác sĩ.',
])

lesson('G15', 3, '⏪', 'was, were', 'Quá khứ của "là": was, were', [
    'Muốn nói chuyện đã qua, am và is đổi thành was, are đổi thành were.',
    'I, he, she, it đi với was. You, we, they đi với were.',
    'Hay đi với: yesterday, last week, last year.',
], (['Ai', 'Hiện tại', 'Quá khứ'], [
    ['I', 'am', 'was'],
    ['He / She / It', 'is', 'was'],
    ['You / We / They', 'are', 'were'],
]), [
    ('I was at home yesterday.', 'Hôm qua tớ ở nhà.'),
    ('They were very happy.', 'Họ đã rất vui.'),
], [
    'C I ___ tired yesterday. | was | were | am | Hôm qua tớ mệt. | Quá khứ của I là was.',
    'C We ___ at the beach last week. | were | was | are | Tuần trước chúng tớ ở biển. | We đi với were.',
    'C The film ___ very funny. | was | were | are | Bộ phim rất buồn cười. | The film là it: was.',
    'C ___ you at school yesterday? | Were | Was | Are | Hôm qua cậu có đi học không? | You đi với were.',
    "C She ___ at home last night. | wasn't | weren't | isn't | Tối qua bạn ấy không ở nhà. | She đi với wasn't.",
    'O I was six last year | Năm ngoái tớ sáu tuổi.',
    'O They were in the garden | Họ đã ở trong vườn.',
])

lesson('G16', 3, '📼', 'Past simple: played', 'Thì quá khứ đơn: thêm ed', [
    'Việc đã xảy ra trong quá khứ, nhiều động từ chỉ cần thêm ed.',
    'play thành played, watch thành watched.',
    'Động từ tận cùng là e thì thêm d: dance thành danced.',
    'Phụ âm và y thì đổi thành ied: cry thành cried. Một số từ ngắn gấp đôi chữ cuối: stop thành stopped.',
], (['Động từ', 'Quá khứ'], [
    ['play', 'played'], ['watch', 'watched'], ['dance', 'danced'], ['like', 'liked'],
    ['cry', 'cried'], ['stop', 'stopped'], ['visit', 'visited'],
]), [
    ('I played football yesterday.', 'Hôm qua tớ đá bóng.'),
    ('We visited Grandma last Sunday.', 'Chủ nhật tuần trước chúng tớ đi thăm bà.'),
], [
    'C Yesterday I ___ with my friends. | played | play | plays | Hôm qua tớ chơi với các bạn. | Chuyện hôm qua: thêm ed.',
    'C She ___ TV last night. | watched | watches | watch | Tối qua bạn ấy xem TV. | Chuyện tối qua: watched.',
    'C We ___ at the party. | danced | danceed | dances | Chúng tớ đã nhảy ở bữa tiệc. | dance tận cùng là e: thêm d.',
    'C The baby ___ a lot. | cried | cryed | cries | Em bé đã khóc nhiều. | cry đổi thành cried.',
    'C The bus ___ at the station. | stopped | stoped | stops | Xe buýt đã dừng ở bến. | stop gấp đôi p: stopped.',
    'O I cleaned my room yesterday | Hôm qua tớ đã dọn phòng.',
    'O We walked to the park | Chúng tớ đã đi bộ đến công viên.',
])

lesson('G17', 3, '🔀', 'Past simple: went, saw, ate', 'Quá khứ đơn: động từ bất quy tắc', [
    'Một số động từ có dạng quá khứ riêng, không thêm ed.',
    'go thành went. see thành saw. eat thành ate. have thành had.',
    'Mình học thuộc dần trong bảng chia động từ nhé.',
], (['Động từ', 'Quá khứ', 'Nghĩa'], [
    ['go', 'went', 'đi'], ['see', 'saw', 'nhìn thấy'], ['eat', 'ate', 'ăn'], ['have', 'had', 'có'],
    ['make', 'made', 'làm'], ['buy', 'bought', 'mua'], ['swim', 'swam', 'bơi'], ['take', 'took', 'cầm, mang'],
]), [
    ('We went to the zoo.', 'Chúng tớ đã đi sở thú.'),
    ('I saw a big elephant.', 'Tớ đã nhìn thấy một con voi to.'),
    ('She ate an ice cream.', 'Bạn ấy đã ăn một cây kem.'),
], [
    'C Last Sunday we ___ to the beach. | went | goed | go | Chủ nhật tuần trước chúng tớ đi biển. | Quá khứ của go là went.',
    'C I ___ a rainbow yesterday. | saw | seed | see | Hôm qua tớ nhìn thấy cầu vồng. | Quá khứ của see là saw.',
    'C He ___ rice for lunch. | ate | eated | eats | Bạn ấy ăn cơm trưa. | Quá khứ của eat là ate.',
    'C We ___ a lot of fun. | had | haved | has | Chúng tớ đã rất vui. | Quá khứ của have là had.',
    'C Mum ___ me a new book. | bought | buyed | buys | Mẹ đã mua cho tớ quyển sách mới. | Quá khứ của buy là bought.',
    'C They ___ a big cake. | made | maked | make | Họ đã làm một cái bánh to. | Quá khứ của make là made.',
    'O We went to the zoo yesterday | Hôm qua chúng tớ đã đi sở thú.',
    'O I had a good time | Tớ đã chơi rất vui.',
])

lesson('G18', 3, '🔍', "did, didn't", "Quá khứ đơn: câu hỏi và phủ định", [
    "Câu phủ định ở quá khứ dùng didn't, rồi động từ nguyên mẫu.",
    "I didn't go, không nói I didn't went.",
    'Câu hỏi dùng did: Did you see it? Yes, I did. No, I didn\'t.',
], (['Câu', 'Ví dụ'], [
    ['Khẳng định', 'I went to school.'],
    ['Phủ định', "I didn't go to school."],
    ['Hỏi', 'Did you go to school?'],
    ['Trả lời', "Yes, I did. / No, I didn't."],
]), [
    ('Did you have breakfast?', 'Cậu đã ăn sáng chưa?'),
    ("He didn't watch TV.", 'Bạn ấy đã không xem TV.'),
], [
    "C I ___ go out yesterday. | didn't | don't | wasn't | Hôm qua tớ không ra ngoài. | Quá khứ phủ định: didn't.",
    'C ___ you see the moon last night? | Did | Do | Were | Tối qua cậu có nhìn thấy trăng không? | Hỏi chuyện đã qua: did.',
    "C She didn't ___ her homework. | do | did | does | Bạn ấy đã không làm bài tập. | Sau didn't là động từ nguyên mẫu.",
    'C Did they ___ the bus? | take | took | takes | Họ có đi xe buýt không? | Sau did là động từ nguyên mẫu.',
    'C Did you like the film? Yes, I ___. | did | do | was | Cậu có thích phim không? Có. | Trả lời có: Yes, I did.',
    'O Did you go to the park | Cậu có đi công viên không?',
    "O We didn't play football | Chúng tớ đã không đá bóng.",
])

lesson('G19', 3, '🗓️', 'going to', 'Dự định: be going to', [
    'Việc mình đã định làm, dùng am, is, are và going to, rồi động từ nguyên mẫu.',
    'I am going to visit Grandma: tớ định đi thăm bà.',
    'Hay đi với: tomorrow, next week, this weekend.',
], (['Ai', 'Mẫu câu'], [
    ['I', 'am going to + động từ'],
    ['He / She / It', 'is going to + động từ'],
    ['You / We / They', 'are going to + động từ'],
]), [
    ("I'm going to swim this weekend.", 'Cuối tuần này tớ định đi bơi.'),
    ('Look at the clouds! It is going to rain.', 'Nhìn mây kìa! Trời sắp mưa.'),
], [
    'C I am going ___ visit my uncle. | to | for | at | Tớ định đi thăm chú. | going to và động từ.',
    'C She ___ going to buy a dress. | is | are | am | Bạn ấy định mua váy. | She đi với is.',
    'C We are going to ___ a cake. | make | made | making | Chúng tớ định làm bánh. | Sau going to là động từ nguyên mẫu.',
    'C They ___ going to play tennis. | are | is | am | Họ định chơi quần vợt. | They đi với are.',
    'C What ___ you going to do tomorrow? | are | is | do | Ngày mai cậu định làm gì? | You đi với are.',
    'O I am going to read a book | Tớ định đọc một quyển sách.',
    'O It is going to rain | Trời sắp mưa.',
])

lesson('G20', 3, '🔮', "will, won't", "Tương lai: will, won't", [
    'Will dùng để nói điều sẽ xảy ra, lời hứa hoặc quyết định ngay lúc nói.',
    'Will đi với mọi người và động từ nguyên mẫu: I will help you.',
    "Phủ định là won't: I won't be late.",
], (['Câu', 'Ví dụ'], [
    ['Khẳng định', 'It will be sunny tomorrow.'],
    ['Phủ định', "I won't forget."],
    ['Hỏi', 'Will you come?'],
]), [
    ('I will be a teacher.', 'Tớ sẽ làm cô giáo.'),
    ("Don't worry. I will help you.", 'Đừng lo. Tớ sẽ giúp cậu.'),
], [
    'C It ___ be hot tomorrow. | will | is | does | Ngày mai trời sẽ nóng. | Nói chuyện ngày mai: will.',
    'C I will ___ you later. | call | calls | calling | Lát nữa tớ sẽ gọi cho cậu. | Sau will là động từ nguyên mẫu.',
    "C I ___ be late again. I promise! | won't | don't | am not | Tớ sẽ không muộn nữa. Tớ hứa! | Phủ định của will là won't.",
    'C ___ you help me, please? | Will | Do | Are | Cậu giúp tớ được không? | Nhờ lịch sự: will you.',
    'C She will ___ ten next year. | be | is | being | Năm sau bạn ấy sẽ mười tuổi. | Sau will dùng be.',
    'O I will help you | Tớ sẽ giúp cậu.',
    'O It will rain tomorrow | Ngày mai trời sẽ mưa.',
])

lesson('G21', 4, '📏', 'bigger, more beautiful', 'So sánh hơn: bigger, more beautiful', [
    'So sánh hai thứ, từ ngắn thì thêm er và than: big thành bigger than.',
    'Từ dài thì dùng more: more beautiful than.',
    'Đặc biệt: good thành better, bad thành worse.',
], (['Từ', 'So sánh hơn'], [
    ['tall', 'taller'], ['big', 'bigger'], ['happy', 'happier'], ['beautiful', 'more beautiful'],
    ['good', 'better'], ['bad', 'worse'],
]), [
    ('An elephant is bigger than a dog.', 'Con voi to hơn con chó.'),
    ('My sister is taller than me.', 'Chị tớ cao hơn tớ.'),
], [
    'C A car is ___ than a bike. | faster | fast | fastest | Ô tô nhanh hơn xe đạp. | So sánh hai thứ: thêm er.',
    'C My dad is ___ than my mum. | taller | tall | more tall | Bố tớ cao hơn mẹ tớ. | Từ ngắn: taller.',
    'C A whale is ___ than a fish. | bigger | biger | more big | Cá voi to hơn con cá. | big gấp đôi g: bigger.',
    'C This flower is ___ than that one. | more beautiful | beautifuler | beautiful | Bông hoa này đẹp hơn bông kia. | Từ dài dùng more.',
    'C Your drawing is ___ than mine. | better | gooder | more good | Tranh của cậu đẹp hơn của tớ. | good thành better.',
    'C A cat is smaller ___ a dog. | than | that | then | Con mèo nhỏ hơn con chó. | So sánh hơn dùng than.',
    'O An apple is bigger than a grape | Quả táo to hơn quả nho.',
    'O My bag is heavier than your bag | Cặp của tớ nặng hơn cặp của cậu.',
])

lesson('G22', 4, '🏆', 'the biggest, the most', 'So sánh nhất: the biggest, the most', [
    'Nói cái gì nhất trong nhiều thứ, từ ngắn thêm est và có the đứng trước: the biggest.',
    'Từ dài dùng the most: the most beautiful.',
    'Đặc biệt: good thành the best, bad thành the worst.',
], (['Từ', 'Hơn', 'Nhất'], [
    ['tall', 'taller', 'the tallest'], ['big', 'bigger', 'the biggest'], ['happy', 'happier', 'the happiest'],
    ['beautiful', 'more beautiful', 'the most beautiful'], ['good', 'better', 'the best'],
]), [
    ('The blue whale is the biggest animal.', 'Cá voi xanh là con vật to nhất.'),
    ('You are my best friend.', 'Cậu là bạn thân nhất của tớ.'),
], [
    'C The cheetah is the ___ animal. | fastest | faster | fast | Báo săn là con vật chạy nhanh nhất. | Nhất: thêm est.',
    'C Lan is the ___ girl in my class. | tallest | taller | most tall | Lan là bạn gái cao nhất lớp tớ. | Từ ngắn: the tallest.',
    'C This is the ___ day of my life! | happiest | happyest | most happy | Đây là ngày vui nhất đời tớ! | happy đổi y: happiest.',
    'C It is the ___ picture in the book. | most beautiful | beautifulest | more beautiful | Đó là bức tranh đẹp nhất trong sách. | Từ dài: the most.',
    'C Mum makes the ___ cakes. | best | goodest | better | Mẹ làm bánh ngon nhất. | good thành the best.',
    'O The elephant is the biggest | Con voi là to nhất.',
    'O This is the best day | Đây là ngày tuyệt nhất.',
])

lesson('G23', 4, '⚠️', "must, mustn't, should", "Phải, không được, nên: must, mustn't, should", [
    'Must là phải làm. Mustn\'t là không được làm.',
    'Should là nên làm. Shouldn\'t là không nên làm.',
    'Sau must và should là động từ nguyên mẫu.',
], (['Từ', 'Nghĩa', 'Ví dụ'], [
    ['must', 'phải', 'You must wear a helmet.'],
    ["mustn't", 'không được', "You mustn't run in class."],
    ['should', 'nên', 'You should drink water.'],
    ["shouldn't", 'không nên', "You shouldn't eat too many sweets."],
]), [
    ('We must stop at a red light.', 'Chúng ta phải dừng khi đèn đỏ.'),
    ('You should go to bed early.', 'Cậu nên đi ngủ sớm.'),
], [
    "C You ___ cross the road at a red light. | mustn't | must | should | Không được qua đường khi đèn đỏ. | Không được: mustn't.",
    'C You ___ wash your hands before eating. | must | mustn\'t | can\'t | Phải rửa tay trước khi ăn. | Phải làm: must.',
    'C You have a cold. You ___ rest. | should | shouldn\'t | mustn\'t | Cậu bị cảm. Cậu nên nghỉ ngơi. | Lời khuyên: should.',
    "C You ___ watch TV all day. | shouldn't | should | must | Không nên xem TV cả ngày. | Khuyên không nên: shouldn't.",
    'C We must ___ quiet in the library. | be | are | being | Ở thư viện phải giữ trật tự. | Sau must là động từ nguyên mẫu.',
    'O You must wear a seat belt | Cậu phải thắt dây an toàn.',
    'O We should help our friends | Chúng ta nên giúp đỡ bạn bè.',
])

lesson('G24', 5, '🌍', 'Present perfect: have you ever', 'Thì hiện tại hoàn thành: đã từng', [
    'Kể trải nghiệm đã từng có, dùng have hoặc has và động từ dạng thứ ba.',
    'I have been to Ha Long Bay: tớ đã từng đến vịnh Hạ Long.',
    'Hỏi: Have you ever...? Trả lời: Yes, I have. No, I haven\'t.',
    'Never là chưa bao giờ: I have never seen snow.',
], (['Ai', 'Mẫu câu'], [
    ['I / You / We / They', 'have + động từ dạng 3'],
    ['He / She / It', 'has + động từ dạng 3'],
    ['Hỏi', 'Have you ever + động từ dạng 3?'],
]), [
    ('I have visited Hue.', 'Tớ đã từng đến Huế.'),
    ('Have you ever seen a panda?', 'Cậu đã bao giờ nhìn thấy gấu trúc chưa?'),
    ('She has never flown in a plane.', 'Bạn ấy chưa bao giờ đi máy bay.'),
], [
    'C I ___ been to the sea. | have | has | am | Tớ đã từng ra biển. | I đi với have.',
    'C She ___ seen a dolphin. | has | have | is | Bạn ấy đã từng thấy cá heo. | She đi với has.',
    'C Have you ever ___ sushi? | eaten | ate | eat | Cậu đã bao giờ ăn sushi chưa? | Dạng thứ ba của eat là eaten.',
    'C We have ___ this film. | seen | saw | see | Chúng tớ đã xem phim này rồi. | Dạng thứ ba của see là seen.',
    "C Have you ever been to Da Lat? No, I ___. | haven't | didn't | don't | Cậu đã đến Đà Lạt chưa? Chưa. | Trả lời chưa: No, I haven't.",
    'C I have ___ seen snow. | never | ever | not | Tớ chưa bao giờ thấy tuyết. | Chưa bao giờ: never.',
    'O I have been to Ha Noi | Tớ đã từng đến Hà Nội.',
    'O Have you ever seen a tiger | Cậu đã bao giờ thấy hổ chưa?',
])

lesson('G25', 5, '⏸️', 'Past continuous: was playing', 'Thì quá khứ tiếp diễn: đang làm thì...', [
    'Việc đang diễn ra ở một lúc trong quá khứ, dùng was hoặc were và động từ thêm ing.',
    'Hay dùng với when: I was reading when Mum called.',
    'Tớ đang đọc sách thì mẹ gọi.',
], (['Ai', 'Mẫu câu'], [
    ['I / He / She / It', 'was + động từ ing'],
    ['You / We / They', 'were + động từ ing'],
]), [
    ('At eight o\'clock I was eating dinner.', 'Lúc tám giờ tớ đang ăn tối.'),
    ('We were playing when it started to rain.', 'Chúng tớ đang chơi thì trời bắt đầu mưa.'),
], [
    'C I ___ sleeping when the phone rang. | was | were | am | Tớ đang ngủ thì điện thoại reo. | I đi với was.',
    'C They ___ watching TV at nine o\'clock. | were | was | are | Lúc chín giờ họ đang xem TV. | They đi với were.',
    'C She was ___ a song. | singing | sing | sang | Bạn ấy đang hát. | Đang làm: thêm ing.',
    'C What were you ___ yesterday at five? | doing | do | did | Lúc năm giờ hôm qua cậu đang làm gì? | Đang làm: thêm ing.',
    'C We were walking ___ it started to rain. | when | than | because | Chúng tớ đang đi bộ thì trời mưa. | Việc chen vào: dùng when.',
    'O I was reading a book | Tớ đang đọc sách.',
    'O They were playing in the garden | Họ đang chơi trong vườn.',
])

lesson('G26', 5, '🔁', 'If ..., ... will', 'Câu điều kiện: If ..., ... will', [
    'Nói điều có thể xảy ra: If và thì hiện tại, rồi will và động từ.',
    'If it rains, we will stay at home: nếu trời mưa, chúng mình sẽ ở nhà.',
    'Vế có if không dùng will.',
], (['Vế if', 'Vế kết quả'], [
    ['If it is sunny,', 'we will go to the beach.'],
    ['If you study hard,', 'you will learn a lot.'],
    ["If we don't hurry,", 'we will be late.'],
]), [
    ('If you are tired, you will sleep well.', 'Nếu cậu mệt, cậu sẽ ngủ ngon.'),
    ('If we plant trees, the air will be cleaner.', 'Nếu mình trồng cây, không khí sẽ sạch hơn.'),
], [
    'C If it ___, we will stay home. | rains | will rain | rained | Nếu trời mưa, chúng mình sẽ ở nhà. | Vế if dùng hiện tại: rains.',
    'C If you eat too much, you ___ feel sick. | will | are | did | Nếu ăn quá nhiều, cậu sẽ bị mệt. | Vế kết quả dùng will.',
    'C If she ___ hard, she will win. | tries | will try | try | Nếu bạn ấy cố gắng, bạn ấy sẽ thắng. | She ở vế if: tries.',
    "C If we ___ hurry, we will miss the bus. | don't | won't | didn't | Nếu không nhanh lên, mình sẽ lỡ xe buýt. | Vế if dùng don't.",
    'C If you water the plant, it will ___. | grow | grows | grew | Nếu cậu tưới cây, cây sẽ lớn. | Sau will là động từ nguyên mẫu.',
    'O If it is sunny we will swim | Nếu trời nắng chúng mình sẽ đi bơi.',
    'O If you are hungry you will eat | Nếu cậu đói cậu sẽ ăn.',
])

STAGES = [
    (1, 'Câu đơn giản', 'Simple sentences', '🌱'),
    (2, 'Thì hiện tại', 'Present', '☀️'),
    (3, 'Quá khứ và tương lai', 'Past and future', '⏳'),
    (4, 'So sánh và lời khuyên', 'Comparing and advice', '🏆'),
    (5, 'Nâng cao', 'More grammar', '🚀'),
]

# ---------------------------------------------------------------------------
# Tenses overview.
# ---------------------------------------------------------------------------
TENSES = [
    dict(id='present_simple', emoji='☀️', name_en='Present simple', name_vi='Hiện tại đơn',
         use_vi='Việc làm hằng ngày, thói quen, sự thật.', yes='I play. / She plays.',
         no="I don't play. / She doesn't play.", ask='Do you play? / Does she play?',
         signals='every day, always, usually, often, sometimes, never',
         example=('I go to school every day.', 'Ngày nào tớ cũng đi học.'), lesson='G11'),
    dict(id='present_continuous', emoji='🏃', name_en='Present continuous', name_vi='Hiện tại tiếp diễn',
         use_vi='Việc đang xảy ra ngay lúc này.', yes='I am playing. / She is playing.',
         no="I'm not playing. / She isn't playing.", ask='Are you playing? / Is she playing?',
         signals='now, right now, look, listen',
         example=('Look! The baby is laughing.', 'Nhìn kìa! Em bé đang cười.'), lesson='G13'),
    dict(id='past_simple', emoji='📼', name_en='Past simple', name_vi='Quá khứ đơn',
         use_vi='Việc đã xảy ra và kết thúc trong quá khứ.', yes='I played. / I went.',
         no="I didn't play. / I didn't go.", ask='Did you play? / Did you go?',
         signals='yesterday, last week, last year, ago',
         example=('We went to the zoo yesterday.', 'Hôm qua chúng tớ đi sở thú.'), lesson='G17'),
    dict(id='past_continuous', emoji='⏸️', name_en='Past continuous', name_vi='Quá khứ tiếp diễn',
         use_vi='Việc đang diễn ra ở một lúc trong quá khứ.', yes='I was playing. / They were playing.',
         no="I wasn't playing. / They weren't playing.", ask='Were you playing?',
         signals='at eight o\'clock yesterday, when, while',
         example=('I was eating when Dad came home.', 'Tớ đang ăn thì bố về.'), lesson='G25'),
    dict(id='going_to', emoji='🗓️', name_en='Be going to', name_vi='Tương lai dự định',
         use_vi='Việc đã có kế hoạch, hoặc sắp xảy ra.', yes="I'm going to swim.",
         no="I'm not going to swim.", ask='Are you going to swim?',
         signals='tomorrow, next week, this weekend',
         example=("I'm going to visit Grandma.", 'Tớ định đi thăm bà.'), lesson='G19'),
    dict(id='future_will', emoji='🔮', name_en='Future with will', name_vi='Tương lai đơn',
         use_vi='Điều sẽ xảy ra, lời hứa, quyết định ngay lúc nói.', yes='I will help.',
         no="I won't help.", ask='Will you help?',
         signals='tomorrow, next year, I think, maybe',
         example=('It will be sunny tomorrow.', 'Ngày mai trời sẽ nắng.'), lesson='G20'),
    dict(id='present_perfect', emoji='🌍', name_en='Present perfect', name_vi='Hiện tại hoàn thành',
         use_vi='Trải nghiệm đã từng có, việc vừa mới xong.', yes='I have seen it. / She has seen it.',
         no="I haven't seen it.", ask='Have you ever seen it?',
         signals='ever, never, already, just, yet',
         example=('I have never seen snow.', 'Tớ chưa bao giờ thấy tuyết.'), lesson='G24'),
]

# ---------------------------------------------------------------------------
# Verb table. Irregular verbs: base -> (past, past participle). Regular forms
# are built by the spelling rules below and checked against EXPECT.
# ---------------------------------------------------------------------------
IRREGULAR = {
    'be': ('was / were', 'been'), 'have': ('had', 'had'), 'do': ('did', 'done'), 'go': ('went', 'gone'),
    'come': ('came', 'come'), 'see': ('saw', 'seen'), 'eat': ('ate', 'eaten'), 'drink': ('drank', 'drunk'),
    'make': ('made', 'made'), 'take': ('took', 'taken'), 'give': ('gave', 'given'), 'get': ('got', 'got'),
    'run': ('ran', 'run'), 'swim': ('swam', 'swum'), 'sing': ('sang', 'sung'), 'buy': ('bought', 'bought'),
    'bring': ('brought', 'brought'), 'think': ('thought', 'thought'), 'catch': ('caught', 'caught'),
    'teach': ('taught', 'taught'), 'write': ('wrote', 'written'), 'read': ('read', 'read'),
    'ride': ('rode', 'ridden'), 'drive': ('drove', 'driven'), 'fly': ('flew', 'flown'),
    'draw': ('drew', 'drawn'), 'sleep': ('slept', 'slept'), 'sit': ('sat', 'sat'), 'stand': ('stood', 'stood'),
    'speak': ('spoke', 'spoken'), 'tell': ('told', 'told'), 'say': ('said', 'said'), 'find': ('found', 'found'),
    'put': ('put', 'put'), 'cut': ('cut', 'cut'), 'know': ('knew', 'known'), 'grow': ('grew', 'grown'),
    'throw': ('threw', 'thrown'), 'wear': ('wore', 'worn'), 'win': ('won', 'won'), 'lose': ('lost', 'lost'),
    'begin': ('began', 'begun'), 'break': ('broke', 'broken'), 'fall': ('fell', 'fallen'),
    'feel': ('felt', 'felt'), 'hear': ('heard', 'heard'), 'leave': ('left', 'left'), 'meet': ('met', 'met'),
    'send': ('sent', 'sent'), 'spend': ('spent', 'spent'), 'wake': ('woke', 'woken'), 'hide': ('hid', 'hidden'),
    'build': ('built', 'built'), 'forget': ('forgot', 'forgotten'), 'understand': ('understood', 'understood'),
}

VERBS = [
    # (base, Vietnamese, emoji)
    ('be', 'là, thì, ở', '🙋'), ('have', 'có', '🎁'), ('do', 'làm', '🛠️'), ('go', 'đi', '🚶'),
    ('come', 'đến', '👋'), ('see', 'nhìn thấy', '👀'), ('eat', 'ăn', '🍚'), ('drink', 'uống', '🥛'),
    ('make', 'làm, tạo ra', '🧁'), ('take', 'cầm, mang đi', '🤲'), ('give', 'cho, tặng', '🎁'),
    ('get', 'nhận được', '📬'), ('run', 'chạy', '🏃'), ('swim', 'bơi', '🏊'), ('sing', 'hát', '🎤'),
    ('buy', 'mua', '🛒'), ('bring', 'mang đến', '🧺'), ('think', 'nghĩ', '🤔'), ('catch', 'bắt', '🥎'),
    ('teach', 'dạy', '👩‍🏫'), ('write', 'viết', '✍️'), ('read', 'đọc', '📖'), ('ride', 'đi (xe), cưỡi', '🚲'),
    ('drive', 'lái xe', '🚗'), ('fly', 'bay', '🪁'), ('draw', 'vẽ', '🖍️'), ('sleep', 'ngủ', '😴'),
    ('sit', 'ngồi', '🪑'), ('stand', 'đứng', '🧍'), ('speak', 'nói', '🗣️'), ('tell', 'kể, bảo', '💬'),
    ('say', 'nói', '💭'), ('find', 'tìm thấy', '🔍'), ('put', 'đặt, để', '📥'), ('cut', 'cắt', '✂️'),
    ('know', 'biết', '💡'), ('grow', 'lớn lên, trồng', '🌱'), ('throw', 'ném', '🤾'), ('wear', 'mặc, đội', '👕'),
    ('win', 'thắng', '🏆'), ('lose', 'thua, đánh mất', '😟'), ('begin', 'bắt đầu', '🏁'), ('break', 'làm vỡ', '💥'),
    ('fall', 'ngã, rơi', '🍂'), ('feel', 'cảm thấy', '💛'), ('hear', 'nghe thấy', '👂'), ('leave', 'rời đi', '🚪'),
    ('meet', 'gặp', '🤝'), ('send', 'gửi', '📨'), ('spend', 'tiêu (tiền), dành (thời gian)', '💰'), ('wake', 'thức dậy', '⏰'), ('hide', 'trốn, giấu', '🙈'),
    ('build', 'xây', '🧱'), ('forget', 'quên', '❓'), ('understand', 'hiểu', '✅'),
    ('play', 'chơi', '⚽'), ('like', 'thích', '👍'), ('love', 'yêu', '❤️'), ('want', 'muốn', '🙏'),
    ('need', 'cần', '🆘'), ('help', 'giúp', '🤝'), ('watch', 'xem', '📺'), ('listen', 'nghe', '🎧'),
    ('look', 'nhìn', '👁️'), ('walk', 'đi bộ', '🚶'), ('jump', 'nhảy', '🦘'), ('dance', 'nhảy múa', '💃'),
    ('cook', 'nấu ăn', '🍳'), ('clean', 'dọn dẹp', '🧹'), ('wash', 'rửa', '🧼'), ('brush', 'chải, đánh (răng)', '🪥'),
    ('open', 'mở', '📂'), ('close', 'đóng', '🚪'), ('start', 'bắt đầu', '▶️'), ('stop', 'dừng lại', '🛑'),
    ('carry', 'xách, mang', '🎒'), ('cry', 'khóc', '😢'), ('study', 'học', '📚'), ('try', 'thử, cố gắng', '💪'),
    ('visit', 'thăm', '🏡'), ('live', 'sống', '🏠'), ('climb', 'leo', '🧗'), ('smile', 'cười mỉm', '😊'),
    ('laugh', 'cười to', '😂'), ('kick', 'đá', '🦵'), ('paint', 'tô màu, sơn', '🎨'), ('plant', 'trồng cây', '🌳'),
    ('rain', 'mưa', '🌧️'), ('fix', 'sửa', '🔧'), ('finish', 'làm xong', '🏁'), ('ask', 'hỏi', '❔'),
    ('answer', 'trả lời', '🙋'), ('enjoy', 'tận hưởng, thích', '🥳'), ('shop', 'đi mua sắm', '🛍️'),
]

VOWELS = 'aeiou'
# Verbs ending consonant-vowel-consonant whose last letter is doubled.
DOUBLE = {'stop', 'run', 'swim', 'sit', 'get', 'put', 'cut', 'win', 'begin', 'shop', 'forget', 'plan', 'hop', 'clap'}


def third(v):
    if v == 'be':
        return 'is'
    if v == 'have':
        return 'has'
    if v in ('do', 'go'):
        return v + 'es'
    if re.search(r'(s|sh|ch|x|z)$', v):
        return v + 'es'
    if v.endswith('y') and v[-2] not in VOWELS:
        return v[:-1] + 'ies'
    return v + 's'


def ing(v):
    if v == 'be':
        return 'being'
    if v == 'lie':
        return 'lying'
    if v.endswith('ie'):
        return v[:-2] + 'ying'
    if v.endswith('e') and not v.endswith('ee') and v not in ('be',):
        return v[:-1] + 'ing'
    if v in DOUBLE:
        return v + v[-1] + 'ing'
    return v + 'ing'


def regular_past(v):
    if v.endswith('e'):
        return v + 'd'
    if v.endswith('y') and v[-2] not in VOWELS:
        return v[:-1] + 'ied'
    if v in DOUBLE:
        return v + v[-1] + 'ed'
    return v + 'ed'


EXPECT = {
    'go': ('goes', 'going'), 'watch': ('watches', 'watching'), 'fly': ('flies', 'flying'),
    'play': ('plays', 'playing'), 'dance': ('dances', 'dancing'), 'swim': ('swims', 'swimming'),
    'see': ('sees', 'seeing'), 'study': ('studies', 'studying'), 'carry': ('carries', 'carrying'),
    'fix': ('fixes', 'fixing'), 'stop': ('stops', 'stopping'), 'begin': ('begins', 'beginning'),
    'visit': ('visits', 'visiting'), 'open': ('opens', 'opening'), 'enjoy': ('enjoys', 'enjoying'),
    'write': ('writes', 'writing'), 'have': ('has', 'having'), 'do': ('does', 'doing'),
}
EXPECT_PAST = {'cry': 'cried', 'stop': 'stopped', 'dance': 'danced', 'play': 'played', 'visit': 'visited',
               'shop': 'shopped', 'enjoy': 'enjoyed', 'study': 'studied', 'carry': 'carried', 'fix': 'fixed'}


def verbs():
    out = []
    seen = set()
    for base, vi, emoji in VERBS:
        assert base not in seen, base
        seen.add(base)
        if base in IRREGULAR:
            past, pp = IRREGULAR[base]
        else:
            past = pp = regular_past(base)
        out.append(dict(base=base, s=third(base), ing=ing(base), past=past, pp=pp, vi=vi, emoji=emoji,
                        irregular=base in IRREGULAR))
    for v, (s, g) in EXPECT.items():
        row = next(r for r in out if r['base'] == v)
        assert (row['s'], row['ing']) == (s, g), (v, row)
    for v, p in EXPECT_PAST.items():
        row = next(r for r in out if r['base'] == v)
        assert row['past'] == p, (v, row)
    assert set(IRREGULAR) <= seen, set(IRREGULAR) - seen
    return out


def parse_practice(lid, lines):
    out = []
    for raw in lines:
        kind, body = raw[0], raw[2:]
        parts = [p.strip() for p in body.split('|')]
        if kind == 'C':
            q, right, w1, w2, vi, why = parts
            assert '___' in q, (lid, q)
            assert len({right, w1, w2}) == 3, (lid, q)
            out.append(dict(kind='choose', q=q, answer=right, options=[right, w1, w2], vi=vi, why_vi=why))
        elif kind == 'O':
            sentence, vi = parts
            words = sentence.split()
            assert 3 <= len(words) <= 9, (lid, sentence)
            out.append(dict(kind='order', words=words, vi=vi))
        else:
            raise ValueError(raw)
    return out


def main():
    lessons = []
    ids = set()
    for l in L:
        assert l['id'] not in ids
        ids.add(l['id'])
        practice = parse_practice(l['id'], l['practice'])
        assert sum(p['kind'] == 'choose' for p in practice) >= 5, l['id']
        assert sum(p['kind'] == 'order' for p in practice) >= 2, l['id']
        head, rows = l['table'] if l['table'] else ([], [])
        for r in rows:
            assert len(r) == len(head), (l['id'], r)
        lessons.append(dict(
            id=l['id'], stage=l['stage'], emoji=l['emoji'], title_en=l['title_en'], title_vi=l['title_vi'],
            explain_vi=l['explain_vi'], table=dict(head=head, rows=rows),
            examples=[dict(en=e, vi=v) for e, v in l['examples']], practice=practice))
    for t in TENSES:
        assert t['lesson'] in ids, t
        t['example'] = dict(en=t['example'][0], vi=t['example'][1])
    data = dict(version=1, stages=[dict(stage=s, name_vi=v, name_en=e, emoji=m) for s, v, e, m in STAGES],
                lessons=lessons, tenses=TENSES, verbs=verbs())
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
        f.write('\n')
    n = sum(len(l['practice']) for l in lessons)
    print(f'{len(lessons)} lessons, {n} practice questions, {len(TENSES)} tenses, {len(data["verbs"])} verbs')


if __name__ == '__main__':
    main()
