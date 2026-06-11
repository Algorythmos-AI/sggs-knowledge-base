# -*- coding: utf-8 -*-
"""Phonetic Variant Engine — deterministic build (design: 03_Phonetic-Variant-Engine.md;
rules: validation/variant_rules_spec.md; review: validation/variant_arch_review.md).

Generates, for every (gurmukhi word, canonical translit) pair, the romanization
variants real users type — ≤15 per word, BFS depth 2 over 15 weighted rules —
then purges: English-vocabulary collisions (vocab of OUR translation layer +
shortlist), canonical-translit collisions, <2 chars, non-alnum.

Usage: python3 build_variants.py <db_path>
"""
import sys, re, sqlite3, collections, itertools

DB = sys.argv[1]
con = sqlite3.connect(DB)
cur = con.cursor()

# ---------------------------------------------------------------- token pairs
# Reviewer change #1: ੴ expands to two translit tokens; pre-substitute.
pairs = collections.Counter()          # (gurmukhi_word, translit_token) -> freq
misaligned = 0
GDIG = set('੦੧੨੩੪੫੬੭੮੯')
for text, translit in cur.execute('SELECT text, translit FROM lines WHERE is_header=0'):
    g_toks = [t for t in text.replace('ੴ', '').split()
              if t and not set(t) <= GDIG]
    g_out = []
    for t in g_toks:
        if t == '': g_out += ['ੴ', 'ੴ']    # ik + oankaar slots
        else: g_out.append(t)
    t_toks = (translit or '').split()
    if len(g_out) != len(t_toks):
        misaligned += 1; continue
    for g, tr in zip(g_out, t_toks):
        if g.startswith('ੴ'): continue                  # invocation handled by lexicon
        pairs[(g, tr)] += 1

# canonical translit per gurmukhi word = its most frequent token
canon = {}
freq_g = collections.Counter()
for (g, tr), n in pairs.items():
    freq_g[g] += n
    if g not in canon or pairs[(g, canon[g])] < n:
        canon[g] = tr
canonical_set = {tr for tr in canon.values()}
print(f'word pairs: {len(canon)} | misaligned lines skipped: {misaligned}')

# ---------------------------------------------------------------- veto list
# Veto = words that occur in the English layer in LOWERCASE form (real English
# vocabulary). SSK reverentially capitalizes Gurbani loanwords (Kirtan, Amrit,
# Naam, Hukam…) — those must NOT be vetoed, they're the variants we want most.
lc_count = collections.Counter()
try:
    for (t,) in cur.execute("SELECT text FROM translations WHERE lang='en'"):
        for w in re.findall(r"[A-Za-z]{2,}", t):
            if w.islower(): lc_count[w] += 1
except sqlite3.OperationalError:
    pass
veto = {w for w, n in lc_count.items() if n >= 2}
veto |= {'me','he','may','hay','lay','say','fir','fun','man','war','win','sun','ram',
         'jam','hum','sum','gun','gem','dam','nam','pan','ban','tan','car','jar'}
print(f'english veto vocabulary: {len(veto)}')

# ---------------------------------------------------------------- rule engine
C = 'bcdfghjklmnprstvwxyz'
RULES = [  # (id, applies(w)->bool, expand(w)->[variants], weight)
 ('R01', lambda w: 'aa' in w,              lambda w: [w.replace('aa', 'a')],            0.90),
 ('R02', lambda w: 'ee' in w,              lambda w: [w.replace('ee', 'i')],            0.85),
 ('R03', lambda w: 'oo' in w,              lambda w: [w.replace('oo', 'u')],            0.85),
 ('R04', lambda w: re.search(f'[{C}]iaan', w), lambda w: [re.sub(f'([{C}])iaan', r'\1yan', w)],  0.80),
 ('R05', lambda w: re.search(f'[{C}]iaan', w), lambda w: [re.sub(f'([{C}])iaan', r'\1iyan', w)], 0.55),
 ('R06', lambda w: 'au' in w,              lambda w: [w.replace('au', 'o')],            0.80),
 ('R07', lambda w: 'au' in w,              lambda w: [w.replace('au', 'ou')],           0.70),
 ('R08', lambda w: 'ai' in w and len(w) >= 5, lambda w: [w.replace('ai', 'e')],         0.75),
 ('R09', lambda w: 'ai' in w and len(w) >= 5, lambda w: [w.replace('ai', 'ay')],        0.65),
 ('R10', lambda w: w.startswith('v'),      lambda w: ['w' + w[1:]],                     0.85),
 ('R11', lambda w: re.search(f'([{C}])\\1', w), lambda w: [re.sub(f'([{C}])\\1', r'\1', w)], 0.80),
 ('R12', lambda w: w.endswith('am') and len(w) >= 5 and not w.endswith('aam') and w[-3] != 'r',
         lambda w: [w[:-2] + 'um'],                                                     0.60),
 ('R13', lambda w: 'ph' in w,              lambda w: [w.replace('ph', 'f')],            0.70),
 ('R14', lambda w: re.search(f'[aeiou]ra[{C}]', w),
         lambda w: [re.sub(f'(?<=[aeiou])ra([{C}])', r'r\1', w)],                       0.75),
 ('R15', lambda w: re.search('[msn]ar[aeiou]', w),
         lambda w: [re.sub('([msn])a(r[aeiou])', r'\1\2', w)],                          0.70),
]

def expand(canonical):
    """BFS depth 3 (wahiguru = v→w + aa→a + oo→u); returns {variant: best_score}."""
    found = {}
    frontier = [(canonical, 1.0, 0)]
    for depth in (1, 2, 3):
        nxt = []
        for w, score, _ in frontier:
            for rid, applies, fn, wt in RULES:
                if not applies(w): continue
                for v in fn(w):
                    s = score * wt
                    if v != canonical and (v not in found or found[v] < s):
                        found[v] = s
                        nxt.append((v, s, depth))
        frontier = nxt
    return found

# ---------------------------------------------------------------- build table
cur.executescript('''
DROP TABLE IF EXISTS variants;
CREATE TABLE variants(variant TEXT, gurmukhi TEXT, translit TEXT,
                      freq INT, score REAL);
''')
rows, purged = [], collections.Counter()
for g, tr in canon.items():
    fr = freq_g[g]
    cands = sorted(expand(tr).items(), key=lambda kv: -kv[1])
    kept = 0
    for v, s in cands:
        if kept >= 15: break                                   # reviewer change #5
        if len(v) < 2 or not v.isalnum(): purged['form'] += 1; continue
        if v in veto: purged['english'] += 1; continue
        if v in canonical_set: purged['canonical'] += 1; continue   # reviewer change #4
        rows.append((v, g, tr, fr, s)); kept += 1
cur.executemany('INSERT INTO variants VALUES(?,?,?,?,?)', rows)
cur.execute('CREATE INDEX idx_var ON variants(variant)')
cur.execute("INSERT OR REPLACE INTO meta VALUES('variants', ?)", (str(len(rows)),))
con.commit()
print(f'variants: {len(rows)} | purged: {dict(purged)}')
for probe in ('gyan', 'wahiguru', 'kartaa', 'kirtan', 'amrit', 'simran', 'hukum'):
    hits = cur.execute('SELECT translit, freq FROM variants WHERE variant=? '
                       'ORDER BY freq*score DESC LIMIT 3', (probe,)).fetchall()
    print(f'  {probe:10s} ->', hits)
con.close()
