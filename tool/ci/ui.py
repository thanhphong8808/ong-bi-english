#!/usr/bin/env python3
"""Tiny UI driver for the CI smoke test (adb + uiautomator, no extra installs).

Usage:
  ui.py list                 print every visible label
  ui.py wait  TEXT [SECONDS] exit 0 once TEXT is on screen
  ui.py tap   TEXT [SECONDS] wait for TEXT, then tap the middle of it
  ui.py shot  NAME           save a screenshot and print it as base64
  ui.py gate                 solve the parent gate (a x b) if it is open
  ui.py setup [MINUTES]      download every required pack on the setup screen
  ui.py explore SECONDS [TEXT]  tap through a lesson like a child (answers, mic,
                             next); with TEXT, stop 75 s after TEXT first shows
  ui.py tapright TEXT [SEC]  tap the button at the right end of the row showing TEXT
  ui.py tapx  TEXT [SEC]     like tap, but the label must be exactly TEXT
  ui.py type  TEXT           type ASCII text into the focused field
  ui.py field N              tap the N-th text field on screen (1 = first)
  ui.py writeset SECONDS     do one writing set: copy and test (draws a stroke,
                             taps "Xong"; letter tiles when there is no ink)
  ui.py guided SECONDS       play a guided talk with Bi to its end: the mic on
                             the child's turn (the emulator is silent), then
                             a tap on the first answer when Bi asks for a tap

A "Huy hiệu mới!" (new badge) dialog is photographed once and closed
whenever it shows up, so it never hides the screen being tested.
"""
import base64
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

OUT = 'smoke-out'


def adb(*args, timeout=60):
    return subprocess.run(['adb', *args], capture_output=True, timeout=timeout)


BADGES_SEEN = []


def dump():
    """UI tree of the screen. A system "isn't responding" dialog (the
    emulator's launcher is often slow right after boot) is answered with
    "Wait" first, so it never hides the app."""
    for _ in range(3):
        root = _dump_once()
        if root is None:
            return None
        texts = [(n.get('text') or '') + ' ' + (n.get('content-desc') or '') for n in root.iter('node')]
        if any('Huy hiệu mới' in t for t in texts):
            badge = [t.strip().replace('\n', ' / ') for t in texts if t.strip()][:6]
            print('badge celebration:', badge)
            if not BADGES_SEEN:
                shot('badge')
            BADGES_SEEN.append(1)
            adb('shell', 'input', 'keyevent', 'KEYCODE_BACK')
            time.sleep(2)
            continue
        if not any("isn't responding" in t or 'không phản hồi' in t for t in texts):
            return root
        for node in root.iter('node'):
            if (node.get('text') or '') in ('Wait', 'Chờ'):
                print('dismissed a system "not responding" dialog')
                x1, y1, x2, y2 = map(int, re.findall(r'-?\d+', node.get('bounds')))
                adb('shell', 'input', 'tap', str((x1 + x2) // 2), str((y1 + y2) // 2))
                time.sleep(2)
                break
    return _dump_once()


def _dump_once():
    try:
        adb('shell', 'rm', '-f', '/sdcard/ui.xml', timeout=20)
        adb('shell', 'uiautomator', 'dump', '/sdcard/ui.xml', timeout=45)
        raw = adb('shell', 'cat', '/sdcard/ui.xml', timeout=20).stdout.decode('utf-8', 'replace')
        start = raw.find('<?xml')
        return ET.fromstring(raw[start:]) if start >= 0 else None
    except Exception as error:  # noqa: BLE001 - best effort in CI
        print(f'dump failed: {error}')
        return None


def labels(root):
    for node in root.iter('node'):
        text = ' | '.join(x for x in (node.get('text'), node.get('content-desc')) if x)
        if text:
            yield text, node


def find(text, seconds, exact_match=False):
    deadline = time.time() + seconds
    while True:
        root = dump()
        if root is not None:
            if exact_match:
                matches = [n for label, n in labels(root)
                           if text in (part.strip() for node_text in label.split(' | ')
                                       for part in node_text.split('\n'))]
            else:
                matches = [n for label, n in labels(root) if text.lower() in label.lower()]
            if matches:
                clickable = [n for n in matches if n.get('clickable') == 'true']
                return (clickable or matches)[0]
        if time.time() > deadline:
            return None
        time.sleep(2)


def center(node):
    x1, y1, x2, y2 = map(int, re.findall(r'-?\d+', node.get('bounds')))
    return (x1 + x2) // 2, (y1 + y2) // 2


def shot(name):
    import os
    os.makedirs(OUT, exist_ok=True)
    data = adb('exec-out', 'screencap', '-p', timeout=60).stdout
    with open(f'{OUT}/{name}.png', 'wb') as f:
        f.write(data)
    print(f'BEGIN_PNG {name} {len(data)}')
    print(base64.b64encode(data).decode())
    print('END_PNG')


def bounds(node):
    return tuple(map(int, re.findall(r'-?\d+', node.get('bounds'))))


def exact(root, text):
    return [n for label, n in labels(root) if label.strip() == text]


def tap_node(node):
    x, y = center(node)
    adb('shell', 'input', 'tap', str(x), str(y))


def solve_gate(root):
    """Taps the answer to "a × b = ?". Returns True when a gate was found."""
    for label, _ in labels(root):
        m = re.search(r'(\d+)\s*×\s*(\d+)', label)
        if not m:
            continue
        answer = str(int(m.group(1)) * int(m.group(2)))
        print(f'gate: {m.group(0)} = {answer}')
        for digit in answer:
            keys = exact(root, digit)
            if not keys:
                print(f'gate: key {digit} not found')
                return True
            tap_node(keys[0])
            time.sleep(0.4)
        done = exact(root, 'Xong')
        if done:
            tap_node(done[0])
        time.sleep(2)
        return True
    return False


BUSY = ('Đang tải', 'Đang kiểm tra', 'Đang giải nén', 'Đang nhập')


def swipe(up=True):
    if up:
        adb('shell', 'input', 'swipe', '540', '1900', '540', '600', '300')
    else:
        adb('shell', 'input', 'swipe', '540', '600', '540', '1900', '300')
    time.sleep(1.2)


def to_edge(top):
    for _ in range(6):
        swipe(up=not top)


def setup(minutes):
    """Does what a parent does: "Tải tất cả qua Wi-Fi", the gate, then waits
    until "Vào học" is enabled. Prints progress and failures on the way."""
    deadline = time.time() + minutes * 60
    started = 0
    last_progress = ''
    last_report = 0.0
    while time.time() < deadline:
        to_edge(top=True)
        root = dump()
        if root is None:
            print('setup: no UI dump')
            time.sleep(5)
            continue
        if time.time() - last_report > 60:
            last_report = time.time()
            visible = [label.replace('\n', ' / ')[:90] for label, _ in labels(root)]
            print(f'setup: {int(deadline - time.time())} s left; screen:', visible[:8])
        if solve_gate(root):
            continue
        all_labels = [label for label, _ in labels(root)]
        busy = [label for label in all_labels if any(b in label for b in BUSY)]
        if busy:
            progress = ' || '.join(label.replace('\n', ' / ') for label in busy)
            if progress != last_progress:
                print('busy:', progress[:400])
                last_progress = progress
            time.sleep(10)
            continue
        failed = [label.replace('\n', ' / ') for label in all_labels if 'Chưa tải được' in label]
        if failed:
            print('failed packs:', failed)
        everything = [n for label, n in labels(root) if label.startswith('Tải tất cả')]
        if everything and everything[0].get('enabled') == 'true' and started < 3:
            started += 1
            print(f'tap "Tải tất cả" (#{started})')
            tap_node(everything[0])
            time.sleep(3)
            continue
        to_edge(top=False)
        root = dump()
        if root is not None:
            go = exact(root, 'Vào học')
            if go and go[0].get('enabled') == 'true':
                print('setup: required packs ready')
                return 0
        time.sleep(5)
    print('setup: TIMEOUT')
    for top in (True, False):
        to_edge(top=top)
        root = dump()
        for label, _ in labels(root) if root is not None else []:
            print('   ', label.replace('\n', ' / '))
    return 1


AVOID = ('Phụ huynh', 'Thoát', 'Về nhà', 'Nghỉ học', 'Nghỉ đã')


def explore(seconds, until=None):
    """Taps the clickable things of the current lesson screen in turn: answer
    cards, the microphone, the speaker, "next". Avoids the top bar (close).
    With [until], stops 75 s after that text first appears (time to finish
    the activity showing it)."""
    deadline = time.time() + seconds
    seen_until = False
    turn = 0
    last_screen = None
    while time.time() < deadline:
        root = dump()
        if root is None:
            adb('shell', 'input', 'tap', '540', '1700')
            time.sleep(4)
            continue
        found = [(label, n) for label, n in labels(root)]
        texts = [label for label, _ in found]
        screen = ' | '.join(t.replace('\n', ' ')[:30] for t in texts[:6])
        if screen != last_screen:
            print('screen:', screen)
            last_screen = screen
        if any('Xong chặng' in t for t in texts):
            print('checkpoint reached:', [t for t in texts if 'chặng' in t][:2])
        if until and not seen_until and any(until.lower() in t.lower() for t in texts):
            seen_until = True
            print(f'seen {until!r}')
            shot('explore-' + re.sub(r'\W+', '-', until))
            deadline = min(deadline, time.time() + 75)
        # The "leave the lesson?" dialog: keep learning.
        keep = [n for label, n in found if label.strip() in ('Học tiếp', 'Tiếp tục')]
        if keep:
            tap_node(keep[0])
            time.sleep(2)
            continue
        targets = []
        for node in root.iter('node'):
            if node.get('clickable') != 'true' or node.get('enabled') == 'false':
                continue
            x1, y1, x2, y2 = bounds(node)
            label = (node.get('content-desc') or node.get('text') or '').strip()
            if y1 < 330 or any(a in label for a in AVOID):
                continue
            targets.append(node)
        if not targets:
            adb('shell', 'input', 'tap', '540', '1700')
            time.sleep(4)
            continue
        node = targets[turn % len(targets)]
        turn += 1
        label = (node.get('content-desc') or node.get('text') or '?').replace('\n', ' ')[:40]
        print(f'tap {label!r} at {center(node)}')
        tap_node(node)
        time.sleep(5)
    return 0


def writeset(seconds):
    """Look -> copy -> test -> result. Returns 0 when the result shows."""
    deadline = time.time() + seconds
    turn = 0
    shots = set()
    while time.time() < deadline:
        root = dump()
        if root is None:
            time.sleep(3)
            continue
        found = list(labels(root))
        texts = [label for label, _ in found]
        for emoji, name in (('✏️', '09w-copy'), ('📝', '09w-test')):
            if name not in shots and any(t.strip() == emoji for t in texts):
                shots.add(name)
                shot(name)
        if any(t.strip() == 'Kết quả' for t in texts):
            print('writeset: result screen')
            return 0
        start = [n for label, n in found if label.strip() == 'Tập chép']
        if start:
            print('writeset: tap "Tập chép"')
            tap_node(start[0])
            time.sleep(6)
            continue
        done = [n for label, n in found if label.strip() == 'Xong']
        if done:
            # Write something on the pad (above the tool row), then check.
            x1, y1, x2, y2 = bounds(done[0])
            top = 700
            bottom = max(top + 200, y1 - 120)
            adb('shell', 'input', 'swipe', '300', str(top + 60), '450', str(bottom), '400')
            adb('shell', 'input', 'swipe', '600', str(top + 60), '760', str(bottom), '400')
            time.sleep(1)
            turn += 1
            print(f'writeset: stroke + "Xong" #{turn}')
            tap_node(done[0])
            time.sleep(7)
            continue
        # Letter tiles (no handwriting model): tap them in turn.
        targets = [n for n in root.iter('node')
                   if n.get('clickable') == 'true' and bounds(n)[1] > 900]
        if targets:
            node = targets[turn % len(targets)]
            turn += 1
            tap_node(node)
            time.sleep(2)
        else:
            time.sleep(3)
    print('writeset: TIMEOUT')
    return 1


def guided(seconds):
    """Returns 0 when the talk reaches "Xong rồi!"."""
    deadline = time.time() + seconds
    turns = 0
    while time.time() < deadline:
        root = dump()
        if root is None:
            time.sleep(3)
            continue
        found = list(labels(root))
        texts = [label for label, _ in found]
        # The end card is one accessibility node: its title, the stars and
        # the moral arrive as one label, one line each.
        if any('Xong rồi!' in [line.strip() for line in t.splitlines()] for t in texts):
            print(f'guided: finished after {turns} turns')
            return 0
        header = [n for label, n in found if label.strip() == 'Chạm vào câu bé muốn nói']
        if header:
            top = bounds(header[0])[3]
            cards = [n for n in root.iter('node')
                     if bounds(n)[1] >= top and bounds(n)[3] - bounds(n)[1] > 90
                     and (n.get('text') or n.get('content-desc'))]
            if cards:
                cards.sort(key=lambda n: bounds(n)[1])
                turns += 1
                print(f'guided: tap answer #{turns}:', (cards[0].get('content-desc') or cards[0].get('text') or '')[:60].replace('\n', ' / '))
                tap_node(cards[0])
                time.sleep(6)
                continue
        if any(t.strip() in ('Đến lượt bé!', 'Bé nói theo nhé:') for t in texts):
            mic = [n for label, n in found if label.strip() == 'Micro']
            if mic:
                turns += 1
                print(f'guided: microphone #{turns}')
                tap_node(mic[0])
                time.sleep(18)
                continue
        time.sleep(3)
    print('guided: TIMEOUT')
    return 1


def main():
    cmd = sys.argv[1]
    if cmd == 'list':
        root = dump()
        for label, node in labels(root) if root is not None else []:
            print(f'  [{node.get("bounds")}] {label!r}')
        return 0
    if cmd == 'shot':
        shot(sys.argv[2])
        return 0
    if cmd == 'gate':
        root = dump()
        return 0 if root is not None and solve_gate(root) else 1
    if cmd == 'setup':
        return setup(float(sys.argv[2]) if len(sys.argv) > 2 else 25)
    if cmd == 'explore':
        return explore(float(sys.argv[2]) if len(sys.argv) > 2 else 120,
                       sys.argv[3] if len(sys.argv) > 3 else None)
    if cmd == 'guided':
        return guided(float(sys.argv[2]) if len(sys.argv) > 2 else 300)
    if cmd == 'writeset':
        return writeset(float(sys.argv[2]) if len(sys.argv) > 2 else 240)
    if cmd == 'field':
        root = dump()
        fields = [n for n in root.iter('node') if 'EditText' in (n.get('class') or '')] if root is not None else []
        index = int(sys.argv[2]) - 1
        if index >= len(fields):
            print(f'NOT FOUND: text field {index + 1} ({len(fields)} on screen)')
            return 1
        tap_node(fields[index])
        print(f'tapped text field {index + 1} at {center(fields[index])}')
        return 0
    if cmd == 'type':
        adb('shell', 'input', 'text', sys.argv[2].replace(' ', '%s'))
        print(f'typed {sys.argv[2]!r}')
        return 0
    text = sys.argv[2]
    seconds = float(sys.argv[3]) if len(sys.argv) > 3 else 30
    node = find(text, seconds, exact_match=(cmd == 'tapx'))
    if cmd == 'tapx':
        cmd = 'tap'  # exact label, otherwise the same as tap
    if node is None:
        # Screens with a looping animation never become "idle", so
        # uiautomator cannot read them; fall back to known coordinates
        # (pixel_6 profile, 1080 x 2400) when the caller gives them.
        if cmd == 'tap' and len(sys.argv) > 5:
            x, y = sys.argv[4], sys.argv[5]
            adb('shell', 'input', 'tap', x, y)
            print(f'tapped {text!r} at {x},{y} (by position)')
            return 0
        print(f'NOT FOUND: {text!r}')
        return 1
    if cmd == 'tapright':
        x1, y1, x2, y2 = bounds(node)
        x, y = x2 - 110, (y1 + y2) // 2
        adb('shell', 'input', 'tap', str(x), str(y))
        print(f'tapped the right end of {text!r} at {x},{y}')
        return 0
    if cmd == 'tap':
        x, y = center(node)
        adb('shell', 'input', 'tap', str(x), str(y))
        print(f'tapped {text!r} at {x},{y}')
    else:
        print(f'found {text!r}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
