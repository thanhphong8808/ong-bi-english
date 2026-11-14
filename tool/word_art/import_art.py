#!/usr/bin/env python3
# tool/word_art/import_art.py
#
# Brings vocabulary pictures into the app:
#   <slug>.png|jpg|webp          -> assets/word_art/<slug>.webp (square, 448 px)
#   word_sheet_<NNN>.png|jpg|webp -> cut into the sheet's words (2x2 or 3x3 grid)
# A picture made for one word wins over the same word cut from a sheet.
#
#   python3 tool/word_art/import_art.py <folder with pictures>
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, 'assets', 'word_art')
SIDE = 448
PACK = json.load(open(os.path.join(HERE, 'prompts.json'), encoding='utf-8'))
WORDS = {e['file'].rsplit('.', 1)[0] for e in PACK if e['kind'] == 'word'}
SHEETS = {e['file'].rsplit('.', 1)[0]: e['words'] for e in PACK if e['kind'] == 'sheet'}
# Number words keep their keycap emoji: generated pictures often show the
# wrong count, and a child learning to count must see the right number.
SKIP = {'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve',
        'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen', 'twenty'}


def square(im):
    w, h = im.size
    s = min(w, h)
    return im.crop(((w - s) // 2, (h - s) // 2, (w - s) // 2 + s, (h - s) // 2 + s))


def save(im, stem):
    im = square(im.convert('RGB')).resize((SIDE, SIDE), Image.LANCZOS)
    im.save(os.path.join(OUT, stem + '.webp'), 'WEBP', quality=80, method=6)


def cells(im, n):
    """The cards of an n x n sheet, row by row, trimmed a little to drop the gaps."""
    im = square(im.convert('RGB'))
    s = im.size[0]
    pad = s // (20 * n)
    for r in range(n):
        for c in range(n):
            left, top = s * c // n, s * r // n
            right, bottom = s * (c + 1) // n, s * (r + 1) // n
            yield im.crop((left + pad, top + pad, right - pad, bottom - pad))


def main(folder):
    os.makedirs(OUT, exist_ok=True)
    files = sorted(f for f in os.listdir(folder) if os.path.splitext(f)[1].lower() in ('.png', '.jpg', '.jpeg', '.webp'))
    singles = {os.path.splitext(f)[0].strip().lower(): f for f in files}
    done, skipped = 0, []
    for stem, name in singles.items():
        if stem in SHEETS:
            n = round(len(SHEETS[stem]) ** 0.5)
            for word, cell in zip(SHEETS[stem], cells(Image.open(os.path.join(folder, name)), n)):
                if word not in singles and word not in SKIP:
                    save(cell, word)
                    done += 1
        elif stem in WORDS:
            save(Image.open(os.path.join(folder, name)), stem)
            done += 1
        else:
            skipped.append(name)
    print(f'imported {done} word pictures')
    if skipped:
        print('skipped (name not in the prompt pack):', ', '.join(skipped))
    have = {f.rsplit('.', 1)[0] for f in os.listdir(OUT) if f.endswith('.webp')}
    for word in SKIP & have:
        os.remove(os.path.join(OUT, word + '.webp'))
    have -= SKIP
    print(f'word pictures still missing: {len(WORDS - have - SKIP)} of {len(WORDS - SKIP)}')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    main(sys.argv[1])
