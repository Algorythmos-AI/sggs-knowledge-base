# -*- coding: utf-8 -*-
"""Chaos-QA scoring harness. Reads attack files (JSONL: {agent, behavior, query,
canonical_translit, canonical_ang}), fires each query at the live /api/search,
PASS iff a top-3 result is the canonical line (translit match, ang ±1).

Usage: python3 chaos_harness.py <attacks_glob> <results_out.jsonl>
"""
import sys, json, glob, urllib.request, urllib.parse, time

API = 'http://127.0.0.1:7777/api/search?q={}&limit=3'

def norm(s): return ' '.join((s or '').lower().split())

attacks = []
for f in sorted(glob.glob(sys.argv[1])):
    for raw in open(f, encoding='utf-8'):
        raw = raw.strip()
        if raw:
            try: attacks.append(json.loads(raw))
            except json.JSONDecodeError: pass

out = open(sys.argv[2], 'w', encoding='utf-8')
stats = {}
t0 = time.time()
for a in attacks:
    q = a['query']
    try:
        with urllib.request.urlopen(API.format(urllib.parse.quote(q)), timeout=15) as r:
            d = json.loads(r.read().decode())
        res = d.get('results', [])
        want = norm(a['canonical_translit'])
        ok = any(norm(x.get('translit')) == want or
                 (want in norm(x.get('translit')) and abs(x.get('ang', -9) - a.get('canonical_ang', -1)) <= 1)
                 for x in res)
        mode = d.get('mode', '?')
    except Exception as e:
        ok, mode = False, f'ERROR:{e}'
    b = a.get('behavior', '?')
    s = stats.setdefault(b, [0, 0])
    s[0] += ok; s[1] += 1
    out.write(json.dumps({**a, 'pass': bool(ok), 'mode': mode}, ensure_ascii=False) + '\n')
out.close()

tot_p = sum(s[0] for s in stats.values()); tot_n = sum(s[1] for s in stats.values())
print(f'TOTAL: {tot_p}/{tot_n} pass ({100*tot_p/max(tot_n,1):.0f}%) in {time.time()-t0:.0f}s')
for b in sorted(stats):
    p, n = stats[b]
    print(f'  {b:28s} {p:2d}/{n}')
