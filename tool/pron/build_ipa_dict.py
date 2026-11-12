#!/usr/bin/env python3
"""Builds assets/pron/ipa_en_us.txt.gz from the CMU Pronouncing Dictionary.

Usage: python3 tool/pron/build_ipa_dict.py path/to/cmudict.dict

One line per word, "word<TAB>ipa", sorted, first pronunciation only, IPA in
the same American style as the curriculum (/hɛˈloʊ/ without the slashes).
The CMU dictionary is BSD-licensed (see LICENSES.md).
"""
import gzip
import re
import sys

VOWELS = {
    'AA': 'ɑ', 'AE': 'æ', 'AH': 'ʌ', 'AO': 'ɔ', 'AW': 'aʊ', 'AY': 'aɪ', 'EH': 'ɛ',
    'EY': 'eɪ', 'IH': 'ɪ', 'IY': 'i', 'OW': 'oʊ', 'OY': 'ɔɪ', 'UH': 'ʊ',
    'UW': 'u',
}
CONSONANTS = {
    'B': 'b', 'CH': 'tʃ', 'D': 'd', 'DH': 'ð', 'F': 'f', 'G': 'ɡ', 'HH': 'h', 'JH': 'dʒ',
    'K': 'k', 'L': 'l', 'M': 'm', 'N': 'n', 'NG': 'ŋ', 'P': 'p', 'R': 'r', 'S': 's',
    'SH': 'ʃ', 'T': 't', 'TH': 'θ', 'V': 'v', 'W': 'w', 'Y': 'j', 'Z': 'z', 'ZH': 'ʒ',
}
# Consonant clusters that can start an English syllable (maximal onset).
ONSETS = {
    tuple(o.split()) for o in [
        'P R', 'P L', 'B R', 'B L', 'T R', 'D R', 'K R', 'K L', 'G R', 'G L', 'F R', 'F L',
        'TH R', 'SH R', 'S P', 'S T', 'S K', 'S M', 'S N', 'S L', 'S W', 'T W', 'D W', 'K W',
        'G W', 'S P R', 'S T R', 'S K R', 'S P L', 'S K W', 'P Y', 'B Y', 'K Y', 'F Y', 'M Y',
        'V Y', 'HH Y', 'TH W',
    ]
}


def to_ipa(phones):
    """ARPAbet with stress digits -> IPA with stress marks before syllables."""
    syll_vowels = [i for i, p in enumerate(phones) if p[-1].isdigit()]
    marks = {}
    if len(syll_vowels) > 1:
        prev_end = 0
        for n, v in enumerate(syll_vowels):
            stress = phones[v][-1]
            # Onset: consonants before the vowel that form a legal onset.
            start = v
            lo = syll_vowels[n - 1] + 1 if n > 0 else 0
            while start - 1 >= lo:
                cand = tuple(p for p in phones[start - 1:v])
                if len(cand) == 1 or cand in ONSETS:
                    start -= 1
                else:
                    break
            if n == 0:
                start = 0
            if stress == '1':
                marks[start] = 'ˈ'
            elif stress == '2':
                marks[start] = 'ˌ'
            prev_end = v
    out = []
    for i, p in enumerate(phones):
        if i in marks:
            out.append(marks[i])
        base = p.rstrip('012')
        if base in VOWELS or base == 'ER':
            stress = p[-1]
            if base == 'AH' and stress == '0':
                out.append('ə')
            elif base == 'ER':
                # Same style as the curriculum: "teacher" /ˈtitʃər/, "bird" /bʌrd/.
                out.append('ər' if stress == '0' else 'ʌr')
            else:
                out.append(VOWELS[base])
        else:
            out.append(CONSONANTS[base])
    ipa = ''.join(out)
    # "around" is ER0 AW1 in CMU: the r starts the stressed syllable.
    return re.sub(r'([əʌ])r([ˈˌ])', r'\1\2r', ipa)


def main(path):
    seen = {}
    word_re = re.compile(r"^[a-z]+(?:'[a-z]+)?$")
    for line in open(path, encoding='utf-8'):
        line = line.split('#')[0].strip()
        if not line:
            continue
        word, *phones = line.split()
        if '(' in word or not word_re.match(word) or word in seen:
            continue
        seen[word] = to_ipa(phones)
    data = ''.join(f'{w}\t{seen[w]}\n' for w in sorted(seen))
    with gzip.open('assets/pron/ipa_en_us.txt.gz', 'wb', compresslevel=9) as f:
        f.write(data.encode('utf-8'))
    print(f'{len(seen)} words')


if __name__ == '__main__':
    main(sys.argv[1])
