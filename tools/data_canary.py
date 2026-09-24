#!/usr/bin/env python3
"""Data canary: does production serve exactly the scripture this repository pins?

The pinned database (dataset.lock.json → db/sggs.sqlite, installed by `make dataset`) is the
reference. For every origin given, the canary fetches a random sample of lines through
/api/lines and whole Angs through /api/ang/{n}, and compares what is served with the pinned
rows, byte for byte:

  /api/lines   id · ang · comp_id · gurmukhi · translit     (sample + first/last line)
  /api/ang/N   the exact set and order of line ids, and per line gurmukhi · comp_id ·
               is_header · line_no                           (random Angs + Ang 1, 712, 1430)

Any difference, missing line or unreachable origin is a failure (exit 1). Scripture is never
"close enough": a stale CDN copy, a wrong database behind the API or bit rot all fail here.

    python3 tools/data_canary.py --origin https://sggs-knowledge-base.onrender.com \\
        --origin https://gurbanisoul.com --sample 500 --angs 12

Stdlib only. The seed is printed so any failure can be replayed exactly (--seed).
"""
from __future__ import annotations

import argparse
import json
import random
import sqlite3
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LINE_FIELDS = ("id", "ang", "comp_id", "gurmukhi", "translit")
ANG_FIELDS = ("gurmukhi", "comp_id", "is_header", "line_no")
ANCHOR_ANGS = (1, 712, 1430)
BATCH = 300          # /api/lines serves at most 300 ids per request
RETRIES = 4


def connect(db: Path) -> sqlite3.Connection:
    con = sqlite3.connect(f"file:{db.resolve()}?mode=ro&immutable=1", uri=True)
    con.row_factory = sqlite3.Row
    return con


def get_json(url: str, timeout: int = 60):
    """GET with bounded retries: a cold start or a transient 5xx is not a data failure."""
    last = None
    for attempt in range(1, RETRIES + 1):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "sggs-data-canary",
                                                       "Cache-Control": "no-cache"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            last = e
            if e.code < 500 and e.code != 429:
                raise
        except (urllib.error.URLError, TimeoutError, ConnectionError) as e:
            last = e
        time.sleep(3 * attempt)
    raise RuntimeError(f"{url}: {last}")


def compare_lines(con, origin: str, ids: list[int], fetch=get_json) -> list[str]:
    want = {r["id"]: r for r in con.execute(
        f"SELECT {', '.join(LINE_FIELDS)} FROM lines WHERE id IN ({','.join('?' * len(ids))})", ids)}
    problems = []
    for i in range(0, len(ids), BATCH):
        chunk = ids[i:i + BATCH]
        got = {r["id"]: r for r in fetch(f"{origin}/api/lines?ids={','.join(map(str, chunk))}").get("lines", [])}
        for lid in chunk:
            if lid not in got:
                problems.append(f"{origin} line {lid}: not served")
                continue
            for f in LINE_FIELDS:
                if got[lid].get(f) != want[lid][f]:
                    problems.append(f"{origin} line {lid}: {f} differs from the pinned database")
    return problems


def compare_ang(con, origin: str, ang: int, fetch=get_json) -> list[str]:
    want = con.execute(f"SELECT id, {', '.join(ANG_FIELDS)} FROM lines WHERE ang = ? ORDER BY id",
                       (ang,)).fetchall()
    got = fetch(f"{origin}/api/ang/{ang}").get("lines", [])
    if [r["id"] for r in got] != [r["id"] for r in want]:
        return [f"{origin} Ang {ang}: served {len(got)} lines, pinned {len(want)} (ids or order differ)"]
    problems = []
    for g, w in zip(got, want):
        for f in ANG_FIELDS:
            gv, wv = g.get(f), w[f]
            if f == "is_header":
                gv, wv = bool(gv), bool(wv)
            if gv != wv:
                problems.append(f"{origin} Ang {ang} line {w['id']}: {f} differs from the pinned database")
    return problems


def run(db: Path, origins: list[str], sample: int, n_angs: int, seed: int, fetch=get_json) -> list[str]:
    con = connect(db)
    all_ids = [r[0] for r in con.execute("SELECT id FROM lines ORDER BY id")]
    rng = random.Random(seed)
    ids = sorted(set(rng.sample(all_ids, min(sample, len(all_ids))) + [all_ids[0], all_ids[-1]]))
    angs = sorted(set(rng.sample(range(1, 1431), n_angs)) | set(ANCHOR_ANGS))
    problems = []
    for origin in origins:
        origin = origin.rstrip("/")
        try:
            problems += compare_lines(con, origin, ids, fetch)
            for ang in angs:
                problems += compare_ang(con, origin, ang, fetch)
        except Exception as e:           # unreachable is a failure too, reported per origin
            problems.append(f"{origin}: {e}")
    print(f"data canary: seed {seed} · {len(ids)} lines + {len(angs)} Angs × {len(origins)} origin(s)")
    return problems


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--db", type=Path, default=ROOT / "db" / "sggs.sqlite")
    ap.add_argument("--origin", action="append", required=True, help="repeat for each origin to check")
    ap.add_argument("--sample", type=int, default=500)
    ap.add_argument("--angs", type=int, default=12)
    ap.add_argument("--seed", type=int, default=None)
    a = ap.parse_args(argv)
    seed = a.seed if a.seed is not None else int(time.time())
    problems = run(a.db, a.origin, a.sample, a.angs, seed)
    for p in problems[:50]:
        print(f"::error::{p}")
    if problems:
        print(f"RESULT: FAIL — {len(problems)} difference(s); replay with --seed {seed}")
        return 1
    print("RESULT: PASS — every sampled line and Ang is byte-identical to the pinned database")
    return 0


if __name__ == "__main__":
    sys.exit(main())
