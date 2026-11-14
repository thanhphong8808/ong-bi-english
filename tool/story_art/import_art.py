#!/usr/bin/env python3
# tool/story_art/import_art.py
#
# Brings generated pictures into the app:
#   <story>_<NN>.png|jpg|webp  -> assets/story_art/<story>_<NN>.webp (16:10, 1280x800)
# Other files (character sheets) are skipped. Bi pictures (bi_*) go through import_bi.py,
# which keys out their green background.
#
#   python3 tool/story_art/import_art.py <folder with pictures>
import json
import os
import re
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
STORY_OUT = os.path.join(ROOT, 'assets', 'story_art')
WANTED = {i['file'].rsplit('.', 1)[0] for i in json.load(open(os.path.join(HERE, 'prompts.json'), encoding='utf-8'))}


def crop_16_10(im):
    w, h = im.size
    target = 16 / 10
    if w / h > target:
        nw = int(h * target)
        left = (w - nw) // 2
        return im.crop((left, 0, left + nw, h))
    nh = int(w / target)
    top = (h - nh) // 2
    return im.crop((0, top, w, top + nh))


def main(folder):
    os.makedirs(STORY_OUT, exist_ok=True)
    done, skipped = 0, []
    for name in sorted(os.listdir(folder)):
        stem, ext = os.path.splitext(name)
        if ext.lower() not in ('.png', '.jpg', '.jpeg', '.webp'):
            continue
        stem = stem.strip().lower()
        if stem not in WANTED or stem.endswith('_cast') or stem.startswith('bi_'):
            skipped.append(name)
            continue
        im = Image.open(os.path.join(folder, name))
        im = crop_16_10(im.convert('RGB')).resize((1280, 800), Image.LANCZOS)
        im.save(os.path.join(STORY_OUT, stem + '.webp'), 'WEBP', quality=80, method=6)
        done += 1
    print(f'imported {done} pictures')
    if skipped:
        print('skipped (name not in the prompt pack):', ', '.join(skipped))
    have = {f.rsplit('.', 1)[0] for f in os.listdir(STORY_OUT) if f.endswith('.webp')}
    missing = sorted(w for w in WANTED if re.match(r'.+_\d\d$', w) and w not in have)
    print(f'story pictures still missing: {len(missing)}')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    main(sys.argv[1])
