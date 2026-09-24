# -*- coding: utf-8 -*-
"""romannorm.py — the ONE Roman phonetic fold shared by the index (build time), the search
query path (serve.py) and the quotation-verification engine (verify.py). verify.py cannot
import serve.py (serve imports verify), so the fold lives here and serve re-exports it.

KEEP IN SYNC, byte for byte, with sggs-data pipeline/sggs_pipeline.py:roman_norm() — the query-time
fold must equal the fold that built `lines.translit_norm` or search/verify silently break.
"""
import re

def roman_norm(s):
    """Phonetic-fold Roman normal form, applied to BOTH the index column and the
    query: 'waheguru'/'vaahiguroo' -> 'vhgr'; 'yashoda'/'jasodaa' -> 'jsd';
    'krishna'/'krisan' -> 'krsn'; 'gyan'/'giaan' -> 'gn'.
    KEEP IN SYNC with sggs-data pipeline/sggs_pipeline.py:roman_norm()."""
    out = []
    for w in s.lower().split():
        w = w.replace('w', 'v').replace('z', 'j').replace('q', 'k').replace('x', 'k')
        for dg in ('sh', 'chh', 'ch', 'kh', 'gh', 'jh', 'th', 'dh', 'bh', 'ph', 'rh', 'f'):
            w = w.replace(dg, dg[0] if dg != 'f' else 'p')
        w = w.replace('b', 'v').replace('k', 'g').replace('t', 'd').replace('p', 'v')   # ਬ/ਵ + Sanskrit↔Punjabi voicing (bhakti~bhagatee)
        if w.startswith('y'): w = 'j' + w[1:]
        w = w.replace('y', '')                       # medial glide: gyan ~ giaan
        head = w[0] if w and w[0] in 'aeiou' else ''
        body = re.sub('[aeiou]', '', w)
        body = re.sub(r'(.)\1+', r'\1', body)        # collapse doubles
        out.append((head + body) if (head + body) else w)
    return ' '.join(o for o in out if o)
