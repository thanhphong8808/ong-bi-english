// lib/features/talk_with_bi/bi_scenarios.dart
//
// Role-play situations and story starters for "Talk with Bi". All original.

class BiScenario {
  const BiScenario({
    required this.id,
    required this.emoji,
    required this.titleVi,
    required this.place,
    required this.biRole,
    required this.kidRole,
    required this.opener,
    required this.hints,
    required this.minLevel,
  });

  final String id;
  final String emoji;
  final String titleVi;
  final String place;
  final String biRole;
  final String kidRole;

  /// Bi's first line, fixed so the session starts instantly.
  final String opener;

  /// Default reply suggestions for the hint buttons.
  final List<String> hints;
  final int minLevel;
}

class BiStory {
  const BiStory({required this.id, required this.emoji, required this.seed, required this.opener});

  final String id;
  final String emoji;
  final String seed;
  final String opener;
}

const List<BiScenario> biScenarios = [
  BiScenario(
    id: 'fruit_shop',
    emoji: '🍎',
    titleVi: 'Cửa hàng hoa quả',
    place: 'a fruit shop',
    biRole: 'the shopkeeper',
    kidRole: 'a customer',
    opener: 'Hello! What fruit do you want?',
    hints: ['An apple, please.', 'A banana, please.', 'Thank you!'],
    minLevel: 0,
  ),
  BiScenario(
    id: 'park',
    emoji: '🛝',
    titleVi: 'Chơi ở công viên',
    place: 'the park',
    biRole: 'a friend',
    kidRole: 'a friend',
    opener: "Let's play! Do you like the swing?",
    hints: ['Yes, I do!', "Let's play!", 'I like the slide.'],
    minLevel: 0,
  ),
  BiScenario(
    id: 'zoo',
    emoji: '🦁',
    titleVi: 'Đi sở thú',
    place: 'the zoo',
    biRole: 'the zoo keeper',
    kidRole: 'a visitor',
    opener: 'Welcome to the zoo! Which animal do you like?',
    hints: ['I like lions.', 'I like monkeys.', 'Wow!'],
    minLevel: 0,
  ),
  BiScenario(
    id: 'birthday',
    emoji: '🎂',
    titleVi: 'Tiệc sinh nhật',
    place: 'a birthday party',
    biRole: 'the birthday child',
    kidRole: 'a guest',
    opener: "It's my birthday today! Do you want some cake?",
    hints: ['Happy birthday!', 'Yes, please.', 'Thank you!'],
    minLevel: 0,
  ),
  BiScenario(
    id: 'toy_shop',
    emoji: '🧸',
    titleVi: 'Cửa hàng đồ chơi',
    place: 'a toy shop',
    biRole: 'the shopkeeper',
    kidRole: 'a customer',
    opener: 'Hello! Can I help you?',
    hints: ['I want a ball.', 'How much is it?', 'Thank you!'],
    minLevel: 1,
  ),
  BiScenario(
    id: 'cafe',
    emoji: '🍜',
    titleVi: 'Gọi món ở quán ăn',
    place: 'a small restaurant',
    biRole: 'the waiter',
    kidRole: 'a customer',
    opener: 'Hello! What would you like to eat?',
    hints: ['Noodles, please.', 'Some water, please.', "I'd like rice."],
    minLevel: 2,
  ),
  BiScenario(
    id: 'clinic',
    emoji: '🩺',
    titleVi: 'Đi khám bác sĩ',
    place: 'a clinic',
    biRole: 'a kind doctor',
    kidRole: 'a patient',
    opener: "Hello, I'm the doctor. How are you feeling today?",
    hints: ['I have a cold.', 'My head hurts.', "I'm OK now."],
    minLevel: 2,
  ),
  BiScenario(
    id: 'library',
    emoji: '📚',
    titleVi: 'Thư viện',
    place: 'a library',
    biRole: 'the librarian',
    kidRole: 'a reader',
    opener: 'Hello! What books do you like?',
    hints: ['I like animal books.', 'Can I read this?', 'Thank you!'],
    minLevel: 2,
  ),
  BiScenario(
    id: 'directions',
    emoji: '🗺️',
    titleVi: 'Hỏi đường',
    place: 'a street in a small town',
    biRole: 'a helpful person on the street',
    kidRole: 'a visitor who is a little lost',
    opener: 'You look lost. Where do you want to go?',
    hints: ['Where is the park?', 'Is it far?', 'Thank you very much!'],
    minLevel: 4,
  ),
  BiScenario(
    id: 'phone_call',
    emoji: '📞',
    titleVi: 'Gọi điện cho bạn',
    place: 'a pretend phone call between two friends',
    biRole: 'a friend on the phone',
    kidRole: 'a friend calling',
    opener: 'Hi, thanks for calling! What are you doing today?',
    hints: ["I'm at home.", 'Do you want to play?', 'See you later!'],
    minLevel: 4,
  ),
];

const List<BiStory> biStories = [
  BiStory(
    id: 'lost_ball',
    emoji: '🐱',
    seed: 'a little cat called Mimi who loses her red ball in the garden',
    opener: 'Mimi the cat has a red ball. Where is the ball now?',
  ),
  BiStory(
    id: 'moon_bee',
    emoji: '🌙',
    seed: 'a small bee who wants to fly to the moon to see the stars',
    opener: 'A little bee wants to visit the moon! What does she need?',
  ),
  BiStory(
    id: 'rainy_day',
    emoji: '☔',
    seed: 'a duck and a frog who play in the rain and find a rainbow',
    opener: 'Duck and Frog love the rain! What do they do?',
  ),
  BiStory(
    id: 'picnic',
    emoji: '🧺',
    seed: 'a family of rabbits who go on a picnic and share food with friends',
    opener: 'The rabbits have a big picnic basket. What food is in it?',
  ),
  BiStory(
    id: 'robot',
    emoji: '🤖',
    seed: 'a friendly robot who learns to dance at school',
    opener: 'The new robot wants to dance! Can you dance?',
  ),
];
