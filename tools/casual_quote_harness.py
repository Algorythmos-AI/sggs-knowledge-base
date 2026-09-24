#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Casual-quote precision harness — the "user recalls a LINE and types it the modern way".

This is the corpus-wide measurement of the class that produced the `jamuna ka kul khel
kelio` bug (v2.0.5): a user types a contiguous FRAGMENT of a line, modernising the
Gurbani function words (ਕੈ kai -> ka, ਕੀ kee -> ki), dropping aspirates (khelio ->
kelio), and shortening long vowels (kool -> kul). For a sample of real lines we take the
first ~6 words, casualise them, search, and check the true line is returned top-1 / top-3.

Complements roundtrip_harness.py: that types a line's *own* (or lightly perturbed)
transliteration; THIS one specifically stresses the modern-postposition + dropped-aspirate
fragment-quote pattern, which is how seekers actually half-remember a verse.

Runs do_search IN-PROCESS (no HTTP). Usage:
  python3 tools/casual_quote_harness.py [--sample N] [--seed S] [--words W] [--show-fails K]
"""
import argparse, json, os, random, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, 'webapp'))
import serve                                   # noqa: E402
serve.DB = os.path.join(ROOT, 'db', 'sggs.sqlite')

# aspirated digraphs a casual typist drops the 'h' from (longest first)
_ASP = [('chh', 'ch'), ('kh', 'k'), ('gh', 'g'), ('jh', 'j'),
        ('th', 't'), ('dh', 'd'), ('ph', 'p'), ('bh', 'b')]
_PREP = {'kai': 'ka', 'kee': 'ki', 'kau': 'ko'}   # Gurbani postposition -> modern colloquial


def casualise(word):
    if word in _PREP:
        return _PREP[word]
    w = word
    for a, b in _ASP:                # drop the first aspirate
        if a in w:
            w = w.replace(a, b, 1)
            break
    if 'oo' in w:                    # shorten one long vowel
        w = w.replace('oo', 'u', 1)
    elif 'ee' in word:
        w = w.replace('ee', 'i', 1)
    return w


def casual_quote(translit, nwords):
    return ' '.join(casualise(w) for w in translit.split()[:nwords])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--sample', type=int, default=600)
    ap.add_argument('--seed', type=int, default=7)
    ap.add_argument('--words', type=int, default=6, help='leading words of the line to quote')
    ap.add_argument('--show-fails', type=int, default=20)
    ap.add_argument('--out', default=os.path.join(ROOT, 'qa', 'results', 'casual_quote_results.jsonl'))
    args = ap.parse_args()

    serve.HAVE_FTS = serve.have_fts()
    rows = [dict(r) for r in serve.db().execute(
        "SELECT id, ang, comp_type, gurmukhi, translit FROM lines WHERE is_header=0 "
        "AND translit IS NOT NULL "
        "AND length(translit)-length(replace(translit,' ',''))>=4 ORDER BY id")]
    random.seed(args.seed)
    samp = random.sample(rows, min(args.sample, len(rows)))

    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)

    out = open(args.out, 'w', encoding='utf-8')
    p1 = p3 = n = 0
    fails = []
    t0 = time.time()
    for ln in samp:
        q = casual_quote(ln['translit'], args.words)
        if len(q.split()) < 3:
            continue
        n += 1
        d = serve.do_search(q, 'auto', 3, 0)
        res = d.get('results', [])[:3]
        ranks = [i + 1 for i, r in enumerate(res) if r.get('gurmukhi') == ln['gurmukhi']]
        rank = ranks[0] if ranks else 0
        if rank == 1:
            p1 += 1; p3 += 1
        elif rank in (2, 3):
            p3 += 1
        else:
            fails.append((ln['ang'], q, ln['translit'][:55], d.get('mode'), [r['ang'] for r in res]))
        out.write(json.dumps({'ang': ln['ang'], 'query': q, 'rank': rank,
                              'mode': d.get('mode')}, ensure_ascii=False) + '\n')
    out.close()
    print(f"==== CASUAL-QUOTE over {n} lines (sample, seed {args.seed}) in {time.time()-t0:.0f}s ====")
    print(f"  pass@1 {p1}/{n} = {100*p1/max(n,1):.1f}%   pass@3 {p3}/{n} = {100*p3/max(n,1):.1f}%   fails {len(fails)}")
    if fails:
        print(f"\n  sample fails (showing {min(args.show_fails, len(fails))}):")
        for f in fails[:args.show_fails]:
            print(f"    Ang{f[0]} | {f[1]!r} | true: {f[2]} | {f[3]} | got {f[4]}")


if __name__ == '__main__':
    main()
