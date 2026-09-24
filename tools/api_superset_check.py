#!/usr/bin/env python3
"""
api_superset_check.py — integration proof that the shabad sheet now serves the
title heading, that no shabad lost a line, and that a gap comp_id 404s.

For every composition in the NEW db, /api/shabad/{comp_id} must return exactly the
db's lines for that comp (same ids, in order). Compositions that gained a heading
run (a header line before their first body line) are additionally asserted to lead
with that verbatim header. A comp_id that is a gap must return HTTP 404.

Usage:
  python3 tools/api_superset_check.py --db db/sggs.sqlite --url http://127.0.0.1:7777
  [--sample N]            check N random comps (default 400) + all regression comps
"""
import sys, json, argparse, random, sqlite3, urllib.error, urllib.request
from pathlib import Path


def connect_ro(db_path):
    """Read-only connection (the database is never written by a check)."""
    p = Path(db_path).resolve()
    if not p.exists():
        raise FileNotFoundError(f"database not found: {p}")
    con = sqlite3.connect(f"file:{p}?mode=ro", uri=True)
    con.execute("PRAGMA query_only=ON")
    return con

# Angs whose compositions open with a multi-header run (the regression set)
REGRESSION_ANGS = [712, 262, 343, 462, 475, 642]

def get(url):
    try:
        with urllib.request.urlopen(url, timeout=10) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, None

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--db', default='db/sggs.sqlite')
    ap.add_argument('--url', default='http://127.0.0.1:7777')
    ap.add_argument('--sample', type=int, default=400)
    args = ap.parse_args()
    base = args.url.rstrip('/')
    con = connect_ro(args.db)

    from collections import defaultdict
    comp_lines, comp_ang, first_is_header = {}, {}, {}
    rows = con.execute("SELECT id, comp_id, ang, is_header, gurmukhi FROM lines ORDER BY id").fetchall()
    tmp = defaultdict(list)
    for lid, cid, ang, ish, gm in rows:
        tmp[cid].append((lid, ish, gm, ang))
    for cid, ls in tmp.items():
        comp_lines[cid] = [x[0] for x in ls]
        comp_ang[cid] = ls[0][3]
        first_is_header[cid] = (ls[0][1] == 1, ls[0][2])
    all_comps = sorted(comp_lines)
    max_cid = all_comps[-1]
    gaps = [c for c in range(1, max_cid + 1) if c not in comp_lines]

    fails = []
    def check(cond, msg):
        if not cond:
            fails.append(msg); print("  FAIL " + msg)

    # regression comps: the comp on each regression Ang that has a header-run first line
    reg_comps = []
    for a in REGRESSION_ANGS:
        cands = [c for c in all_comps if comp_ang[c] == a and first_is_header[c][0]
                 and not first_is_header[c][1].startswith('ੴ')]
        reg_comps += cands[:2]

    random.seed(1)
    sample = set(reg_comps) | set(random.sample(all_comps, min(args.sample, len(all_comps))))
    print(f"checking {len(sample)} comps against {base} (+{min(3,len(gaps))} gaps)")
    for cid in sorted(sample):
        st, d = get(f"{base}/api/shabad/{cid}")
        if st != 200 or not d:
            check(False, f"comp {cid}: HTTP {st}"); continue
        ids = [l['id'] for l in d['lines']]
        check(ids == comp_lines[cid], f"comp {cid}: api lines {ids[:3]}… != db {comp_lines[cid][:3]}…")
        ish, gm = first_is_header[cid]
        if ish:
            check(d['lines'][0]['is_header'] == 1 and d['lines'][0]['gurmukhi'] == gm,
                  f"comp {cid} (ang {comp_ang[cid]}): sheet must lead with header {gm[:24]!r}")

    for g in gaps[:3]:
        st, _ = get(f"{base}/api/shabad/{g}")
        check(st == 404, f"gap comp {g}: expected 404, got {st}")

    # explicit: Ang 712 sheet leads with the Todi title
    todi = [c for c in all_comps if comp_ang[c] == 712 and first_is_header[c][1].startswith('ਟੋਡੀ ਮਹਲਾ ੫ ਘਰੁ ੨')]
    if todi:
        st, d = get(f"{base}/api/shabad/{todi[0]}")
        check(st == 200 and d['lines'][0]['gurmukhi'].startswith('ਟੋਡੀ ਮਹਲਾ ੫ ਘਰੁ ੨'),
              "Ang 712 sheet leads with 'ਟੋਡੀ ਮਹਲਾ ੫ ਘਰੁ ੨ ਚਉਪਦੇ'")
        print(f"  Ang 712 comp {todi[0]} first line: {d['lines'][0]['gurmukhi'] if d else '(none)'}")

    con.close()
    if fails:
        print(f"\nRESULT: FAIL — {len(fails)} issue(s)"); return 1
    print(f"\nRESULT: PASS — {len(sample)} comps serve their exact lines; headings present; gaps 404.")
    return 0

if __name__ == '__main__':
    sys.exit(main())
