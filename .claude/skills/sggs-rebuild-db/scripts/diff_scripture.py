#!/usr/bin/env python3
"""
diff_scripture.py OLD.sqlite NEW.sqlite [--allow COL ...]
Byte-level proof for a rebuild: same row count and ids, and every `lines` column not in
--allow identical for every id. Scripture columns can never be allowed.
Exit 0 = only allowed columns changed; 1 = anything else changed.
"""
import argparse, sqlite3, sys
from collections import Counter

NEVER = {"id", "gurmukhi", "text", "ang"}

def rows(path):
    con = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    cols = [r[1] for r in con.execute("PRAGMA table_info(lines)")]
    data = {r[0]: r for r in con.execute(f"SELECT {','.join(['id'] + [c for c in cols if c != 'id'])} FROM lines")}
    con.close()
    return ['id'] + [c for c in cols if c != 'id'], data

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("old"); ap.add_argument("new")
    ap.add_argument("--allow", nargs="*", default=[])
    a = ap.parse_args()
    bad_allow = NEVER & set(a.allow)
    if bad_allow:
        print(f"FAIL: scripture columns can never be allowed to change: {sorted(bad_allow)}"); return 1
    ocols, old = rows(a.old); ncols, new = rows(a.new)
    fails = []
    if ocols != ncols: fails.append(f"schema differs: {sorted(set(ocols) ^ set(ncols))}")
    if len(old) != len(new): fails.append(f"row count {len(old)} -> {len(new)}")
    if set(old) != set(new): fails.append(f"id sets differ ({len(set(old) ^ set(new))} ids)")
    changed = Counter(); samples = {}
    for i in sorted(set(old) & set(new)):
        for k, c in enumerate(ocols):
            if k < len(new[i]) and old[i][k] != new[i][k]:
                changed[c] += 1; samples.setdefault(c, i)
    print(f"rows: {len(old)} -> {len(new)}")
    for c, n in sorted(changed.items()):
        tag = "allowed" if c in a.allow else "NOT ALLOWED"
        print(f"  {c:18s} changed in {n:6d} rows ({tag}; e.g. id {samples[c]})")
        if c not in a.allow: fails.append(f"{c} changed in {n} rows")
    if not changed: print("  no column changed")
    if fails:
        print("RESULT: FAIL — " + "; ".join(fails)); return 1
    print("RESULT: PASS — only allowed columns changed; scripture byte-identical"); return 0

if __name__ == "__main__":
    sys.exit(main())
