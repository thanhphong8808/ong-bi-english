#!/usr/bin/env python3
# tool/word_art/build.py
#
# Prompt pack for the vocabulary pictures (docs/WORD_ART.md + prompts.json).
# One picture per English word or phrase that the curriculum marks as
# picturable; the app looks for assets/word_art/<slug>.webp and falls back to
# the emoji when the file is missing.
#
# Two ways to draw them:
#   - one picture per word: <slug>.png
#   - a "sheet" of nine words in a 3x3 grid: word_sheet_<NNN>.png (square,
#     2K), which import_art.py cuts into nine pictures (nine times fewer
#     generations).
#
#   python3 tool/word_art/build.py
import glob
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

STYLE = (
    "Soft 3D animated picture-book look: rounded, toy-like shapes, big friendly eyes on any person or animal, "
    "honey-gold and soft pastel colours, gentle soft shadows, warm light, plain very light cream background, "
    "safe and cheerful for a 6-year-old. No text, no letters, no numbers, no logos."
)
NEGATIVE = (
    "text, letters, words, numbers, captions, labels, watermark, logo, signature, scary, horror, blood, "
    "injury, weapons, realistic photo, dark gloomy lighting, extra limbs, deformed hands, cluttered background, "
    "several unrelated objects"
)
SHEET = 9
GRID = 3


def slug(en):
    return re.sub(r'^_+|_+$', '', re.sub(r'[^a-z0-9]+', '_', en.lower()))


def subject(w):
    s = f'{w["en"]} (Vietnamese: {w["vi"]})'
    if w['example']:
        s += f', as in "{w["example"]}"'
    return s


def words():
    seen, out = set(), []
    for path in sorted(glob.glob(os.path.join(ROOT, 'assets', 'curriculum', 'level_*', '*.json'))):
        unit = json.load(open(path, encoding='utf-8'))
        for it in unit.get('items', []):
            if it.get('type') not in ('word', 'phrase') or not it.get('picturable', True):
                continue
            key = slug(it['en'])
            if not key or key in seen:
                continue
            seen.add(key)
            out.append({
                'slug': key,
                'en': it['en'],
                'vi': it.get('vi', ''),
                'example': it.get('example_en', ''),
                'level': unit.get('level', 0),
                'unit': unit.get('id', ''),
            })
    return out


def main():
    ws = words()
    entries = []
    for w in ws:
        entries.append({
            'file': f'{w["slug"]}.png',
            'kind': 'word',
            'level': w['level'],
            'unit': w['unit'],
            'en': w['en'],
            'vi': w['vi'],
            'prompt': (
                f'Picture card for a children\'s vocabulary app. Show: {subject(w)}. '
                f'One clear, instantly recognisable subject that a 6-year-old would name "{w["en"]}", '
                f'large and centred, filling most of the frame. {STYLE} Square 1:1.'
            ),
            'negative': NEGATIVE,
        })
    sheets = []
    for i in range(0, len(ws), SHEET):
        group = ws[i:i + SHEET]
        while len(group) < SHEET:
            group = group + [group[-1]]
        cells = [f'row {r + 1} {c}' for r in range(GRID) for c in ('left', 'middle', 'right')]
        parts = '; '.join(f'{c}: {subject(w)}' for c, w in zip(cells, group))
        sheets.append({
            'file': f'word_sheet_{len(sheets) + 1:03d}.png',
            'kind': 'sheet',
            'words': [w['slug'] for w in group],
            'prompt': (
                'A 3x3 grid of nine separate square picture cards for a children\'s vocabulary app, equal size, '
                'thin even cream gaps between them, nothing crossing from one card into another. '
                f'Each card shows one clear subject, large and centred. {parts}. {STYLE} Square 1:1 overall.'
            ),
            'negative': NEGATIVE + ', overlapping cards, grid lines through subjects',
        })
    with open(os.path.join(HERE, 'prompts.json'), 'w', encoding='utf-8') as f:
        json.dump(entries + sheets, f, ensure_ascii=False, indent=1)

    md = [
        '# Ảnh minh hoạ từ vựng: bộ prompt cho cinai.tv',
        '',
        f'{len(ws)} từ/cụm từ có thể vẽ được (các từ trừu tượng vẫn dùng emoji). App tự dùng ảnh khi có file '
        '`assets/word_art/<tên>.webp`, chưa có thì hiện emoji như cũ.',
        '',
        '## Cách tạo',
        '',
        '- **Cách 1, mỗi từ một ảnh:** dùng prompt ở bảng "Từng từ", ảnh vuông 1:1, đặt tên `<tên>.png`.',
        f'- **Cách 2, bảng 9 từ (ít lần tạo hơn 9 lần):** dùng prompt ở bảng "Bảng 9 từ", ảnh vuông 1:1, 2K, '
        f'đặt tên `word_sheet_NNN.png`. Lệnh nhập ảnh tự cắt lưới 3×3 thành 9 ảnh, đọc từ trái sang phải, '
        f'từ trên xuống dưới. Ảnh nào hỏng thì vẽ lại riêng từ đó theo cách 1 (file riêng được ưu tiên).',
        '- Nhập vào app: `python3 tool/word_art/import_art.py <thư mục ảnh>` (nén WebP 448 px vào `assets/word_art/`).',
        '',
        f'**Phong cách (đã có trong mỗi prompt):** {STYLE}',
        '',
        f'**Negative prompt:** {NEGATIVE}',
        '',
        '## Bảng 9 từ',
        '',
        '| File | Từ | Prompt |',
        '|---|---|---|',
    ]
    for s in sheets:
        md.append(f'| `{s["file"]}` | {", ".join(s["words"])} | {s["prompt"]} |')
    md += ['', '## Từng từ', '', '| File | Cấp | Từ | Nghĩa | Prompt |', '|---|---|---|---|---|']
    for e in entries:
        md.append(f'| `{e["file"]}` | {e["level"]} | {e["en"]} | {e["vi"]} | {e["prompt"]} |')
    with open(os.path.join(ROOT, 'docs', 'WORD_ART.md'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(md) + '\n')
    print(f'{len(entries)} words, {len(sheets)} sheets')


if __name__ == '__main__':
    main()
