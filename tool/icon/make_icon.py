#!/usr/bin/env python3
# tool/icon/make_icon.py
#
# Turns one square picture of Bi (the 3D app icon, made on cinai.tv from
# tool/icon/PROMPT.txt) into the Android adaptive-icon foreground:
# android/app/src/main/res/mipmap-*/ic_launcher_foreground.png.
#
# A launcher shows only the middle 72 of the 108 dp foreground (round,
# squircle or rounded-square mask), so the picture is placed at 74 dp in the
# middle (a little low, for the antennae) and the edge around it is the
# picture's own background, mirrored, so there is no seam. The vector bee
# stays as the monochrome layer for Android 13 themed icons.
#
#   python3 tool/icon/make_icon.py <picture.png> [preview.png]
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
DENSITIES = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0}
INNER = 74 / 108  # share of the foreground the picture covers
DROP = 3 / 108  # moves Bi down a little, so the antennae stay inside a round mask


def foreground(src, side):
    w, h = src.size
    s = min(w, h)
    square = src.crop(((w - s) // 2, (h - s) // 2, (w - s) // 2 + s, (h - s) // 2 + s)).convert('RGB')
    inner = round(side * INNER)
    picture = np.asarray(square.resize((inner, inner), Image.LANCZOS))
    left = (side - inner) // 2
    top = left + round(side * DROP)
    padded = np.pad(picture, ((top, side - inner - top), (left, side - inner - left), (0, 0)), mode='reflect')
    return Image.fromarray(padded)


def preview(fg, path):
    """The icon as launchers show it: circle, squircle and rounded square."""
    side = fg.size[0]
    visible = round(side * 72 / 108)
    cut = fg.crop(((side - visible) // 2,) * 2 + ((side + visible) // 2,) * 2)
    out = Image.new('RGB', (visible * 3 + 80, visible + 40), (240, 240, 240))
    for i, shape in enumerate(('circle', 'squircle', 'rounded')):
        mask = Image.new('L', (visible, visible), 0)
        d = ImageDraw.Draw(mask)
        if shape == 'circle':
            d.ellipse((0, 0, visible - 1, visible - 1), fill=255)
        else:
            r = visible * (0.42 if shape == 'squircle' else 0.22)
            d.rounded_rectangle((0, 0, visible - 1, visible - 1), radius=r, fill=255)
        out.paste(cut, (20 + i * (visible + 20), 20), mask)
    out.save(path)


def main(src_path, preview_path=None):
    src = Image.open(src_path)
    for name, scale in DENSITIES.items():
        side = round(108 * scale)
        folder = os.path.join(RES, f'mipmap-{name}')
        os.makedirs(folder, exist_ok=True)
        foreground(src, side).save(os.path.join(folder, 'ic_launcher_foreground.png'), optimize=True)
    if preview_path:
        preview(foreground(src, 432), preview_path)
    print('icon written for', ', '.join(DENSITIES))


if __name__ == '__main__':
    if len(sys.argv) not in (2, 3):
        raise SystemExit('usage: python3 tool/icon/make_icon.py <picture.png> [preview.png]')
    main(*sys.argv[1:])
