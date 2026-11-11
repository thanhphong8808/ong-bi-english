#!/usr/bin/env python3
"""Tiny UI driver for the CI smoke test (adb + uiautomator, no extra installs).

Usage:
  ui.py list                 print every visible label
  ui.py wait  TEXT [SECONDS] exit 0 once TEXT is on screen
  ui.py tap   TEXT [SECONDS] wait for TEXT, then tap the middle of it
  ui.py shot  NAME           save a screenshot and print it as base64
  ui.py gate                 solve the parent gate (a x b) if it is open
  ui.py setup [MINUTES]      download every required pack on the setup screen
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


def dump():
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


def find(text, seconds):
    deadline = time.time() + seconds
    while True:
        root = dump()
        if root is not None:
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
MARKERS = {'Bắt buộc': True, 'Tuỳ chọn': False, 'Nhận dạng chữ viết tay': True}


def swipe(up=True):
    if up:
        adb('shell', 'input', 'swipe', '540', '1900', '540', '700', '400')
    else:
        adb('shell', 'input', 'swipe', '540', '700', '540', '1900', '400')
    time.sleep(1.5)


def setup(minutes):
    """Downloads required packs (and handwriting) one by one, skipping Gemma."""
    deadline = time.time() + minutes * 60
    taps = 0
    scrolls = 0
    while time.time() < deadline:
        root = dump()
        if root is None:
            time.sleep(3)
            continue
        if solve_gate(root):
            continue
        all_labels = [label for label, _ in labels(root)]
        if any(label.startswith(BUSY) for label in all_labels):
            progress = [label for label in all_labels if label.startswith(BUSY)]
            print('busy:', progress[:3])
            time.sleep(6)
            continue
        markers = []
        for label, node in labels(root):
            if label.strip() in MARKERS:
                markers.append((bounds(node)[1], MARKERS[label.strip()]))
        eligible = []
        for node in exact(root, 'Tải'):
            top = bounds(node)[1]
            above = [m for m in markers if m[0] < top]
            if above and max(above)[1]:
                eligible.append(node)
        if eligible and taps < 12:
            taps += 1
            node = min(eligible, key=lambda n: bounds(n)[1])
            print(f'download tap #{taps} at {center(node)}')
            tap_node(node)
            time.sleep(3)
            continue
        go = exact(root, 'Vào học')
        if go and go[0].get('enabled') == 'true' and not eligible:
            print('setup: required packs ready')
            for label in all_labels:
                print('  ', label)
            return 0
        failed = [label for label in all_labels if 'Chưa tải được' in label or 'Lỗi' in label]
        if failed:
            print('setup: failures:', failed)
        scrolls += 1
        if scrolls % 8 == 0:
            for _ in range(6):
                swipe(up=False)
        else:
            swipe(up=True)
    print('setup: TIMEOUT')
    root = dump()
    for label, _ in labels(root) if root is not None else []:
        print('  ', label)
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
    text = sys.argv[2]
    seconds = float(sys.argv[3]) if len(sys.argv) > 3 else 30
    node = find(text, seconds)
    if node is None:
        print(f'NOT FOUND: {text!r}')
        return 1
    if cmd == 'tap':
        x, y = center(node)
        adb('shell', 'input', 'tap', str(x), str(y))
        print(f'tapped {text!r} at {x},{y}')
    else:
        print(f'found {text!r}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
