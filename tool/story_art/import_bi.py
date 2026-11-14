#!/usr/bin/env python3
# tool/story_art/import_bi.py
#
# Brings the 3D Bi pictures into the app. Each picture is drawn on a plain
# pure green (#00FF00) background; this script keys the green out (soft edge,
# green spill removed), trims, centres on a square and saves
# assets/bi3d/<name>.webp (768 px, transparent).
#
# Names: bi_<mood>.png (no outfit) and bi_<mood>_<level>.png (wearing the
# outfit of that level, see biOutfits in lib/widgets/bi_mascot.dart).
#
#   python3 tool/story_art/import_bi.py <folder with pictures>
import os
import re
import sys

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), 'assets', 'bi3d')
MOODS = ('happy', 'listening', 'thinking', 'cheering', 'sleeping')
NAME = re.compile(r'^bi_(%s)(_[1-5])?$' % '|'.join(MOODS))
SIDE = 768


def key_out(path):
    rgb = np.asarray(Image.open(path).convert('RGB')).astype(np.float32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    rb = np.maximum(r, b)
    alpha = np.clip(1.0 - (g - rb - 40.0) / 110.0, 0.0, 1.0)
    alpha_img = Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))
    g = np.where(g > rb, rb + (g - rb) * 0.25, g)
    img = Image.fromarray(np.dstack([r, g, b, np.asarray(alpha_img)]).clip(0, 255).astype(np.uint8), 'RGBA')
    box = img.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox()
    if box:
        x0, y0, x1, y1 = box
        side = max(x1 - x0, y1 - y0) + 48
        square = Image.new('RGBA', (side, side), (0, 0, 0, 0))
        square.paste(img.crop(box), ((side - (x1 - x0)) // 2, (side - (y1 - y0)) // 2))
        img = square
    return img.resize((SIDE, SIDE), Image.LANCZOS)


def main(folder):
    os.makedirs(OUT, exist_ok=True)
    done = []
    for name in sorted(os.listdir(folder)):
        stem, ext = os.path.splitext(name)
        if ext.lower() in ('.png', '.jpg', '.jpeg', '.webp') and NAME.match(stem.lower()):
            key_out(os.path.join(folder, name)).save(os.path.join(OUT, stem.lower() + '.webp'), 'WEBP',
                                                     quality=88, method=6)
            done.append(stem.lower())
    print(f'imported {len(done)} Bi pictures: {" ".join(done)}')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: python3 tool/story_art/import_bi.py <folder with pictures>')
    main(sys.argv[1])
