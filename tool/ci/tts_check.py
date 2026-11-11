#!/usr/bin/env python3
"""tool/ci/tts_check.py SPEECH_JSON

Runs every built-in voice and the speech recogniser with the app's exact
sherpa-onnx settings (printed by tool/dump_speech_configs.dart) on real
lesson text, using the same sherpa-onnx version as the app.

Inside the app a sherpa-onnx C++ exception aborts the whole process (for
example "Failed to set eSpeak-ng voice" for a British voice), so any
failure here stops the release.
"""
import glob
import hashlib
import json
import os
import random
import re
import shutil
import sys
import tarfile
import time
import urllib.request

import sherpa_onnx

CACHE = os.path.expanduser('~/.cache/ongbi-models')
MODELS = os.path.abspath('speech-models')
RISKY = re.compile(r"[^A-Za-z0-9 ,.?!'\-]")
failures = []


def log(*args):
    print(*args, flush=True)


def fetch(pack):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, pack['fileName'])
    if not os.path.exists(path):
        log(f"download {pack['url']}")
        request = urllib.request.Request(pack['url'], headers={'User-Agent': 'ongbi-ci'})
        with urllib.request.urlopen(request, timeout=600) as response, open(path + '.part', 'wb') as out:
            shutil.copyfileobj(response, out, 1 << 20)
        os.replace(path + '.part', path)
    if pack.get('sha256'):
        digest = hashlib.sha256()
        with open(path, 'rb') as f:
            for block in iter(lambda: f.read(1 << 20), b''):
                digest.update(block)
        if digest.hexdigest() != pack['sha256']:
            os.remove(path)
            raise SystemExit(f"sha256 mismatch for {pack['fileName']}")
    return path


def install(pack):
    """Installs a pack the way the app does: models/<id>/..., then prunes."""
    target = os.path.join(MODELS, pack['id'])
    if all(os.path.exists(os.path.join(target, f)) for f in pack['requiredFiles']):
        return
    archive = fetch(pack)
    os.makedirs(target, exist_ok=True)
    if pack['kind'] == 'tarBz2':
        with tarfile.open(archive, 'r:bz2') as tar:
            tar.extractall(target, filter='data')
    else:
        shutil.copy(archive, os.path.join(target, pack['fileName']))
    for rel in pack.get('prune', []):
        path = os.path.join(target, rel)
        if os.path.isdir(path):
            shutil.rmtree(path, ignore_errors=True)
        elif os.path.exists(path):
            os.remove(path)
    missing = [f for f in pack['requiredFiles'] if not os.path.exists(os.path.join(target, f))]
    if missing:
        raise SystemExit(f"{pack['id']}: missing after install: {missing}")


def real_paths(value, root):
    if isinstance(value, str):
        return value.replace(root, MODELS)
    if isinstance(value, dict):
        return {k: real_paths(v, root) for k, v in value.items()}
    return value


def lesson_texts():
    """English and Vietnamese strings the lessons speak."""
    words, sentences, vi = set(), set(), set()
    for path in sorted(glob.glob('assets/curriculum/level_*/*.json')):
        unit = json.load(open(path, encoding='utf-8'))
        for item in unit.get('items', []):
            words.add(item['en'])
            sentences.add(item.get('example_en', ''))
            vi.add(item.get('vi', ''))
            vi.add(item.get('example_vi', ''))
        for pattern in unit.get('patterns', []):
            for slot in pattern.get('slots', {}).get('x', [])[:2]:
                sentences.add(pattern['en'].replace('{x}', slot))
        for dialogue in unit.get('dialogues', []):
            for line in dialogue.get('lines', []):
                sentences.add(line['en'])
                vi.add(line.get('vi', ''))
        for reading in unit.get('readings', []):
            sentences.update(reading.get('text_en', []))
            for question in reading.get('questions', []):
                sentences.add(question.get('q', ''))
                sentences.update(question.get('options', []))
        for quiz in unit.get('quiz_bank', []):
            if quiz.get('audio_en'):
                sentences.add(quiz['audio_en'])
    for pool in (words, sentences, vi):
        pool.discard('')
    return sorted(words), sorted(sentences), sorted(vi)


def pick(pool, n, rng):
    pool = list(pool)
    return pool if len(pool) <= n else rng.sample(pool, n)


def make_tts(config):
    c = config
    if c['kind'] == 'kokoro':
        model = sherpa_onnx.OfflineTtsModelConfig(
            kokoro=sherpa_onnx.OfflineTtsKokoroModelConfig(
                model=c['model'], voices=c['voices'], tokens=c['tokens'], data_dir=c['dataDir'],
                dict_dir=c.get('dictDir', ''), lexicon=c.get('lexicon', ''), lang=c.get('lang', '')),
            num_threads=c['threads'], debug=False, provider='cpu')
    else:
        model = sherpa_onnx.OfflineTtsModelConfig(
            vits=sherpa_onnx.OfflineTtsVitsModelConfig(model=c['model'], tokens=c['tokens'], data_dir=c['dataDir']),
            num_threads=c['threads'], debug=False, provider='cpu')
    return sherpa_onnx.OfflineTts(sherpa_onnx.OfflineTtsConfig(model=model))


def speak(name, tts, sid, texts, speeds=(1.0,)):
    start = time.time()
    seconds = 0.0
    last = None
    for text in texts:
        for speed in speeds:
            try:
                audio = tts.generate(text, sid=sid, speed=speed)
            except Exception as error:  # noqa: BLE001 - this is what aborts the app
                failures.append(f'{name}: {text!r} (speed {speed}): {error}')
                log(f'  FAIL {name}: {text!r}: {error}')
                continue
            if len(audio.samples) == 0:
                failures.append(f'{name}: {text!r}: empty audio')
                continue
            seconds += len(audio.samples) / audio.sample_rate
            last = audio
    log(f'  {name}: {len(texts)} texts, {seconds:.0f} s of audio in {time.time() - start:.0f} s')
    return last


def resample(samples, rate, target):
    if rate == target:
        return list(samples)
    n = int(len(samples) * target / rate)
    out = []
    for i in range(n):
        pos = i * rate / target
        j = int(pos)
        k = min(j + 1, len(samples) - 1)
        frac = pos - j
        out.append(samples[j] * (1 - frac) + samples[k] * frac)
    return out


def check_stt(entry, audio16k):
    c = entry['config']
    name = entry['name']
    try:
        recognizer = sherpa_onnx.OfflineRecognizer.from_whisper(
            encoder=c['encoder'], decoder=c['decoder'], tokens=c['tokens'], num_threads=c['threads'],
            language='en', task='transcribe', provider='cpu', debug=False)
        vad_config = sherpa_onnx.VadModelConfig()
        vad_config.silero_vad.model = c['vadModel']
        vad_config.silero_vad.threshold = c['vadThreshold']
        vad_config.silero_vad.min_silence_duration = c['vadMinSilence']
        vad_config.silero_vad.min_speech_duration = c['vadMinSpeech']
        vad_config.silero_vad.max_speech_duration = c['vadMaxSpeech']
        vad_config.silero_vad.window_size = c['vadWindow']
        vad_config.sample_rate = c['sampleRate']
        vad_config.num_threads = 1
        vad = sherpa_onnx.VoiceActivityDetector(vad_config, buffer_size_in_seconds=30)
        window = c['vadWindow']
        padded = [0.0] * 8000 + audio16k + [0.0] * 16000
        for i in range(0, len(padded) - window + 1, window):
            vad.accept_waveform(padded[i:i + window])
        vad.flush()
        texts = []
        while not vad.empty():
            stream = recognizer.create_stream()
            stream.accept_waveform(c['sampleRate'], vad.front.samples)
            recognizer.decode_stream(stream)
            texts.append(stream.result.text.strip())
            vad.pop()
        log(f'  {name}: heard {texts!r}')
        if not any(texts):
            failures.append(f'{name}: no speech recognised from a clear synthetic sentence')
    except Exception as error:  # noqa: BLE001
        failures.append(f'{name}: {error}')
        log(f'  FAIL {name}: {error}')


def main():
    spec = json.load(open(sys.argv[1], encoding='utf-8'))
    log(f'sherpa-onnx {sherpa_onnx.__version__}')
    for pack in spec['packs']:
        install(pack)
    root = spec['modelsRoot']
    rng = random.Random(20261112)
    words, sentences, vi = lesson_texts()
    risky_en = [t for t in sentences + words if RISKY.search(t)]
    risky_vi = [t for t in vi if re.search(r'[0-9"“”…—–()/:;]', t)]
    log(f'{len(words)} words, {len(sentences)} sentences ({len(risky_en)} with unusual characters), {len(vi)} Vietnamese lines')

    keep_vi = None
    sample_audio = None
    tested_accents = set()
    for entry in spec['tts']:
        config = real_paths(entry['config'], root)
        name = entry['name']
        log(f'{name}: {json.dumps(entry["config"], ensure_ascii=False)}')
        try:
            tts = make_tts(config)
        except Exception as error:  # noqa: BLE001
            failures.append(f'{name}: cannot load: {error}')
            log(f'  FAIL {name}: cannot load: {error}')
            continue
        if entry['lang'] == 'vi':
            texts = list(spec['viSpoken']) + pick(vi, 60, rng) + pick(risky_vi, 30, rng)
            speak(name, tts, entry['sid'], texts)
            keep_vi = tts  # the app keeps the Vietnamese voice loaded
            continue
        accent = (config.get('lexicon') or config['model']).split(',')[0]
        if accent in tested_accents:
            texts = pick(words, 4, rng) + pick(sentences, 3, rng)
        else:
            tested_accents.add(accent)
            texts = pick(words, 50, rng) + pick(sentences, 40, rng) + pick(risky_en, 40, rng)
        speak(name, tts, entry['sid'], texts[:4], speeds=(0.7, 1.0))
        last = speak(name, tts, entry['sid'], texts[4:])
        if sample_audio is None and entry['name'].startswith('kokoro'):
            audio = tts.generate('Hello! I like apples and bananas.', sid=entry['sid'], speed=1.0)
            sample_audio = resample(audio.samples, audio.sample_rate, 16000)
        del tts, last
    del keep_vi

    if sample_audio is None:
        failures.append('no English audio to test speech recognition with')
    else:
        for entry in spec['stt']:
            log(f"{entry['name']}:")
            check_stt({'name': entry['name'], 'config': real_paths(entry['config'], root)}, sample_audio)

    if failures:
        log(f'\n{len(failures)} FAILURE(S):')
        for failure in failures[:50]:
            log('  ' + failure)
        log('::error::A built-in voice or the speech recogniser failed; in the app this aborts the process.')
        return 1
    log('\nAll voices and speech recognition work with the app settings.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
