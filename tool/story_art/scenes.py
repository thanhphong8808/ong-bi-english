# tool/story_art/scenes.py
#
# One place for every story illustration: where each scene appears in
# assets/talk/stories.txt (block + the English line it comes before) and the
# prompt to draw it. build.py writes the "scene: N" lines into the stories
# and the prompt pack (docs/STORY_ART.md + prompts.json) from this file, so
# pictures and story text always match.
#
# Scene 0 is the cover (story picker); scenes 1-6 change as Bi tells the
# story. Files: assets/story_art/<story id>_<NN>.webp

STYLE = (
    "Children's picture-book illustration in a soft 3D animated look: rounded, toy-like characters "
    "with big friendly eyes and gentle smiles, warm morning sunlight, honey-gold and soft pastel colours, "
    "clean simple background, soft shadows, cosy and safe mood for a 6-year-old. "
    "Landscape 16:10, main characters large and centred, no text, no letters, no logos."
)

NEGATIVE = (
    "text, letters, words, numbers, watermark, logo, signature, scary, horror, blood, injury, weapons, "
    "sharp fangs, angry monster, realistic photo, dark gloomy lighting, extra limbs, deformed hands, "
    "cluttered background"
)

# Bi, the app's mascot, in 3D (for the home screen and the chat).
BI = (
    "Bi, a cute chubby little bee mascot: round honey-yellow head with rosy pink cheeks and big shiny "
    "dark eyes, two curly antennae tipped with small orange balls, round yellow body with two "
    "chocolate-brown stripes, tiny light-blue translucent wings, short little arms, soft 3D vinyl-toy look"
)

BI_POSES = [
    ("happy", "waving one hand and smiling, floating slightly"),
    ("listening", "holding one hand behind its ear, eyes wide and curious, leaning forward"),
    ("thinking", "finger on chin, looking up, with a small sparkle above its head"),
    ("cheering", "jumping with both arms up, eyes closed with joy, a few golden confetti pieces"),
    ("sleeping", "curled up and floating, eyes closed, peaceful smile, a tiny star-patterned nightcap"),
]

# What Bi wears at each level (same order as biOutfits in lib/widgets/bi_mascot.dart).
# Level 0 wears nothing; sleeping Bi always wears only the nightcap.
BI_OUTFITS = [
    "",
    "wearing a small red baseball cap",
    "wearing a small red baseball cap and a blue bow tie",
    "wearing round brown glasses and a blue bow tie",
    "wearing round brown glasses and a soft green knitted scarf",
    "wearing a dark-blue graduation cap with a golden tassel, round brown glasses and a soft green knitted scarf",
]

STORIES = {
    "tortoise_hare": {
        "title": "The Tortoise and the Hare | Rùa và Thỏ",
        "cast": {
            "Hare": "a slim light-brown hare with long upright ears, a white belly and a small red scarf",
            "Tortoise": "a small green tortoise with a round dark-green patterned shell and a kind, calm smile",
        },
        "scenes": [
            (0, None, None, "Hare and Tortoise stand side by side at a start line on a sunny meadow path, small coloured flags, wildflowers"),
            (1, "start", "This is Hare.", "Hare zooms along a meadow path with little dust clouds while Tortoise walks slowly behind, smiling"),
            (2, "race", "Ready, steady, go!", "the race begins: Hare dashes off from a start line drawn in the dirt, Tortoise takes his first careful step, a few animal friends cheer from the grass"),
            (3, "race", "Hare sleeps under a tree.", "Hare is fast asleep in the shade of a big leafy tree, curled up with a happy face, sleepy bubbles floating up"),
            (4, "walk", None, "Tortoise walks steadily past the sleeping Hare, looking determined, butterflies above"),
            (5, "finish", None, "Tortoise breaks a ribbon at the finish line while small animals cheer; far behind, Hare runs with a surprised face"),
        ],
    },
    "lion_mouse": {
        "title": "The Lion and the Mouse | Sư tử và chuột nhắt",
        "cast": {
            "Lion": "a big golden lion with a fluffy orange mane and gentle eyes",
            "Mouse": "a tiny grey mouse with round pink ears and big bright eyes",
        },
        "scenes": [
            (0, None, None, "the big Lion and the tiny Mouse together on a grassy savanna hill, the Mouse sitting on the Lion's paw, both smiling"),
            (1, "start", "A big lion is sleeping.", "the Lion sleeps on a warm rock in the savanna while the little Mouse runs across his nose"),
            (2, "start", "Grrr!", "the Lion, just woken, holds the Mouse gently in his big paw; the Mouse clasps her hands, asking to be let go"),
            (3, "net", None, "the Lion is caught in a big rope net hanging between trees, looking worried, not hurt"),
            (4, "help", None, "the little Mouse bites through the ropes of the net, bite by bite, the Lion watching hopefully"),
            (5, "life", None, "the Lion, free, smiles at the Mouse sitting on his head; best friends in the sunset"),
        ],
    },
    "boy_wolf": {
        "title": "The Boy Who Cried Wolf | Cậu bé chăn cừu",
        "cast": {
            "Boy": "a young shepherd boy with messy brown hair, a straw hat and a small wooden staff",
            "Villagers": "friendly village grown-ups in simple farm clothes",
            "Wolf": "a grey cartoon wolf, mischievous but not scary, soft rounded shapes",
        },
        "scenes": [
            (0, None, None, "the shepherd Boy sits on a green hill with fluffy white sheep around him, a small village below"),
            (1, "start", "A boy looks after the sheep", "the Boy yawns on the hill watching fluffy sheep graze, bored, chin on his hand"),
            (2, "start", "The people run up the hill.", "villagers run up the hill with worried faces while the Boy laughs, holding his tummy"),
            (3, "again", None, "the villagers stand with crossed arms and frowning faces in front of the Boy, who looks down"),
            (4, "real", None, "the grey cartoon Wolf sneaks towards the sheep at the edge of the meadow while the Boy waves his arms and shouts"),
            (5, "sad", None, "the Boy sits alone on the empty hill looking sad and sorry, sunset sky, a single sheep returning to him"),
        ],
    },
    "ant_grasshopper": {
        "title": "The Ant and the Grasshopper | Kiến và châu chấu",
        "cast": {
            "Ant": "a small hard-working red ant with a tiny blue cap and a little backpack",
            "Grasshopper": "a lanky green grasshopper holding a tiny violin, cheerful",
        },
        "scenes": [
            (0, None, None, "the Ant carrying a grain of rice and the Grasshopper playing his violin on a sunny summer leaf"),
            (1, "start", "It is summer.", "a bright summer field: the Ant carries food along a path of leaves under a hot sun"),
            (2, "sing", None, "the Grasshopper sings and plays his violin on a flower, music notes floating, while the Ant works in the background"),
            (3, "winter", None, "a snowy winter field, the Grasshopper shivers alone in the snow, hugging himself"),
            (4, "door", None, "the Ant opens the round door of her cosy home under a tree root and welcomes the cold Grasshopper inside; warm light, shelves of food"),
        ],
    },
    "fox_grapes": {
        "title": "The Fox and the Grapes | Cáo và chùm nho",
        "cast": {
            "Fox": "an orange fox with a fluffy white-tipped tail and a hungry, hopeful face",
        },
        "scenes": [
            (0, None, None, "the Fox looks up at a bunch of purple grapes hanging from a vine above a garden wall"),
            (1, "start", "A hungry fox", "the Fox licks his lips, staring at juicy purple grapes high on a vine"),
            (2, "start", "The grapes are high up.", "the Fox jumps high with paws stretched out, the grapes just out of reach"),
            (3, "jump", "He jumps again", "the Fox sits on the ground, tired, with crossed arms, turning his nose up at the grapes"),
            (4, "life", None, "the Fox walks away down a sunny path, looking back at the grapes with a little sigh"),
        ],
    },
    "thirsty_crow": {
        "title": "The Thirsty Crow | Con quạ thông minh",
        "cast": {
            "Crow": "a clever black crow with a shiny blue sheen and bright curious eyes",
        },
        "scenes": [
            (0, None, None, "the Crow perched on the rim of a clay jar in a sunny yard, small pebbles around"),
            (1, "start", "It is a very hot day.", "the Crow flies over a dry, sunny countryside, looking thirsty, heat shimmer in the air"),
            (2, "start", "The crow finds a jar.", "the Crow peeks into a tall clay jar; deep inside there is only a little water"),
            (3, "stones", "He picks up a stone.", "the Crow drops a pebble into the jar, plop, a little splash"),
            (4, "stones", "The water comes up", "the water has risen to the top of the jar; the Crow happily drinks, pebbles visible inside"),
        ],
    },
    "golden_egg": {
        "title": "The Goose and the Golden Egg | Con ngỗng đẻ trứng vàng",
        "cast": {
            "Farmer": "a round-faced farmer with a straw hat and blue overalls",
            "Goose": "a big white goose with an orange beak and a proud, kind face",
        },
        "scenes": [
            (0, None, None, "the white Goose sits proudly next to a shining golden egg in a straw nest, the Farmer smiling behind"),
            (1, "start", "A farmer has a special goose.", "a little farm with a barn; the Farmer feeds the white Goose in the yard"),
            (2, "start", "Every morning", "the Farmer holds up a shining golden egg in amazement, sparkles around it"),
            (3, "chase", None, "the Farmer chases the Goose around the farmyard with open arms; the Goose flaps away, worried"),
            (4, "chase", "The goose flies away.", "the Goose flies away over the hills while the Farmer stands with empty hands, sad"),
        ],
    },
    "dog_reflection": {
        "title": "The Dog and His Reflection | Con chó tham ăn",
        "cast": {
            "Dog": "a fluffy brown puppy with floppy ears and a red collar",
        },
        "scenes": [
            (0, None, None, "the brown Dog proudly carrying a big bone on a little wooden bridge over a sparkling river"),
            (1, "start", "A dog has a big bone.", "the Dog trots happily along a village path with a big bone in his mouth"),
            (2, "start", "He walks on a bridge", "the Dog on a wooden bridge looks down into the clear river and sees his own reflection holding a bone"),
            (3, "bark", None, "the Dog barks at the water and his bone falls with a splash into the river"),
            (4, "bark", "Oh no!", "the Dog sits on the bridge looking sadly at the ripples where the bone sank"),
        ],
    },
    "wind_sun": {
        "title": "The Wind and the Sun | Gió và Mặt Trời",
        "cast": {
            "Wind": "a puffy blue cloud character with chubby cheeks blowing air",
            "Sun": "a smiling golden sun character with soft rays and rosy cheeks",
            "Man": "a traveller with a long brown coat and a hat walking on a country road",
        },
        "scenes": [
            (0, None, None, "the Wind cloud and the smiling Sun in the sky above a traveller in a brown coat on a country road"),
            (1, "start", None, "the puffy Wind cloud and the golden Sun face each other in the sky, as if having a friendly contest"),
            (2, "wind", None, "the Wind blows hard; the traveller holds his coat tight, leaves and his hat flying"),
            (3, "sun_turn", None, "the Sun shines warmly; the traveller wipes his forehead in the bright light"),
            (4, "win", None, "the traveller takes off his coat and relaxes under a tree; the Sun smiles and the Wind looks surprised"),
        ],
    },
    "town_country_mouse": {
        "title": "The Town Mouse and the Country Mouse | Chuột thành phố và chuột đồng quê",
        "cast": {
            "Country Mouse": "a brown mouse in a straw hat and a patched green vest",
            "Town Mouse": "a grey mouse in a smart red jacket and a bow tie",
        },
        "scenes": [
            (0, None, None, "the Country Mouse and the Town Mouse shaking hands in a golden wheat field"),
            (1, "start", "Country Mouse lives in a field.", "the Country Mouse welcomes the Town Mouse to a tiny burrow in a wheat field with corn and bread on a leaf"),
            (2, "town", "The town house is big.", "inside a grand town house kitchen, the two mice stand on a table full of cake and cheese, eyes wide"),
            (3, "town", "Suddenly, a big cat comes!", "a big round fluffy cat peeks around the kitchen door (cute, not scary); the two mice freeze"),
            (4, "home", None, "the Country Mouse back home in his cosy field burrow, smiling and safe under the stars"),
        ],
    },
    "fox_crow": {
        "title": "The Fox and the Crow | Cáo và quạ",
        "cast": {
            "Fox": "a sly orange fox with a fluffy tail and a big charming smile",
            "Crow": "a shiny black crow holding a yellow piece of cheese in her beak",
        },
        "scenes": [
            (0, None, None, "the Crow on a tree branch with a piece of cheese, the Fox looking up from below"),
            (1, "start", "A crow sits in a tree.", "the Crow sits proudly on a branch with a yellow piece of cheese in her beak, sunny forest"),
            (2, "start", "Hello, beautiful Crow!", "the Fox bows politely under the tree, paws together, flattering the Crow"),
            (3, "sing", None, "the Crow opens her beak to sing and the cheese falls down; the Fox catches it"),
            (4, "sing", "Oh no!", "the Fox trots away with the cheese while the Crow looks down, surprised and a little sad"),
        ],
    },
    "dove_ant": {
        "title": "The Dove and the Ant | Chim bồ câu và kiến",
        "cast": {
            "Dove": "a soft white dove with a gentle face",
            "Ant": "a tiny brave red ant",
            "Bird-catcher": "a man in a brown hat carrying a big net, comic and harmless-looking",
        },
        "scenes": [
            (0, None, None, "the white Dove on a branch and the tiny Ant on a green leaf by a river, smiling at each other"),
            (1, "start", "A little ant falls", "the tiny Ant floats in a gently flowing river, waving for help; the Dove watches from a branch"),
            (2, "leaf", None, "the Dove drops a green leaf into the river and the Ant climbs onto it, safe"),
            (3, "hunter", None, "a bird-catcher with a big net sneaks towards the Dove resting on a branch"),
            (4, "bite", "The ant bites his foot.", "the bird-catcher hops on one foot in surprise while the Dove flies away to safety; the Ant cheers on the grass"),
        ],
    },
    "bundle_sticks": {
        "title": "The Bundle of Sticks | Bó đũa",
        "cast": {
            "Father": "a kind old Vietnamese grandfather-like father with white hair and a long beard, in a simple brown shirt",
            "Brothers": "three young brothers of different heights in simple village clothes",
        },
        "scenes": [
            (0, None, None, "an old father holding a bundle of sticks tied with red string, three sons around him in a village yard"),
            (1, "start", "An old father has three sons.", "three brothers argue and pull at a basket in a village yard while their old father watches"),
            (2, "start", "He ties the sticks together.", "the father ties a bundle of sticks with red string and hands it to his sons"),
            (3, "try", None, "the brothers try hard to break the bundle, straining, but it does not bend"),
            (4, "one", "Snap!", "each brother easily snaps a single stick, surprised; the father smiles"),
            (5, "one", "We will stay together!", "the three brothers hug each other, smiling, the father happy behind them"),
        ],
    },
    "fox_stork": {
        "title": "The Fox and the Stork | Cáo và cò",
        "cast": {
            "Fox": "an orange fox with a playful grin and an apron",
            "Stork": "a tall white stork with a long orange beak and long legs, elegant",
        },
        "scenes": [
            (0, None, None, "the Fox and the Stork at a little garden table, a flat plate and a tall jar between them"),
            (1, "start", None, "the Fox serves soup on a flat plate at his cosy den; the Stork's long beak cannot pick it up"),
            (2, "hungry", None, "the Fox laps up the soup happily while the Stork looks hungry and a bit sad"),
            (3, "stork_turn", None, "at the Stork's house the Stork serves food in a tall narrow jar; the Fox cannot reach inside"),
            (4, "sorry", None, "the Fox says sorry with his ears down; the Stork smiles kindly, both sharing a meal from bowls that suit them"),
        ],
    },
    "two_friends_bear": {
        "title": "The Two Friends and the Bear | Hai người bạn và con gấu",
        "cast": {
            "Tom": "a boy with spiky red hair and a green T-shirt",
            "Sam": "a boy with short black hair and an orange T-shirt",
            "Bear": "a big round brown bear, cuddly-looking and curious, not scary",
        },
        "scenes": [
            (0, None, None, "two boy friends walking on a forest path, a curious brown bear peeking from behind a tree"),
            (1, "start", "Tom and Sam walk", "Tom and Sam walk happily arm in arm along a sunny forest path"),
            (2, "start", "Suddenly, a big bear comes!", "a big round brown bear appears on the path; Tom quickly climbs a tree, leaving Sam on the ground"),
            (3, "bear", "The bear sniffs Sam.", "Sam lies very still on the grass with eyes closed while the curious bear sniffs his hair"),
            (4, "bear", "What did the bear say to you?", "the bear has gone; Tom climbs down and Sam stands up, looking at Tom thoughtfully"),
        ],
    },
    "belling_cat": {
        "title": "Belling the Cat | Đeo nhạc cho mèo",
        "cast": {
            "Mice": "a group of little grey and brown mice",
            "Old mouse": "a wise old mouse with white whiskers, round glasses and a walking stick",
            "Cat": "a big fluffy orange cat, sleepy and round, not scary",
        },
        "scenes": [
            (0, None, None, "a group of mice gathered around a small golden bell on a red ribbon"),
            (1, "start", "The mice are scared", "the big fluffy cat tiptoes quietly across a kitchen floor while mice peek from a hole in the wall"),
            (2, "start", "I have an idea!", "a young mouse stands on a spool of thread, holding up a little golden bell to the other mice, excited"),
            (3, "who", None, "the wise old mouse asks a question; all the mice look at each other, nobody raising a hand"),
            (4, "life", None, "the mice still sit around the bell, thinking, the sleeping cat in the background"),
        ],
    },
    "milkmaid": {
        "title": "The Milkmaid and Her Pail | Cô gái và thùng sữa",
        "cast": {
            "Milkmaid": "a cheerful girl with two braids, a blue dress and a wooden milk pail",
        },
        "scenes": [
            (0, None, None, "the Milkmaid walking on a country lane balancing a wooden milk pail on her head"),
            (1, "start", "A girl carries a pail", "the Milkmaid walks along a sunny country lane with the milk pail on her head"),
            (2, "start", "The eggs will be chicks.", "the Milkmaid daydreams: a dreamy cloud above her shows eggs, fluffy chicks and a pretty dress"),
            (3, "start", "She dances and jumps!", "the Milkmaid skips and dances happily; the pail on her head tips"),
            (4, "right", None, "the milk splashes onto the road and the Milkmaid looks surprised, hands on her cheeks"),
        ],
    },
    "little_red_hen": {
        "title": "The Little Red Hen | Cô gà mái đỏ",
        "cast": {
            "Hen": "a little red hen with a white apron",
            "Cat": "a lazy orange cat",
            "Dog": "a sleepy brown dog",
            "Duck": "a white duck with a yellow beak",
        },
        "scenes": [
            (0, None, None, "the Little Red Hen holding a warm loaf of bread, her yellow chicks around her"),
            (1, "start", None, "the Hen holds up wheat seeds; the cat, dog and duck lounge in the sun, shaking their heads"),
            (2, "start", "Then I will do it myself.", "the Hen plants seeds in a little field by herself, determined"),
            (3, "grow", None, "tall golden wheat in the field; the Hen carries a sack of flour"),
            (4, "bake", None, "the Hen takes a golden loaf out of a cosy oven, the smell drawing the cat, dog and duck to the window"),
            (5, "bake", "No! You didn't help.", "the Hen and her chicks happily share the bread at a little table"),
        ],
    },
    "ugly_duckling": {
        "title": "The Ugly Duckling | Vịt con xấu xí",
        "cast": {
            "Duckling": "a big fluffy grey duckling with big shy eyes",
            "Ducks": "small yellow ducklings and a mother duck",
            "Swans": "graceful white swans",
        },
        "scenes": [
            (0, None, None, "a grey duckling looking at his reflection in a calm pond, a white swan reflection shimmering"),
            (1, "start", "Mother Duck has some eggs.", "eggs hatch in a nest by a pond; small yellow ducklings and one big grey duckling come out"),
            (2, "start", "You are ugly!", "the yellow ducklings turn away from the sad grey duckling by the pond"),
            (3, "alone", None, "the grey duckling sits alone among snowy reeds in winter, looking lonely"),
            (4, "spring", None, "spring flowers by the pond; the duckling looks at the water and sees a beautiful white swan"),
            (5, "friends", None, "the young swan swims happily with other white swans on a sparkling lake"),
        ],
    },
    "star_fruit_tree": {
        "title": "The Star Fruit Tree | Cây khế",
        "cast": {
            "Younger brother": "a kind young Vietnamese man in a simple brown shirt and a conical hat",
            "Older brother": "a plump older Vietnamese man in fancy clothes with a greedy grin",
            "Bird": "a giant magical bird with golden-orange feathers and a long tail, friendly",
        },
        "scenes": [
            (0, None, None, "a star fruit tree full of yellow star fruit, a giant golden bird perched on it, a Vietnamese countryside"),
            (1, "start", "Two brothers live in Viet Nam.", "a Vietnamese village: the older brother walks into a big house while the younger brother stands next to a small star fruit tree"),
            (2, "bird", None, "the giant golden bird eats star fruit in the tree; the younger brother speaks to it politely"),
            (3, "island", None, "the younger brother rides on the giant bird's back over the sea to a small island sparkling with gold"),
            (4, "older", "The older brother makes a very big bag.", "the older brother on the island stuffs a huge bag with gold while the bird waits, worried"),
            (5, "life", None, "the giant bird flies over a calm sea at sunset; a big heavy bag of gold drops and splashes into the water"),
        ],
    },
    "frog_well": {
        "title": "The Frog in the Well | Ếch ngồi đáy giếng",
        "cast": {
            "Frog": "a green frog with big eyes and a tiny golden crown made of a leaf",
        },
        "scenes": [
            (0, None, None, "a green frog sitting at the bottom of an old stone well, looking up at a small circle of blue sky"),
            (1, "start", "A frog lives at the bottom", "the frog at the bottom of a mossy well, a small round patch of sky far above"),
            (2, "start", "I am the king of the world!", "the frog puffs out his chest proudly on a stone in the well, wearing a little leaf crown"),
            (3, "rain", "One day, it rains a lot.", "heavy rain fills the well and the frog floats up to the top, surprised"),
            (4, "rain", "Wow! The sky is so big!", "the frog stands outside the well amazed by a huge sky, rice fields and mountains"),
            (5, "life", None, "a big water buffalo walks by near the frog, who jumps aside just in time, eyes wide"),
        ],
    },
    "blind_men_elephant": {
        "title": "The Blind Men and the Elephant | Thầy bói xem voi",
        "cast": {
            "Men": "three kind old men with closed eyes and gentle smiles, in simple traditional Vietnamese clothes",
            "Elephant": "a big friendly grey elephant with big ears and a calm face",
            "Child": "a smiling Vietnamese child in a yellow shirt",
        },
        "scenes": [
            (0, None, None, "a friendly elephant in a village square with three old men gently touching its trunk, ear and leg"),
            (1, "start", "Some men can't see.", "three old men with closed eyes walk with walking sticks towards a big friendly elephant"),
            (2, "start", "Each man touches one part.", "one old man touches the trunk, one the ear, one the leg; each looks thoughtful"),
            (3, "fight", None, "the three old men argue with waving hands while the elephant watches calmly"),
            (4, "fight", "A child says", "a smiling child points at the whole elephant, showing the trunk, ears, legs and tail; the men listen"),
        ],
    },
    "body_team": {
        "title": "Feet, Hands, Ears, Eyes and Mouth | Chân, Tay, Tai, Mắt, Miệng",
        "cast": {
            "Child": "a cheerful Vietnamese child with short black hair in a striped shirt",
        },
        "scenes": [
            (0, None, None, "a cheerful child surrounded by five small round icons with smiles: a hand, a foot, an eye, an ear and a mouth"),
            (1, "start", None, "the child happily playing, running and eating rice, little sparkles around the hands and feet"),
            (2, "stop", None, "the child lies tired on a bed, too weak to play, toys untouched on the floor"),
            (3, "strong", None, "the child eats a healthy meal at a family table and feels strong again, smiling"),
            (4, "life", None, "a class of children working together on a big drawing, each doing a part"),
        ],
    },
}
