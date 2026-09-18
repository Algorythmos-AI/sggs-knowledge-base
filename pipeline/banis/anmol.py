# -*- coding: utf-8 -*-
"""AnmolLipi / GurbaniAkhar ASCII -> Unicode Gurmukhi (the ShabadOS encoding).

Two modes:
  to_unicode(s, fold=True)   -- folds nukta/addak/udaat away so the result aligns
                                with OUR SGGS edition. Used ONLY as a MATCH KEY to
                                find our verbatim line id; never stored.
  to_unicode(s, fold=False)  -- verbatim conversion for NON-SGGS text (Sri Dasam
                                Granth, Ardaas) stored in `extra_lines`. Nothing is
                                folded; only vishraam pause marks and footnote
                                subscripts (typography, not text) are dropped.

The tables mirror pipeline/shabados_ingest.py; test_banis_layer.py keeps them in step.
"""
import re
import sys
import unicodedata
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from sggs_pipeline import CONS, HALANT  # noqa: E402

DIGRAPHS = [('<>', 'ੴ'), ('AW', 'ਆਂ'), ('Aw', 'ਆ'), ('AY', 'ਐ'), ('AO', 'ਔ'),
            ('aU', 'ਊ'), ('au', 'ਉ'), ('eI', 'ਈ'), ('ey', 'ਏ'), ('ie', 'ਇ')]
MAP = {
    'a': 'ੳ', 'A': 'ਅ', 'e': 'ੲ', 's': 'ਸ', 'h': 'ਹ',
    'k': 'ਕ', 'K': 'ਖ', 'g': 'ਗ', 'G': 'ਘ', '|': 'ਙ',
    'c': 'ਚ', 'C': 'ਛ', 'j': 'ਜ', 'J': 'ਝ', '\\': 'ਞ',
    't': 'ਟ', 'T': 'ਠ', 'f': 'ਡ', 'F': 'ਢ', 'x': 'ਣ',
    'q': 'ਤ', 'Q': 'ਥ', 'd': 'ਦ', 'D': 'ਧ', 'n': 'ਨ',
    'p': 'ਪ', 'P': 'ਫ', 'b': 'ਬ', 'B': 'ਭ', 'm': 'ਮ',
    'X': 'ਯ', 'r': 'ਰ', 'l': 'ਲ', 'v': 'ਵ', 'V': 'ੜ',
    'E': 'ਓ', 'S': 'ਸ਼', 'z': 'ਜ਼', 'Z': 'ਗ਼', '^': 'ਖ਼', '&': 'ਫ਼', 'L': 'ਲ਼',
    'w': 'ਾ', 'i': 'ਿ', 'I': 'ੀ', 'u': 'ੁ', 'U': 'ੂ', 'y': 'ੇ', 'Y': 'ੈ', 'o': 'ੋ', 'O': 'ੌ',
    'W': 'ਾਂ', 'M': 'ੰ', 'µ': 'ੰ', 'N': 'ਂ', 'ˆ': 'ਂ', 'Ú': 'ਃ', '@': 'ੑ', '~': 'ੱ', '`': 'ੱ',
    'R': '੍ਰ', '®': '੍ਰ', 'H': '੍ਹ', 'Í': '੍ਵ', '´': '੍ਯ', 'Î': '੍ਯ', 'ç': '੍ਚ', '†': '੍ਟ',
    'œ': '੍ਤ', '˜': '੍ਨ',
    'ü': 'ੁ', '¨': 'ੂ', 'Ø': '',          # Ø = glyph-positioning helper before subjoined ਯ
    ']': '॥', '[': '।',
    '0': '੦', '1': '੧', '2': '੨', '3': '੩', '4': '੪', '5': '੫', '6': '੬', '7': '੭', '8': '੮', '9': '੯',
    ' ': ' ',
    ';': '', ',': '', '.': '',             # vishraam pause marks — not text
    '₁': '', '₂': '', '₃': '', '₄': '', '₅': '', '₆': '', '₈': '',   # footnote subscripts
}
PASSTHROUGH = set('ੴਆਉਊਇਈਏਐਔ') | {'ਾ', 'ਂ', '…'}
# our SGGS edition writes without nukta/addak/udaat — fold ONLY for match keys
FOLD = {'ਸ਼': 'ਸ', 'ਖ਼': 'ਖ', 'ਗ਼': 'ਗ', 'ਜ਼': 'ਜ', 'ਫ਼': 'ਫ', 'ਲ਼': 'ਲ', 'ੱ': '', 'ੑ': ''}
ELLIPSIS_SLOT = '...'   # Ardaas fill-in slot ("… ਦੀ ਅਰਦਾਸ ਹੈ ਜੀ") — meaningful, kept as U+2026


def move_sihari(s):
    """ASCII sources put sihari before its consonant (visual order); subjoined
    consonants are already logical — so ONLY the sihari moves."""
    out, i, n = [], 0, len(s)
    while i < n:
        c = s[i]
        if c == 'ਿ':
            j = i + 1
            if j < n and s[j] in CONS:
                j += 1
                while j + 1 < n and s[j] == HALANT and s[j + 1] in CONS:
                    j += 2
                out.append(s[i + 1:j])
                out.append('ਿ')
                i = j
                continue
        out.append(c)
        i += 1
    return ''.join(out)


def to_unicode(ascii_g, fold=True, unknown=None):
    s = ascii_g.replace(ELLIPSIS_SLOT, '…')
    for a, b in DIGRAPHS:
        s = s.replace(a, b)
    out = []
    for ch in s:
        if ch in PASSTHROUGH:
            out.append(ch)
        elif ch in MAP:
            out.append(MAP[ch])
        elif unknown is not None:
            unknown[ch] += 1
    u = ''.join(out)
    if fold:
        for a, b in FOLD.items():
            u = u.replace(a, b)
    u = move_sihari(u)
    u = unicodedata.normalize('NFC', u)
    return re.sub(r'\s+', ' ', u).strip()
