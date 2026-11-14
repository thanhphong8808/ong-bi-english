#!/usr/bin/env python3
# tool/story_art/build.py
#
# Writes the "scene: N" lines into assets/talk/stories.txt and the prompt
# pack (docs/STORY_ART.md, tool/story_art/prompts.json) from scenes.py.
# Safe to run again: old scene lines are replaced.
#
#   python3 tool/story_art/build.py
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import scenes as S  # noqa: E402

STORIES = os.path.join(ROOT, 'assets', 'talk', 'stories.txt')


def english(line):
    body = line.split(':', 1)[1] if ':' in line else line
    return body.split('|', 1)[0].strip()


def place_scenes(text):
    lines = [l for l in text.split('\n') if not l.strip().startswith('scene:')]
    out = []
    i = 0
    story_ids = []
    # Split into stories.
    starts = [k for k, l in enumerate(lines) if l.startswith('=== story ')]
    starts.append(len(lines))
    out.extend(lines[:starts[0]])
    for a, b in zip(starts, starts[1:]):
        chunk = lines[a:b]
        sid = chunk[0].split()[2]
        story_ids.append(sid)
        spec = S.STORIES.get(sid)
        if spec is None:
            raise SystemExit(f'no scenes for story {sid}')
        inserts = {}  # index in chunk -> list of scene numbers
        for n, block, anchor, _ in spec['scenes']:
            if block is None:
                continue
            try:
                head = chunk.index(f'[{block}]')
            except ValueError:
                raise SystemExit(f'{sid}: no block [{block}]')
            end = next((k for k in range(head + 1, len(chunk)) if chunk[k].startswith('[')), len(chunk))
            if anchor is None:
                at = head + 1
            else:
                at = next((k for k in range(head + 1, end)
                           if re.match(r'^[a-z_0-9]+:', chunk[k]) and not chunk[k].startswith(('pic:', 'scene:'))
                           and anchor in english(chunk[k])), None)
                if at is None:
                    raise SystemExit(f'{sid} [{block}]: no line with "{anchor}"')
            inserts.setdefault(at, []).append(n)
        for k, l in enumerate(chunk):
            for n in inserts.get(k, []):
                out.append(f'scene: {n}')
            out.append(l)
    missing = set(S.STORIES) - set(story_ids)
    if missing:
        raise SystemExit(f'scenes for unknown stories: {sorted(missing)}')
    return '\n'.join(out), story_ids


def prompt(sid, scene_text):
    cast = '; '.join(f'{name}: {desc}' for name, desc in S.STORIES[sid]['cast'].items())
    return f'{scene_text}. Characters (keep them the same in every picture of this story): {cast}. {S.STYLE}'


def main():
    text = open(STORIES, encoding='utf-8').read()
    new, ids = place_scenes(text)
    if new != text:
        open(STORIES, 'w', encoding='utf-8').write(new)
    items = []
    md = [
        '# Tranh minh hoạ truyện: bộ prompt cho cinai.tv',
        '',
        'Mỗi truyện có 1 ảnh bìa (`_00`) và 4–6 cảnh. Ảnh đổi theo từng đoạn khi Bi kể.',
        '',
        '## Cách tạo',
        '',
        '1. Tạo trước **ảnh bìa** (`_00`) của từng truyện, rồi dùng nó làm ảnh tham chiếu (trên cinai.tv: nút',
        '   "Remix with this image") cho các cảnh, mở đầu prompt bằng "Same characters, colours and soft 3D',
        '   picture-book style as the reference image. New scene: …" để nhân vật giống nhau. Bộ tranh hiện tại',
        '   làm bằng GPT Image 2.5 trên cinai.tv. Model này từ chối prompt "Character sheet", nên bỏ qua bảng',
        '   nhân vật bên dưới (chỉ để tham khảo mô tả nhân vật). Cảnh nào nhân vật chưa xuất hiện thì thêm',
        '   "No <tên> in this picture" vì ảnh bìa có đủ mọi nhân vật.',
        '2. Kích thước ngang **16:9 hoặc 16:10**. Không chữ, không logo. Lệnh nhập ảnh tự cắt về 16:10.',
        '3. Đặt tên file đúng như cột "File", ví dụ `tortoise_hare_03.png`.',
        '4. Bỏ tất cả ảnh vào một thư mục rồi chạy:',
        '   `python3 tool/story_art/import_art.py <thư mục>` — tự cắt 16:10, nén WebP, chép vào `assets/story_art/`.',
        '5. Ong Bi 3D: ảnh vuông 1:1 trên nền xanh lá thuần #00FF00. Làm `bi_happy.png` trước rồi Remix từ nó cho',
        '   các ảnh còn lại. `bi_<tâm trạng>_<cấp>.png` mặc bộ đồ của cấp đó (`biOutfits` trong',
        '   `lib/widgets/bi_mascot.dart`). Nhập bằng `python3 tool/story_art/import_bi.py <thư mục>`: tự tách nền',
        '   xanh, chép vào `assets/bi3d/`. Thiếu ảnh nào thì app dùng Bi SVG kèm đồ như cũ.',
        '',
        f'**Phong cách chung (đã có trong mỗi prompt):** {S.STYLE}',
        '',
        f'**Negative prompt (nếu công cụ có ô này):** {S.NEGATIVE}',
        '',
        '## Ong Bi 3D',
        '',
        '| File | Prompt |',
        '|---|---|',
    ]
    for pose, action in S.BI_POSES:
        for level, outfit in enumerate(S.BI_OUTFITS):
            if level and pose == 'sleeping':
                continue
            name = f'bi_{pose}_{level}' if level else f'bi_{pose}'
            wear = f', {outfit}' if outfit else ', no clothes or accessories'
            p = (f'{S.BI}{wear if pose != "sleeping" else ""}, {action}. Full body, centred, plain pure green '
                 f'(#00FF00) background with nothing else on it, soft studio light, no shadow, no text.')
            items.append({'file': f'{name}.png', 'prompt': p, 'negative': S.NEGATIVE, 'kind': 'mascot'})
            md.append(f'| `{name}.png` | {p} |')
    for sid in ids:
        spec = S.STORIES[sid]
        md += ['', f'## {spec["title"]} (`{sid}`)', '']
        cast = '; '.join(f'{n}: {d}' for n, d in spec['cast'].items())
        sheet = (f'Character sheet: {cast}. Each character shown front and side view on a plain light '
                 f'background, same proportions and colours. {S.STYLE}')
        items.append({'file': f'{sid}_cast.png', 'prompt': sheet, 'negative': S.NEGATIVE, 'kind': 'sheet'})
        md += [f'**Character sheet:** {sheet}', '', '| File | Khi nào hiện | Prompt |', '|---|---|---|']
        for n, block, anchor, scene in spec['scenes']:
            f = f'{sid}_{n:02d}.png'
            p = prompt(sid, scene)
            where = 'Ảnh bìa' if block is None else f'[{block}]' + (f' trước "{anchor}"' if anchor else '')
            items.append({'file': f, 'prompt': p, 'negative': S.NEGATIVE, 'kind': 'scene', 'story': sid, 'scene': n})
            md.append(f'| `{f}` | {where} | {p} |')
    os.makedirs(os.path.join(ROOT, 'docs'), exist_ok=True)
    open(os.path.join(ROOT, 'docs', 'STORY_ART.md'), 'w', encoding='utf-8').write('\n'.join(md) + '\n')
    json.dump(items, open(os.path.join(HERE, 'prompts.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    scenes = sum(1 for i in items if i['kind'] == 'scene')
    print(f'{len(ids)} stories, {scenes} scene pictures, {sum(1 for i in items if i["kind"] == "mascot")} Bi pictures')


if __name__ == '__main__':
    main()
