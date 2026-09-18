# -*- coding: utf-8 -*-
"""Line matching: a converted ShabadOS SGGS line -> OUR verbatim `lines.id`.

Same tiers as pipeline/load_translations.py (exact -> unique skeleton -> fuzzy
>= 0.92 over ang±1), plus the 1->N / N->1 line-break helpers the bani registry
needs (ShabadOS has 60,555 SGGS lines vs our 60,658 — the same text, sometimes
broken at different points). Read-only: only SELECTs on `lines`."""
import difflib
import re
import unicodedata

MATRAS = 'ਾਿੀੁੂੇੈੋੌ੍ੰਂਃ਼ੱੑੵ'


def norm(s):
    s = unicodedata.normalize('NFC', s)
    s = re.sub(r'[॥।|੦-੯\s]+', ' ', s).strip()
    s = re.sub(r'( ਰਹਾਉ( ਦੂਜਾ)?)+$', '', s)   # refrain label = marker, not verse text
    return s


def skel(s):
    return re.sub('[' + MATRAS + ' ]', '', norm(s))


def load_corpus_index(con):
    """ang -> [(line_id, norm(text), skel(text))] in id order."""
    by_ang = {}
    for lid, ang, text in con.execute('SELECT id, ang, text FROM lines ORDER BY id'):
        by_ang.setdefault(ang, []).append((lid, norm(text), skel(text)))
    return by_ang


def candidates(by_ang, ang):
    c = []
    for a in (ang, ang - 1, ang + 1):
        c += by_ang.get(a, [])
    return c


def match_one(cands, g, after=0):
    """-> (line_id, quality) or (None, None).

    `after` is the reading cursor (the last line id already placed): among equal
    matches the FIRST candidate past the cursor wins, so repeated short lines
    (ਸਲੋਕੁ ॥, ਪਉੜੀ ॥, a refrain) resolve to successive printed lines instead of
    the same one twice. Falls back to the first match anywhere."""
    gn, gs = norm(g), skel(g)
    exact = [c_lid for c_lid, c_n, _ in cands if c_n == gn]
    if exact:
        ahead = [i for i in exact if i > after]
        return (ahead[0] if ahead else exact[0]), 'exact'
    sk = [c_lid for c_lid, _, c_s in cands if c_s == gs and gs]
    if sk:
        ahead = [i for i in sk if i > after]
        if len(ahead) == 1 or (not ahead and len(sk) == 1):
            return (ahead or sk)[0], 'skeleton'
    if cands:
        pool = [c for c in cands if c[0] > after] or cands
        best = max(pool, key=lambda c: difflib.SequenceMatcher(None, gn, c[1]).ratio())
        if difflib.SequenceMatcher(None, gn, best[1]).ratio() >= 0.92:
            return best[0], 'fuzzy'
    return None, None


def match_split(cands, g, after=0):
    """1->N: one ShabadOS line == two or three consecutive lines of ours."""
    gn = norm(g)
    ordered = sorted(cands, key=lambda c: c[0])
    for k in (2, 3):
        for i in range(len(ordered) - k + 1):
            run = ordered[i:i + k]
            if run[0][0] <= after:
                continue
            if all(run[j][0] + 1 == run[j + 1][0] for j in range(k - 1)) and \
               ' '.join(r[1] for r in run) == gn:
                return [r[0] for r in run], 'split%d' % k
    return None, None


def match_joined(cands, gs, after=0):
    """N->1: consecutive ShabadOS lines joined == one line of ours."""
    gn = ' '.join(norm(g) for g in gs)
    hits = [c_lid for c_lid, c_n, _ in cands if c_n == gn]
    ahead = [i for i in hits if i > after]
    if ahead or hits:
        return (ahead or hits)[0], 'join%d' % len(gs)
    return None, None
