#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gen_golden_vectors.py — emit the CANONICAL cross-platform fidelity contract.

The search/verify logic in webapp/serve.py + webapp/verify.py is the source of truth.
This script drives the REAL functions and records their exact outputs as golden vectors
under ../contract/, which the Swift GurbaniSearchKit tests (and a future Android port)
assert against byte-for-byte. CI must fail if `git diff --exit-code contract/` is dirty
after running this — i.e. any change to the fold/waterfall/verify must regenerate here.

v1 scope of this generator (the pure, DB-independent fidelity core):
  contract/golden_roman_norm.ndjson   — roman_norm(input) -> output
  contract/golden_difflib.ndjson      — difflib.SequenceMatcher(None,a,b).ratio() (repr-exact)
  contract/_meta.json                 — tool versions + db_sha256 the vectors were built against

Later phases extend this with the full do_search waterfall + verify verdicts (needs the DB).

Usage:  python3 pipeline/gen_golden_vectors.py [path-to-db]   (default: db/sggs.sqlite)
"""
import os, sys, json, sqlite3, hashlib, difflib, platform

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, 'webapp'))
import serve  # noqa: E402  -- the source of truth for roman_norm

DB = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'db', 'sggs.sqlite')
OUT = os.path.join(ROOT, 'contract')
os.makedirs(OUT, exist_ok=True)


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def write_ndjson(name, records):
    path = os.path.join(OUT, name)
    with open(path, 'w', encoding='utf-8') as f:
        for r in records:
            f.write(json.dumps(r, ensure_ascii=False, sort_keys=True) + '\n')
    return path, len(records)


# ---------------------------------------------------------------------------
# 1. roman_norm vectors — real corpus translit tokens + curated edge cases
# ---------------------------------------------------------------------------
def roman_norm_vectors():
    inputs = []
    # curated examples straight from the docstring + known equivalences
    curated = [
        'waheguru', 'vaahiguroo', 'yashoda', 'jasodaa', 'krishna', 'krisan', 'gyan', 'giaan',
        'satnam', 'sat naam', 'satinaam', 'oopar', 'upar', 'ootam', 'utam', 'tumh', 'tum',
        'cheenhe', 'chine', 'bhakti', 'bhagatee', 'waheguroo', 'gobind', 'gobinda',
        'hari', 'har', 'raam', 'ram', 'naam', 'nam', 'sahib', 'saheb', 'ji', 'jee',
        # single chars + empties + casing + punctuation-ish
        'a', 'e', 'i', 'o', 'u', 'y', 'w', 'z', 'q', 'x', 'f', 'WAHEGURU', 'WaHeGuRu',
        'sh', 'chh', 'ch', 'kh', 'gh', 'jh', 'th', 'dh', 'bh', 'ph', 'rh',
        'yyy', 'aaa', 'aeiou', 'bbbb', 'sshh', 'multi word token here', '   spaced   ',
    ]
    inputs.extend(curated)
    # real distinct translit tokens from the corpus (deterministic order)
    try:
        con = sqlite3.connect(f'file:{DB}?mode=ro&immutable=1', uri=True)
        rows = con.execute("SELECT translit FROM lines WHERE translit IS NOT NULL AND translit<>''").fetchall()
        con.close()
        seen = set()
        toks = []
        for (t,) in rows:
            for w in str(t).split():
                if w not in seen:
                    seen.add(w); toks.append(w)
        toks.sort()  # determinism
        inputs.extend(toks)
    except Exception as e:
        print(f'  (warning: could not read corpus translit tokens: {e})', file=sys.stderr)
    # de-dup while preserving the curated-first order, then a stable sort tail already sorted
    seen, uniq = set(), []
    for s in inputs:
        if s not in seen:
            seen.add(s); uniq.append(s)
    return [{'input': s, 'output': serve.roman_norm(s)} for s in uniq]


# ---------------------------------------------------------------------------
# 2. difflib vectors — the LCS-ratio that verify.py + blob_search depend on.
#    Record ratio as Python repr (full 17-sig-fig double) for bit-exact Swift assert.
# ---------------------------------------------------------------------------
def difflib_vectors():
    pairs = []

    def add(a, b):
        pairs.append((a, b))

    # degenerate
    add('', ''); add('', 'a'); add('a', ''); add('a', 'a'); add('a', 'b')
    # repeats / rolling window
    add('aaaa', 'aa'); add('aa', 'aaaa'); add('aaaaa', 'aaab'); add('abab', 'ab')
    add('abxab', 'ab'); add('abcabc', 'abc'); add('xabcx', 'abc')
    # tie cases (earliest-in-a / earliest-in-b)
    add('abxab', 'abyab'); add('aXbXc', 'abc'); add('1234512345', '12345')
    # autojunk cliff: b length 199 / 200 / 201 with a popular element
    for n in (199, 200, 201):
        b = ('q' * (n - 5)) + 'abcde'        # 'q' is popular when n>=200
        add('qqabc', b)
        add('abcde', b)
    # realistic roman-norm-style folds (what verify scores)
    add('vhgr', 'vhgr'); add('vhgr', 'vhgrnm'); add('sdnm', 'sdnmgrd'); add('jsd', 'jsdkrsn')
    # unicode / Gurmukhi (verify gurmukhi path compares cleaned gurmukhi strings)
    add('ਨਾਮੁ', 'ਨਾਮੁ'); add('ਨਾਮੁ', 'ਹਰਿ ਨਾਮੁ'); add('ਸਤਿ ਨਾਮੁ', 'ਸਤਿ ਨਾਮੁ ਕਰਤਾ')
    add('ੴ', 'ੴ ਸਤਿ ਨਾਮੁ')
    # NFC vs NFD of the same Gurmukhi (must be supplied normalized; record both raw)
    import unicodedata
    g = 'ਸਤਿ ਨਾਮੁ'
    add(unicodedata.normalize('NFC', g), unicodedata.normalize('NFD', g))
    # rounding boundary probes (ratios near the verdict thresholds 0.95/0.85/0.80)
    add('abcdefghij', 'abcdefghix')   # 0.9
    add('abcdefghijklmnopqrs', 'abcdefghijklmnopqrx')

    # real corpus line pairs incl. >200-char passages (autojunk genuinely fires on b)
    try:
        con = sqlite3.connect(f'file:{DB}?mode=ro&immutable=1', uri=True)
        lines = con.execute(
            "SELECT gurmukhi FROM lines WHERE is_header=0 AND gurmukhi<>'' ORDER BY id LIMIT 40"
        ).fetchall()
        con.close()
        gs = [r[0] for r in lines]
        for i in range(0, min(len(gs), 30), 2):
            add(gs[i], gs[i + 1] if i + 1 < len(gs) else gs[i])
        # a long (>200 char) concatenation as side b
        longb = ' '.join(gs)[:260]
        add(gs[0], longb)
        add('ਨਾਮੁ', longb)
    except Exception as e:
        print(f'  (warning: could not read corpus lines: {e})', file=sys.stderr)

    out = []
    seen = set()
    for a, b in pairs:
        key = (a, b)
        if key in seen:
            continue
        seen.add(key)
        r = difflib.SequenceMatcher(None, a, b).ratio()       # default autojunk=True, isjunk=None
        out.append({'a': a, 'b': b, 'ratio': repr(r), 'round4': repr(round(r, 4))})
    return out


# ---------------------------------------------------------------------------
# 3. verify vectors — drive the REAL verify engine (webapp/verify.py) against the
#    shipped DB and record the full verdict. Covers every verdict + adversarial input.
# ---------------------------------------------------------------------------
def verify_vectors():
    # (claim, ang)
    claims = [
        ("ਸੋਚੈ ਸੋਚਿ ਨ ਹੋਵਈ ਜੇ ਸੋਚੀ ਲਖ ਵਾਰ", None),       # exact Gurmukhi
        ("ਸੋਚੈ ਸੋਚਿ ਨ ਹੋਵਈ ਜੇ ਸੋਚੀ ਲਖ ਵਾਰ", 1),          # exact + ANG_MATCH
        ("ਸੋਚੈ ਸੋਚਿ ਨ ਹੋਵਈ ਜੇ ਸੋਚੀ ਲਖ ਵਾਰ", 999),        # exact + ANG_MISMATCH
        ("ਸੋਚੇ ਸੋਚ ਨ ਹੋਵਈ ਜੇ ਸੋਚੀ ਲਖ ਵਾਰ", None),         # misspelled Gurmukhi
        ("ਆਦਿ ਸਚੁ ਜੁਗਾਦਿ ਸਚੁ", None),                        # fragment of a longer line
        ("pavan guroo paanee pitaa maataa dharat mahat", None),  # roman exact-ish
        ("pavan guru pani pita mata dharti mahat", None),        # roman misremembered
        ("satgur kirpa", None),                                   # short roman
        ("ਨਾਨਕ ਸੋਨੇ ਦੀ ਚਿੜੀਆ ਉਡ ਗਈ", None),                 # fabricated -> NOT_FOUND
        ("ਨਾਨਕ ਨਾਮ ਚੜ੍ਹਦੀ ਕਲਾ", None),                       # ardas, not in SGGS -> NOT_FOUND
        ("waheguru", None),                                       # single roman token
        ("ੴ ਸਤਿ ਨਾਮੁ", None),                                  # Mool Mantar fragment
        # adversarial (must not crash; v2.11 FTS hardening)
        ('naam"test', None), ('naam*', None), ('"', None), ('***', None), ('।॥', None), ('', None),
    ]
    out = []
    for claim, ang in claims:
        v = serve.verify_claim(claim, ang=ang, db_path=DB)
        dd = v.get('distance_details', {})
        out.append({
            'claim': claim, 'ang': ang,
            'verdict': v.get('verdict'),
            'confidence': repr(v.get('confidence')),
            'matched_line_id': v.get('matched_line_id'),
            'ang_actual': v.get('ang'),
            'best_ratio': repr(dd.get('best_ratio')) if 'best_ratio' in dd else None,
            'second_ratio': repr(dd.get('second_ratio')) if 'second_ratio' in dd else None,
            'gap': repr(dd.get('gap')) if 'gap' in dd else None,
            'candidates_scored': dd.get('candidates_scored'),
            'note': dd.get('note'),
        })
    return out


# ---------------------------------------------------------------------------
# 4. search vectors — drive the REAL do_search for the EXPLICIT modes (the auto
#    waterfall's exotic fallback tiers are ported in a later phase). Records the
#    ordered result line-ids + the resolved 'used' mode (+ concept / related_themes).
# ---------------------------------------------------------------------------
def search_vectors():
    serve.DB = DB
    serve.HAVE_FTS = None  # force re-probe against this DB
    cases = [
        ('ਨਾਮੁ', 'gurmukhi'), ('ਸਤਿ ਨਾਮੁ', 'gurmukhi'), ('ਹਰਿ ਹਰਿ', 'gurmukhi'),
        ('ਸੋਚੈ ਸੋਚਿ', 'gurmukhi'), ('ਆਦਿ ਸਚੁ', 'gurmukhi'),
        ('naam', 'roman'), ('satgur', 'roman'), ('waheguru', 'roman'),
        ('har har', 'roman'), ('gobind', 'roman'), ('saadh sangat', 'roman'),
        ('ਸ ਨ ਕ', 'first'), ('s n k', 'first'), ('dh dh r g', 'first'),
        ('naam', 'theme'), ('hukam', 'theme'), ('haumai', 'theme'), ('simran', 'theme'),
        ('', 'gurmukhi'), ('   ॥  ', 'gurmukhi'),   # empty / punctuation-only
        # --- auto mode: exercise the waterfall tiers ---
        ('ਨਾਮੁ', 'auto'), ('ਸਤਿ ਨਾਮੁ', 'auto'), ('ਸ ਨ ਕ', 'auto'),    # gurmukhi text / single-letter
        ('naam', 'auto'), ('gobind', 'auto'), ('har har', 'auto'),       # roman translit
        ('haumai', 'auto'), ('hukam', 'auto'),                            # concept-exact -> theme
        ('ego', 'auto'), ('mercy', 'auto'), ('peace', 'auto'),           # seeker lexicon (theme/translit)
        ('waheguru', 'auto'), ('satnam waheguru', 'auto'),               # lexicon translit / bigram
        ('darshan', 'auto'), ('seva', 'auto'),                           # lexicon anchors
        ('s n k', 'auto'), ('dh dh r g', 'auto'),                        # roman first-letters
        ('satgur kirpa', 'auto'),                                         # translit / fold
        ('ਨਾਮੁ simran', 'auto'),                                         # mixed-script
        # passage tier candidates (cross-line quotes; ≥3 tokens that fail earlier tiers)
        ('jeevat jo marai haan dutar so tarai haan', 'auto'),
        ('jeevat marai taa sabh kichh soojhai', 'auto'),
        ('nanak naam chardi kala tere bhaane sarbat da bhala', 'auto'),
        ('man toon jot saroop hai apnaa mool pachhaan', 'auto'),
    ]
    out = []
    for q, mode in cases:
        r = serve.do_search(q, mode, 50, 0)
        results = r.get('results', [])
        out.append({
            'query': q, 'mode': mode,
            'used': r.get('mode'),
            'result_ids': [x['id'] for x in results],
            'n': len(results),
            'concept': (r.get('concept') or {}).get('name') if r.get('concept') else None,
            'related_themes': r.get('related_themes'),
        })
    return out


# ---------------------------------------------------------------------------
# 5. reader vectors — plain endpoints: /api/ang + hukam_package (deterministic by seed)
# ---------------------------------------------------------------------------
def reader_vectors():
    serve.DB = DB
    serve.HAVE_FTS = None
    out = []
    for n in (1, 2, 8, 100, 1430):
        r = serve.api(f'/api/ang/{n}', {})
        out.append({'kind': 'ang', 'n': n,
                    'line_ids': [l['id'] for l in r['lines']],
                    'continued_from': r['continued_from'],
                    'raag': r['raag'], 'section': r['section'], 'authors': r['authors']})
    for seed in (1, 5, 100, 400, 405, 1000, 1500):
        try:
            h = serve.hukam_package(seed=seed)
            out.append({'kind': 'hukam', 'seed': seed, 'comp_id': h['comp_id'],
                        'comp_ids': h['comp_ids'], 'line_ids': [l['id'] for l in h['lines']]})
        except Exception as e:
            out.append({'kind': 'hukam', 'seed': seed, 'error': type(e).__name__})
    for lid in (5, 100, 1000, 5000, 50000):
        r = serve.api('/api/neighbors', {'line_id': [str(lid)], 'limit': ['12']})
        out.append({'kind': 'neighbors', 'line_id': lid, 'level': r['level'],
                    'source': r.get('source'),
                    'neighbor_ids': [n.get('id', n.get('comp_id')) for n in r['neighbors']],
                    'scores': [round(n['score'], 6) for n in r['neighbors']]})
    # analytics (Insight Engine): author/raag lists + theme co-occurrence network
    av = serve.api('/api/analytics/author', {})['authors']
    out.append({'kind': 'authors', 'names': [a['author'] for a in av],
                'n_lines': [a['n_lines'] for a in av], 'mattr': [round(a['mattr_100'], 4) for a in av]})
    rv2 = serve.api('/api/analytics/raag', {})['raags']
    out.append({'kind': 'raags', 'names': [r['raag'] for r in rv2], 'n_lines': [r['n_lines'] for r in rv2]})
    tn = serve.api('/api/themes/network', {'min_ppmi': ['0.7'], 'limit': ['40']})['edges']
    out.append({'kind': 'theme_net', 'pairs': [f"{e['source']}~{e['target']}" for e in tn],
                'ppmi': [round(e['ppmi'], 6) for e in tn]})
    for con in ('naam', 'hukam', 'seva'):
        r = serve.api('/api/analytics/constellation', {'concept': [con]})
        top = r['clusters'][0]['verses'] if r.get('clusters') else []
        out.append({'kind': 'constellation', 'concept': con, 'total': r['total'],
                    'cluster_cos': [c['co'] for c in r.get('clusters', [])],
                    'cluster_ns': [c['n'] for c in r.get('clusters', [])],
                    'top_verse_ids': [v['id'] for v in top]})
    return out


def main():
    db_hash = sha256(DB) if os.path.exists(DB) else None
    rn = roman_norm_vectors()
    dl = difflib_vectors()
    vv = verify_vectors()
    sv = search_vectors()
    rv = reader_vectors()
    p1, n1 = write_ndjson('golden_roman_norm.ndjson', rn)
    p2, n2 = write_ndjson('golden_difflib.ndjson', dl)
    p3, n3 = write_ndjson('golden_verify.ndjson', vv)
    p4, n4 = write_ndjson('golden_search.ndjson', sv)
    p5, n5 = write_ndjson('golden_reader.ndjson', rv)
    meta = {
        'generator': 'pipeline/gen_golden_vectors.py',
        'db_sha256': db_hash,
        'tool_versions': {
            'python': platform.python_version(),
            'sqlite': sqlite3.sqlite_version,
        },
        'files': {
            'golden_roman_norm.ndjson': n1,
            'golden_difflib.ndjson': n2,
            'golden_verify.ndjson': n3,
            'golden_search.ndjson': n4,
            'golden_reader.ndjson': n5,
        },
    }
    with open(os.path.join(OUT, '_meta.json'), 'w', encoding='utf-8') as f:
        json.dump(meta, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write('\n')
    print(f'roman_norm vectors: {n1}  -> {p1}')
    print(f'difflib   vectors: {n2}  -> {p2}')
    print(f'verify    vectors: {n3}  -> {p3}')
    print(f'search    vectors: {n4}  -> {p4}')
    print(f'reader    vectors: {n5}  -> {p5}')
    print(f'db_sha256={db_hash}  python={meta["tool_versions"]["python"]}  sqlite={meta["tool_versions"]["sqlite"]}')


if __name__ == '__main__':
    main()
