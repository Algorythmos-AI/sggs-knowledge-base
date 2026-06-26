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


def main():
    db_hash = sha256(DB) if os.path.exists(DB) else None
    rn = roman_norm_vectors()
    dl = difflib_vectors()
    p1, n1 = write_ndjson('golden_roman_norm.ndjson', rn)
    p2, n2 = write_ndjson('golden_difflib.ndjson', dl)
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
        },
    }
    with open(os.path.join(OUT, '_meta.json'), 'w', encoding='utf-8') as f:
        json.dump(meta, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write('\n')
    print(f'roman_norm vectors: {n1}  -> {p1}')
    print(f'difflib   vectors: {n2}  -> {p2}')
    print(f'db_sha256={db_hash}  python={meta["tool_versions"]["python"]}  sqlite={meta["tool_versions"]["sqlite"]}')


if __name__ == '__main__':
    main()
