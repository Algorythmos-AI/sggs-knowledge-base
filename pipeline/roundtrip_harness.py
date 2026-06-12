#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Full-corpus round-trip precision harness.

For every (or a sampled / Ang-ranged subset of) corpus line, type the line's OWN
reader-transliteration as a search query and check whether the search returns that
line (or an identical-gurmukhi line) at rank #1 / within top-3. This is the
objective "does every line in SGGS resolve when a user types it" metric.

Runs do_search IN-PROCESS (no HTTP) for speed. Buckets failures by comp_type and
Ang range so fixes can be targeted. Writes per-line JSONL and prints a summary.

Usage:
  python3 pipeline/roundtrip_harness.py [--sample N] [--start-ang A] [--end-ang B]
                                        [--max-words W] [--out FILE]
"""
import argparse, json, os, random, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, 'webapp'))
import serve                                   # noqa: E402
serve.DB = os.path.join(ROOT, 'db', 'sggs.sqlite')
import sqlite3                                  # noqa: E402


def load_lines(con, start_ang, end_ang):
    cur = con.execute(
        "SELECT id, ang, comp_type, author, gurmukhi, translit FROM lines "
        "WHERE is_header = 0 AND translit IS NOT NULL AND translit != '' "
        "AND ang BETWEEN ? AND ? ORDER BY id", (start_ang, end_ang))
    return [dict(id=r[0], ang=r[1], comp_type=r[2] or '', author=r[3] or '',
                 gurmukhi=r[4], translit=r[5]) for r in cur.fetchall()]


def ang_bucket(a):
    return f"{((a - 1) // 100) * 100 + 1}-{((a - 1) // 100) * 100 + 100}"


def perturb_word(w):
    """Simulate casual modern Hindi/Punjabi romanization of a canonical reader word:
    verb perfective endings (-io/-iaa -> -ya), long vowels shortened, -ai -> -e."""
    if len(w) > 3:
        if w.endswith('io'):    w = w[:-2] + 'ya'
        elif w.endswith('iaa'): w = w[:-3] + 'ya'
        elif w.endswith('aa'):  w = w[:-2] + 'a'
        elif w.endswith('ai'):  w = w[:-2] + 'e'
    return w.replace('oo', 'u').replace('ee', 'i')


def perturb_query(translit, max_words):
    return ' '.join(perturb_word(w) for w in translit.split()[:max_words])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--sample', type=int, default=0, help='random sample size (0=all)')
    ap.add_argument('--start-ang', type=int, default=1)
    ap.add_argument('--end-ang', type=int, default=1430)
    ap.add_argument('--max-words', type=int, default=10, help='cap query length (user types a line, not always whole)')
    ap.add_argument('--seed', type=int, default=42)
    ap.add_argument('--perturb', action='store_true', help='simulate casual modern romanization')
    ap.add_argument('--out', default=os.path.join(ROOT, 'validation', 'roundtrip_results.jsonl'))
    ap.add_argument('--show-fails', type=int, default=25)
    args = ap.parse_args()

    con = sqlite3.connect(serve.DB)
    # identical-gurmukhi groups: a duplicated phrase legitimately resolves to any copy
    dup = {}
    for gid, n in con.execute("SELECT gurmukhi, COUNT(*) FROM lines WHERE is_header=0 GROUP BY gurmukhi"):
        dup[gid] = n

    lines = load_lines(con, args.start_ang, args.end_ang)
    if args.sample and args.sample < len(lines):
        random.seed(args.seed)
        lines = random.sample(lines, args.sample)

    p1 = p3 = miss = 0
    by_ct = {}      # comp_type -> [p1, total]
    by_ang = {}     # ang bucket -> [p1, total]
    fails = []
    t0 = time.time()
    out = open(args.out, 'w')
    for i, ln in enumerate(lines):
        if args.perturb:
            q = perturb_query(ln['translit'], args.max_words)
        else:
            q = ' '.join(ln['translit'].split()[:args.max_words])
        try:
            res = serve.do_search(q, 'auto', 5, 0)['results']
        except Exception as e:
            res = []
        rank = 0
        for idx, r in enumerate(res):
            if r['id'] == ln['id'] or r['gurmukhi'] == ln['gurmukhi']:
                rank = idx + 1
                break
        ok1, ok3 = rank == 1, (1 <= rank <= 3)
        p1 += ok1; p3 += ok3; miss += (rank == 0)
        ct = ln['comp_type'] or 'other'
        by_ct.setdefault(ct, [0, 0]); by_ct[ct][0] += ok1; by_ct[ct][1] += 1
        ab = ang_bucket(ln['ang'])
        by_ang.setdefault(ab, [0, 0]); by_ang[ab][0] += ok1; by_ang[ab][1] += 1
        rec = dict(id=ln['id'], ang=ln['ang'], comp_type=ct, rank=rank,
                   q=q, gurmukhi=ln['gurmukhi'][:60])
        out.write(json.dumps(rec, ensure_ascii=False) + '\n')
        if rank != 1 and len(fails) < 5000:
            fails.append(rec)
    out.close()
    n = len(lines)
    dt = time.time() - t0
    print(f"\n==== ROUND-TRIP over {n} lines (Ang {args.start_ang}-{args.end_ang}"
          f"{', sample' if args.sample else ''}) in {dt:.0f}s ====")
    print(f"  pass@1: {p1}/{n} ({100*p1/n:.1f}%)   pass@3: {p3}/{n} ({100*p3/n:.1f}%)   miss(>3): {miss} ({100*miss/n:.1f}%)")
    print("\n  by comp_type (pass@1):")
    for ct, (a, b) in sorted(by_ct.items(), key=lambda kv: -kv[1][1]):
        print(f"    {ct:14s} {a:5d}/{b:5d}  {100*a/b:5.1f}%")
    print("\n  weakest Ang buckets (pass@1):")
    worst = sorted(by_ang.items(), key=lambda kv: (kv[1][0]/kv[1][1]))[:8]
    for ab, (a, b) in worst:
        print(f"    Ang {ab:9s} {a:4d}/{b:4d}  {100*a/b:5.1f}%")
    print(f"\n  sample non-#1 (showing {min(args.show_fails, len(fails))} of {len(fails)}):")
    for f in fails[:args.show_fails]:
        print(f"    rank={f['rank']} Ang{f['ang']} [{f['comp_type']}] {f['gurmukhi']}  <=  {f['q'][:50]}")


if __name__ == '__main__':
    main()
