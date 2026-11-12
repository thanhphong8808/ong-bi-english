#!/usr/bin/env python3
# tool/build_curriculum.py
#
# Builds assets/curriculum/level_N/*.json and assets/curriculum/index.json from
# the compact authoring files in tool/content_src/. Run:
#     python3 tool/build_curriculum.py
# Needs: pip install eng_to_ipa pyphen   (fonttools is optional, for emoji checks)
#
# Authoring format (one record per line, fields separated by " | "):
#   @U <n> | topic_en | topic_vi | can-do 1 ; can-do 2      themed unit
#   @S <n> | letter | ipa | Vietnamese tip                  letter sound (level 0); its W lines
#                                                           are the example words of the sound
#   G <Vietnamese grammar note>                             (level 3+)
#   W en | vi | emoji-or-file.svg | example_en | example_vi
#       An emoji written as "~😀" is only a hint: the word is abstract and is
#       never used in "tap the picture" questions.
#   P pattern_en with {x} | pattern_vi with {x} | value1,value2,...
#   D title_vi | RoleA,RoleB | keyword,swap1,swap2          dialogue (swaps optional)
#   > Role: english | vietnamese                            dialogue line
#   R title_en                                              reading text
#   > sentence one. sentence two.                           (continues the reading)
#   ? question | right answer | wrong 1 | wrong 2
#   S starter one | starter two | starter three             guided-writing starters (level 3+)
import glob, gzip, json, os, random, re, sys, warnings
warnings.filterwarnings('ignore')
import eng_to_ipa
import pyphen

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'tool', 'content_src')
OUT = os.path.join(ROOT, 'assets', 'curriculum')
HYPH = pyphen.Pyphen(lang='en_US')
IPA_FIX = {
    'mum': 'mʌm', 'grandma': 'ˈɡrænmɑ', 'grandpa': 'ˈɡrænpɑ', 'yo-yo': 'ˈjoʊjoʊ', 'bi': 'bi',
    'teddy': 'ˈtɛdi', 'rubber': 'ˈrʌbər', 'trousers': 'ˈtraʊzərz', 'pyjamas': 'pəˈdʒɑməz',
    'pho': 'fʌ', 'tv': 'ˌtiˈvi',
}

# American IPA from the CMU Pronouncing Dictionary (tool/pron/build_ipa_dict.py);
# the same file the app uses for sentences and the parents' own words.
CMU_IPA = dict(
    line.rstrip('\n').split('\t')
    for line in gzip.open(os.path.join(os.path.dirname(__file__), '..', 'assets', 'pron', 'ipa_en_us.txt.gz'),
                          'rt', encoding='utf-8')
)
# British spellings of the curriculum -> the American entry in CMU.
UK_US = {
    'colour': 'color', 'colours': 'colors', 'colourful': 'colorful', 'favourite': 'favorite', 'grey': 'gray',
    'centre': 'center', 'theatre': 'theater', 'neighbour': 'neighbor', 'behaviour': 'behavior',
    'practise': 'practice', 'jewellery': 'jewelry', 'aeroplane': 'airplane', 'chilli': 'chili',
    'humour': 'humor', 'flavour': 'flavor', 'honour': 'honor', 'metre': 'meter', 'litre': 'liter',
    'kilometre': 'kilometer', 'programme': 'program', 'travelling': 'traveling', 'cosy': 'cozy',
    'organise': 'organize', 'recognise': 'recognize', 'realise': 'realize', 'harbour': 'harbor',
}
CLUSTERS = ('scr', 'spl', 'spr', 'str', 'thr', 'bl', 'br', 'cl', 'cr', 'dr', 'fl', 'fr', 'gl', 'gr',
            'pl', 'pr', 'sc', 'sk', 'sl', 'sm', 'sn', 'sp', 'st', 'sw', 'tr', 'tw')
# Same spelling, different meaning: these may be taught twice on purpose.
POLYSEMOUS = {'orange', 'chicken', 'fit', 'patient', 'sink', 'wave', 'iron'}
notes = []
COLORS = ['red', 'blue', 'green', 'yellow', 'pink', 'orange']
# Letter-sound lessons spread over the ten level-0 units, in phonics order.
LETTERS_PER_UNIT = [3, 3, 3, 3, 3, 3, 2, 2, 2, 2]
errors = []
warnings_ = []


def ipa_of(text):
    key = text.lower()
    if key in IPA_FIX:
        return '/' + IPA_FIX[key] + '/'
    out = []
    for word in re.findall(r"[a-z']+", key):
        if word in IPA_FIX:
            out.append(IPA_FIX[word]); continue
        cmu = CMU_IPA.get(word) or CMU_IPA.get(UK_US.get(word, ''))
        if cmu:
            out.append(cmu); continue
        s = eng_to_ipa.convert(word)
        if '*' in s:
            s = s.replace('*', '')
            if not s:
                continue
        if 'ˈ' in s:
            head, tail = s.split('ˈ', 1)
            m = re.search(r'[aeiouæɑɔəɛɪʊ]', tail)
            if m and tail[m.start()] == 'ə':
                tail = tail[:m.start()] + 'ʌ' + tail[m.start() + 1:]
            s = head + 'ˈ' + tail
        elif len(re.findall(r'[aeiouæɑɔəɛɪʊ]+', s)) == 1 and word not in ('a', 'the', 'of', 'was'):
            s = s.replace('ə', 'ʌ')
        out.append(s.replace('g', 'ɡ').replace('ʧ', 'tʃ').replace('ʤ', 'dʒ'))
    return '/' + ' '.join(out) + '/' if out else ''


def syllables_of(text):
    parts = []
    for word in text.split():
        n = eng_to_ipa.syllable_count(word) if re.fullmatch(r"[A-Za-z']+", word) else 1
        n = n if isinstance(n, int) and n > 0 else 1
        cut = HYPH.inserted(word).split('-') if n > 1 else [word]
        parts.extend(cut if len(cut) == n else [word])
    return parts


def phonics_of(word):
    w = word.lower()
    if re.fullmatch(r'[^aeiou\W][aeiou][^aeiouwy\W]', w):
        return 'cvc_short_' + w[1]
    if re.fullmatch(r'[a-z]+', w):
        return 'initial_' + w[0]
    return ''


def pron_focus(word, ipa):
    w = word.lower(); core = ipa.strip('/'); focus = []
    if re.search(r'[ptkbdɡfvszʃʒθðmnŋl]$', core) or core.endswith(('tʃ', 'dʒ')):
        focus.append('final_consonant')
    if 'θ' in core or 'ð' in core:
        focus.append('th_sound')
    if w.startswith(CLUSTERS):
        focus.append('cluster')
    if 'ʃ' in core:
        focus.append('sh_s')
    if w.startswith('r') or re.search(r'[^aeiou ]r[aeiou]', w):
        focus.append('r_sound')
    if w.startswith(('l', 'n')):
        focus.append('l_n')
    if len(syllables_of(word)) >= 2 and ' ' not in word:
        focus.append('stress')
    if re.search(r'[^s]s$', w) and len(w) > 3 and w not in ('bus', 'yes', 'this', 'his', 'is', 'us', 'was', 'has', 'does', 'glass', 'class', 'dress', 'grass'):
        focus.append('ending_s')
    if w.endswith('ed') and len(w) > 4:
        focus.append('ending_ed')
    return focus


def emoji_hex(raw):
    return '-'.join('%X' % ord(c) for c in raw)


def image_of(raw, where):
    raw = raw.strip()
    hint = raw.startswith('~')
    raw = raw.lstrip('~').strip()
    if raw.endswith('.svg'):
        if not os.path.exists(os.path.join(ROOT, 'assets', 'svg', raw)):
            errors.append(f'{where}: missing assets/svg/{raw}')
        return {'svg': raw}, not hint
    if not raw:
        errors.append(f'{where}: no picture')
    return {'emoji': emoji_hex(raw)}, not hint


def split(line):
    return [part.strip() for part in line.split(' | ')]


def parse(path, level):
    units = []; sounds = []; unit = None; dialogue = None; reading = None
    for number, line in enumerate(open(path, encoding='utf-8'), 1):
        line = line.rstrip('\n')
        if not line.strip() or line.startswith('#'):
            continue
        tag, _, rest = line.partition(' ')
        f = split(rest)
        where = f'{os.path.basename(path)}:{number}'
        try:
            if tag == '@U':
                unit = {'kind': 'topic', 'level': level, 'unit': int(f[0]), 'topic_en': f[1], 'topic_vi': f[2],
                        'can_do': [c.strip() for c in f[3].split(';') if c.strip()], 'words': [], 'patterns': [],
                        'dialogues': [], 'readings': [], 'grammar': '', 'starters': []}
                units.append(unit); dialogue = reading = None
            elif tag == '@S':
                unit = {'kind': 'sound', 'n': int(f[0]), 'letter': f[1], 'ipa': f[2], 'tip': f[3], 'words': []}
                sounds.append(unit); dialogue = reading = None
            elif tag == 'G':
                unit['grammar'] = rest.strip()
            elif tag == 'W':
                while len(f) < 5:
                    f.append('')
                image, picturable = image_of(f[2], where)
                unit['words'].append({'en': f[0], 'vi': f[1], 'image': image, 'picturable': picturable,
                                      'ex_en': f[3], 'ex_vi': f[4], 'where': where})
            elif tag == 'P':
                unit['patterns'].append({'en': f[0], 'vi': f[1],
                                         'values': [v.strip() for v in f[2].split(',')] if len(f) > 2 else []})
            elif tag == 'D':
                dialogue = {'title': f[0], 'roles': [r.strip() for r in f[1].split(',')],
                            'swaps': [s.strip() for s in f[2].split(',')] if len(f) > 2 else [], 'lines': []}
                unit['dialogues'].append(dialogue); reading = None
            elif tag == 'R':
                reading = {'title': rest.strip(), 'text': [], 'questions': []}
                unit['readings'].append(reading); dialogue = None
            elif tag == '>':
                if reading is not None:
                    reading['text'].extend(s.strip() for s in re.findall(r'[^.!?]+[.!?]+["”]?', rest) if s.strip())
                else:
                    role, _, text = rest.partition(':')
                    en, _, vi = text.partition(' | ')
                    dialogue['lines'].append({'role': role.strip(), 'en': en.strip(), 'vi': vi.strip()})
            elif tag == '?':
                reading['questions'].append({'q': f[0], 'options': f[1:], 'answer': f[1]})
            elif tag == 'S':
                unit['starters'] = f
            else:
                errors.append(f'{where}: unknown tag {tag}')
        except Exception as exc:  # malformed line
            errors.append(f'{where}: {exc}')
    return units, sounds


def word_item(uid, index, w, level):
    ipa = ipa_of(w['en'])
    plain = bool(re.fullmatch(r"[A-Za-z]+", w['en']))
    skills = ['listen', 'speak']
    if level >= 1:
        skills.append('read')
    if (level == 1 and plain and len(w['en']) <= 6) or level >= 2:
        skills.append('write')
    item = {'id': f'{uid}-W{index:02d}', 'type': 'phrase' if ' ' in w['en'] else 'word', 'en': w['en'],
            'vi': w['vi'], 'ipa': ipa, 'syllables': syllables_of(w['en']), 'phonics': phonics_of(w['en']),
            'image': w['image'], 'picturable': w['picturable'], 'cat': uid,
            'example_en': w['ex_en'], 'example_vi': w['ex_vi'], 'pron_focus': pron_focus(w['en'], ipa),
            'skills': skills}
    return item


DET = {'a', 'an', 'the', 'my', 'your', 'his', 'her', 'our', 'their', 'this', 'that', 'these',
       'those', 'some', 'any', 'many', 'much', 'no', 'of', 'two', 'three', 'four', 'five'}
ADJ_CUE = {'is', 'are', 'was', 'were', 'am', 'be', 'very', 'so', 'too', 'quite', 'really', 'feel',
           'feels', 'felt', 'look', 'looks', 'become', 'stay', 'more', 'most', 'and'}
VERB_CUE = {'to', 'can', 'will', "don't", "let's", 'please', 'i', 'you', 'we', 'they', 'must',
            'should', 'might', 'could', "can't", 'not', "didn't", "doesn't"}


def guess_pos(word, sentence):
    """Rough part of speech of [word] from the word before it in [sentence]:
    noun after a determiner, adjective after be/very, verb after to/can or
    at the start of a command. None when there is no clear cue."""
    tokens = re.findall(r"[a-z']+", sentence.lower())
    target = word.lower()
    for i, t in enumerate(tokens):
        if t == target or (t.startswith(target) and len(t) - len(target) <= 3):
            prev = tokens[i - 1] if i > 0 else ''
            if prev in DET:
                return 'noun'
            if prev in ADJ_CUE:
                return 'adj'
            if prev in VERB_CUE or i == 0:
                return 'verb'
            return None
    return None


def build_unit(u, sounds, known_items, rng):
    level = u['level']
    uid = f"L{level}U{u['unit']:02d}"
    items = []
    topic_words = list(u['words'])
    counter = [0]
    taught = {k['en'].lower() for k in known_items}

    def add_word(w):
        # A word already taught in an earlier unit stays usable in sentences
        # but does not become a second "new" card (spiral review happens
        # through Leitner instead). Words spelled the same with another
        # meaning are listed in POLYSEMOUS.
        key = w['en'].lower()
        if key in taught and key not in POLYSEMOUS:
            notes.append(f"{uid}: \"{w['en']}\" was taught earlier, not repeated as a new item")
            return
        taught.add(key)
        counter[0] += 1
        items.append(word_item(uid, counter[0], w, level))

    # Level 0: letter-sound lessons interleaved with the topic words.
    for li, s in enumerate(sounds):
        for _ in range(3):
            if topic_words:
                add_word(topic_words.pop(0))
        items.append({'id': f'{uid}-L{li + 1:02d}', 'type': 'letter', 'en': s['letter'], 'vi': f"chữ {s['letter']}",
                      'letter': s['letter'], 'sound': s['ipa'], 'tip_vi': s['tip'],
                      'sound_words': [w['en'] for w in s['words']],
                      'image': s['words'][0]['image'] if s['words'] else {'emoji': '1F41D'},
                      'picturable': False, 'cat': 'letter', 'ipa': s['ipa'], 'syllables': [s['letter']],
                      'phonics': 'sound_' + s['letter'], 'example_en': '', 'example_vi': s['tip'],
                      'pron_focus': [], 'skills': ['listen', 'speak', 'read', 'write']})
        for w in s['words']:
            add_word(w)
    for w in topic_words:
        add_word(w)

    words = [it for it in items if it['type'] != 'letter']
    letters = [it for it in items if it['type'] == 'letter']
    pictures = {}
    for it in words:
        if not it['picturable']:
            continue
        key = json.dumps(it['image'], sort_keys=True)
        if key in pictures:
            errors.append(f"{uid}: \"{it['en']}\" and \"{pictures[key]}\" use the same picture")
        pictures[key] = it['en']

    patterns = [{'id': f'{uid}-P{i:02d}', 'en': p['en'], 'vi': p['vi'],
                 'slots': {'x': p['values']} if p['values'] and '{x}' in p['en'] else {}}
                for i, p in enumerate(u['patterns'], 1)]
    dialogues = []
    for i, d in enumerate(u['dialogues'], 1):
        entry = {'id': f'{uid}-D{i:02d}', 'title_vi': d['title'], 'roles': d['roles'], 'lines': d['lines']}
        if d['swaps']:
            key, options = d['swaps'][0], d['swaps'][1:]
            kid_role = 'Kid' if 'Kid' in d['roles'] else next((r for r in d['roles'] if r != 'Bi'), d['roles'][-1])
            line_index = None
            for li, line in enumerate(d['lines']):
                if re.search(r'\b' + re.escape(key) + r'\b', line['en'], re.I) and line['role'] == kid_role:
                    line_index = li; break
            if line_index is None:
                for li, line in enumerate(d['lines']):
                    if re.search(r'\b' + re.escape(key) + r'\b', line['en'], re.I):
                        line_index = li; break
            if line_index is None:
                errors.append(f"{uid}-D{i:02d}: swap keyword \"{key}\" is not in any line")
            elif options:
                entry['variation'] = {'line': line_index, 'key': key, 'options': options}
        dialogues.append(entry)
    readings = [{'id': f'{uid}-R{i:02d}', 'title_en': r['title'], 'text_en': r['text'], 'questions': r['questions']}
                for i, r in enumerate(u['readings'], 1)]

    # Writing tasks follow the level: trace, copy, dictation, then guided writing.
    writing = []
    if level == 0:
        seen = []
        for it in letters:
            for c in (it['letter'].upper(), it['letter'].lower()):
                if c not in seen:
                    seen.append(c)
        for w in words:
            c = w['en'][0].lower()
            if c.isalpha() and c not in seen and c.upper() not in seen:
                seen.append(c)
        writing = [{'type': 'trace_letter', 'target': c} for c in seen[:10]]
    else:
        short = [w for w in words if 'write' in w['skills'] and re.fullmatch(r'[A-Za-z]+', w['en'])]
        if level == 1:
            firsts = []
            for w in words:
                c = w['en'][0].lower()
                if c.isalpha() and c not in firsts:
                    firsts.append(c)
            writing += [{'type': 'write_letter', 'target': c} for c in firsts[:4]]
            writing += [{'type': 'copy_word', 'target': w['en'].lower()} for w in short[:8]]
        else:
            writing += [{'type': 'dictate_word', 'target': w['en']} for w in short[:8]]
            writing += [{'type': 'dictate_sentence', 'target': w['example_en']} for w in words
                        if w['example_en'] and len(w['example_en'].split()) <= 7][:3]
        if level >= 3:
            starters = u['starters'] or [p['en'].split('{')[0].strip() for p in patterns if '{' in p['en']][:3]
            starters = [s for s in starters if s] or ['I like', 'I can', 'My friend']
            writing.append({'type': 'write_sentences', 'target': '|'.join(starters)})

    # Quiz bank: generated from the unit's own material, at least 30 questions.
    quiz = []
    pic_words = [w for w in words if w['picturable']]
    pool = pic_words + [k for k in known_items if k['picturable'] and k['en'].lower() not in {w['en'].lower() for w in words}]

    def options(answer, count):
        same = [p['en'] for p in pic_words if p['en'].lower() != answer['en'].lower()]
        rng.shuffle(same)
        others = [p['en'] for p in pool if p['en'].lower() != answer['en'].lower() and p['en'] not in same]
        rng.shuffle(others)
        picked = []
        for o in same + others:
            if o.lower() not in (x.lower() for x in picked):
                picked.append(o)
            if len(picked) == count - 1:
                break
        opts = [answer['en']] + picked
        rng.shuffle(opts)
        return opts

    def add(skill, kind, **extra):
        quiz.append({'id': f'{uid}-Q{len(quiz) + 1:03d}', 'skill': skill, 'kind': kind, **extra})

    n_opts = 3 if level == 0 else 4
    if len(pool) >= 3:
        for w in pic_words:
            add('listen', 'pick_image', audio_en=w['en'], item=w['en'], options=options(w, n_opts), answer=w['en'])
        if level <= 1:
            for w in pic_words[:4]:
                color = rng.choice(COLORS)
                add('listen', 'color_item', audio_en=f"Color the {w['en']} {color}.", item=w['en'],
                    options=options(w, 3), answer=w['en'], color=color)
    if level >= 2:
        # Abstract words have no picture: hear the word, pick its meaning.
        def meanings(v):
            return {s.strip().lower() for s in re.split(r'[,;()]', v) if s.strip()}
        for w in words:
            if w['picturable']:
                continue
            others = [x for x in words if x['en'].lower() != w['en'].lower()
                      and not (meanings(x['vi']) & meanings(w['vi']))]
            rng.shuffle(others)
            if len(others) >= 2:
                opts = [w['en']] + [x['en'] for x in others[:3]]
                rng.shuffle(opts)
                add('listen', 'pick_meaning', audio_en=w['en'], item=w['en'], options=opts, answer=w['en'])
    for w in pic_words:
        add('speak', 'say_word', item=w['en'], answer=w['en'])
    for w in words:
        if w['example_en'] and len(w['example_en'].split()) <= (8 if level <= 2 else 12):
            add('speak', 'repeat_sentence', audio_en=w['example_en'], item=w['en'], answer=w['example_en'])
    for p in patterns:
        for value in p['slots'].get('x', [])[:3]:
            sentence = p['en'].replace('{x}', value)
            add('speak', 'repeat_sentence', audio_en=sentence, answer=sentence)
    for d in dialogues:
        lines = d['lines']
        for a, b in zip(lines, lines[1:]):
            if a['en'].endswith('?') and a['role'] != b['role']:
                add('speak', 'answer_question', audio_en=a['en'], answer=b['en'])
    for it in letters:
        others = [x['letter'] for x in letters if x['letter'] != it['letter']] + list('stpnmdgbfl')
        others = [o for o in dict.fromkeys(others) if o != it['letter']]
        rng.shuffle(others)
        opts = [it['letter']] + others[:2]
        rng.shuffle(opts)
        add('read', 'letter_sound', item=it['en'], options=opts, answer=it['letter'])
    if level >= 1 and len(pool) >= 3:
        for w in pic_words:
            add('read', 'pick_word', item=w['en'], options=options(w, 3), answer=w['en'])
    if level >= 2:
        for w in words:
            ex = w['example_en']
            m = re.search(r'\b' + re.escape(w['en']) + r'(s|es|ed|d|ing)?\b', ex, re.I) if ex and ' ' not in w['en'] else None
            # Proper nouns (January, Vietnam, Mars...) are skipped: their capital
            # letter would give the answer away, and others of the set also fit.
            if m and w['en'][:1].isupper():
                m = None
            if m:
                # Distractors must not also fit: skip words of the same set
                # (same picture or hint, e.g. months, numbers, directions) and
                # words sharing a meaning (amazing / brilliant).
                def gloss(v):
                    return {g.strip().lower() for g in re.split(r'[,;()]', v) if g.strip()}
                answer_pos = guess_pos(w['en'], ex)
                same_type = [x for x in words if x['en'] != w['en'] and ' ' not in x['en']
                             and x['image'] != w['image'] and not (gloss(x['vi']) & gloss(w['vi']))
                             and x['en'].lower() not in ex.lower()
                             and (answer_pos is None or guess_pos(x['en'], x['example_en'] or '') != answer_pos)]
                rng.shuffle(same_type)
                suffix = (m.group(1) or '').lower()
                if suffix in ('s', 'es'):
                    # A plural blank is a noun: pictured words are nouns far more often.
                    same_type.sort(key=lambda x: not x['picturable'])
                same_type = [x for x in same_type if not x['en'][:1].isupper()]
                if len(same_type) >= 2:
                    def inflect(word):
                        # Give distractors the same ending as the answer so the
                        # form of the word does not give the answer away.
                        if not suffix:
                            return word
                        if suffix in ('s', 'es'):
                            return word + ('es' if re.search(r'(s|x|z|ch|sh)$', word) else 's')
                        if suffix in ('ed', 'd'):
                            return word + ('d' if word.endswith('e') else 'ed')
                        if suffix == 'ing':
                            return (word[:-1] if word.endswith('e') and not word.endswith('ee') else word) + 'ing'
                        return word
                    opts = [m.group(0)] + [inflect(x['en']) for x in same_type[:2]]
                    if m.start() == 0 or not ex[:m.start()].strip(' "\''):
                        # Sentence start: every option gets a capital letter.
                        opts = [o[:1].upper() + o[1:] for o in opts]
                    if len({o.lower() for o in opts}) == len(opts):
                        rng.shuffle(opts)
                        add('read', 'fill_blank', text_en=ex[:m.start()] + '___' + ex[m.end():], item=w['en'],
                            options=opts, answer=m.group(0))
        for i, w in enumerate(pic_words):
            if not w['example_en'] or len(pic_words) < 2:
                continue
            truth = i % 2 == 0
            shown = w if truth else pic_words[(i + 1) % len(pic_words)]
            add('read', 'true_false', text_en=w['example_en'], item=shown['en'], options=['true', 'false'],
                answer='true' if truth else 'false')
    for r in readings:
        for q in r['questions']:
            opts = list(q['options']); rng.shuffle(opts)
            add('read', 'read_question', reading=r['id'], text_en=q['q'], options=opts, answer=q['answer'])
    for t in writing:
        kind = t['type']
        if kind == 'trace_letter':
            add('write', 'trace_letter', answer=t['target'])
        elif kind == 'write_letter':
            add('write', 'write_letter', audio_en=t['target'], answer=t['target'])
        elif kind == 'copy_word':
            add('write', 'copy_word', item=t['target'], answer=t['target'])
        elif kind == 'dictate_word':
            add('write', 'dictate_word', audio_en=t['target'], item=t['target'], answer=t['target'])
        elif kind == 'dictate_sentence':
            add('write', 'dictate_sentence', audio_en=t['target'], answer=t['target'])
    if len(quiz) < 30:
        errors.append(f'{uid}: only {len(quiz)} quiz questions (need 30)')

    doc = {'id': uid, 'level': level, 'unit': u['unit'], 'topic_en': u['topic_en'], 'topic_vi': u['topic_vi'],
           'can_do_vi': u['can_do']}
    if u['grammar']:
        doc['grammar_note_vi'] = u['grammar']
    doc.update(items=items, patterns=patterns, dialogues=dialogues, writing=writing)
    if readings:
        doc['readings'] = readings
    doc['quiz_bank'] = quiz
    return uid, doc, words


def main():
    rng = random.Random(20261110)
    known = []
    index = []
    total_words = 0
    for path in sorted(glob.glob(os.path.join(SRC, 'L*.txt'))):
        level = int(re.search(r'L(\d)', os.path.basename(path)).group(1))
        out_dir = os.path.join(OUT, f'level_{level}')
        os.makedirs(out_dir, exist_ok=True)
        for old in glob.glob(os.path.join(out_dir, '*.json')):
            os.remove(old)
        units, sounds = parse(path, level)
        units.sort(key=lambda u: u['unit'])
        sounds.sort(key=lambda s: s['n'])
        if sounds and level != 0:
            errors.append(f'L{level}: letter sounds (@S) belong to level 0')
        cursor = 0
        for ui, u in enumerate(units):
            take = LETTERS_PER_UNIT[ui] if level == 0 and ui < len(LETTERS_PER_UNIT) else 0
            unit_sounds = sounds[cursor:cursor + take]
            cursor += take
            uid, doc, words = build_unit(u, unit_sounds, known, rng)
            known.extend(words)
            total_words += len(words)
            name = uid + '.json'
            with open(os.path.join(out_dir, name), 'w', encoding='utf-8') as fh:
                json.dump(doc, fh, ensure_ascii=False, indent=1)
            index.append(f'level_{level}/{name}')
        if level == 0 and cursor < len(sounds):
            errors.append(f'L0: {len(sounds) - cursor} letter sounds were not placed in a unit')
    with open(os.path.join(OUT, 'index.json'), 'w', encoding='utf-8') as fh:
        json.dump({'version': 1, 'units': index}, fh, ensure_ascii=False, indent=1)
    try:
        from fontTools.ttLib import TTFont
        cmap = TTFont(os.path.join(ROOT, 'assets', 'fonts', 'NotoColorEmoji-Regular.ttf')).getBestCmap()
        for item in known:
            for part in item['image'].get('emoji', '').split('-'):
                if part and int(part, 16) not in (0x200D, 0xFE0F, 0x20E3) and int(part, 16) not in cmap:
                    errors.append(f"emoji U+{part} of \"{item['en']}\" is not in Noto Color Emoji")
    except ImportError:
        pass
    if '-v' in sys.argv:
        for n in notes:
            print('NOTE ', n)
    elif notes:
        print(f'{len(notes)} repeated word(s) skipped (run with -v to list them)')
    for e in errors:
        print('ERROR', e)
    print(f'build_curriculum: {len(index)} unit file(s), {total_words} word item(s), {len(errors)} error(s)')
    sys.exit(1 if errors else 0)


if __name__ == '__main__':
    main()
