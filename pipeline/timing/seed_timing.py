#!/usr/bin/env python3
"""
Idempotent seed loader for raag timing claims.

Reads pipeline/timing/timing_seed.json (the reviewable scholarly artifact) and
loads it into timing_sources / raag_timing_claims.

Safety + honesty model:
  * scripture baseline verified BEFORE and AFTER (writes go only to new tables);
  * every claim's raag resolves against raags.roman + an explicit alias table —
    HARD FAIL with zero writes on any unresolved name;
  * every claim must cite a source that exists in the seed's sources[] —
    HARD FAIL otherwise (no uncited claims, schema enforces NOT NULL too);
  * INSERT OR IGNORE against the COALESCE unique index — re-runs insert 0 rows.

Usage: python3 seed_timing.py [--db PATH] [--baseline PATH] [--dry-run]
"""

import argparse
import json
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import baseline_lib as bl

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent

# Anglicized spelling -> raags.roman value (normalized: lowercase, no spaces/hyphens).
ALIASES = {
    "sriraag": "sireeraag", "sriraga": "sireeraag", "sireeraag": "sireeraag",
    "maajh": "maajh", "majh": "maajh",
    "gauri": "gaurhee", "gaurhee": "gaurhee",
    "asa": "aasaa", "aasaa": "aasaa",
    "gujri": "goojaree", "goojaree": "goojaree",
    "devgandhari": "devagandhaaree", "devagandhaaree": "devagandhaaree",
    "bihagra": "bihaagarhaa", "bihaagarhaa": "bihaagarhaa",
    "wadhans": "vadahans", "vadahans": "vadahans",
    "sorath": "sorath",
    "dhanasri": "dhanaasaree", "dhanaasaree": "dhanaasaree",
    "jaitsri": "jaitasaree", "jaitasaree": "jaitasaree",
    "todi": "todee", "todee": "todee",
    "bairari": "bairaarhee", "bairaarhee": "bairaarhee",
    "tilang": "tilang",
    "suhi": "soohee", "soohee": "soohee",
    "bilaval": "bilaaval", "bilawal": "bilaaval", "bilaaval": "bilaaval",
    "gaund": "gond", "gond": "gond",
    "ramkali": "raamakalee", "raamakalee": "raamakalee",
    "natnarayan": "nat", "nat": "nat",
    "maligaura": "maalee gaurhaa", "maaleegaurhaa": "maalee gaurhaa",
    "maru": "maaroo", "maaroo": "maaroo",
    "tukhari": "tukhaaree", "tukhaaree": "tukhaaree",
    "kedara": "kedaaraa", "kedaaraa": "kedaaraa",
    "bhairo": "bhairau", "bhairau": "bhairau",
    "basant": "basant",
    "sarang": "saarang", "saarang": "saarang",
    "malhar": "malaar", "malaar": "malaar",
    "kanra": "kaanarhaa", "kaanarhaa": "kaanarhaa",
    "kalyan": "kaliaan", "kaliaan": "kaliaan",
    "prabhati": "prabhaatee", "prabhaatee": "prabhaatee",
    "jaijaiwanti": "jaijaavantee", "jaijaavantee": "jaijaavantee",
}

VALID_CLAIM_TYPES = {"primary", "variant", "seasonal", "ceremonial"}
VALID_CONFIDENCE = {"consistent", "majority", "disputed"}
PAHAR_WINDOWS = {  # fixed-clock rendering, 6 AM anchor (pahar 1 = 06:00-09:00)
    1: ("06:00", "09:00"), 2: ("09:00", "12:00"), 3: ("12:00", "15:00"),
    4: ("15:00", "18:00"), 5: ("18:00", "21:00"), 6: ("21:00", "24:00"),
    7: ("00:00", "03:00"), 8: ("03:00", "06:00"),
}


def norm(s):
    return "".join(s.lower().split()).replace("-", "")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default=str(ROOT / "db" / "sggs.sqlite"))
    ap.add_argument("--baseline", default=str(ROOT / "audit" / "scripture-baseline.json"))
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--skip-baseline", action="store_true",
                    help="ONLY for rebuild_all.sh temp DBs")
    args = ap.parse_args()

    seed = json.loads((HERE / "timing_seed.json").read_text(encoding="utf-8"))
    sources = seed["sources"]
    claims = seed["claims"]
    source_names = {s["name"] for s in sources}

    # ---- validate the whole artifact BEFORE any write --------------------
    errors = []
    for s in sources:
        if s.get("tradition") not in ("gurmat_sangeet", "hindustani"):
            errors.append(f"source {s.get('name')!r}: bad tradition {s.get('tradition')!r}")

    con_ro = bl.connect_ro(args.db)
    try:
        roman_to_name = {norm(r): n for n, r in
                         con_ro.execute("SELECT name, roman FROM raags")}
    finally:
        con_ro.close()

    resolved = []
    for i, c in enumerate(claims):
        key = norm(c["raag"])
        roman = ALIASES.get(key, key)
        gname = roman_to_name.get(norm(roman))
        if gname is None:
            errors.append(f"claim #{i} ({c['raag']!r}): raag does not resolve to raags.roman")
            continue
        if c.get("claim_type") not in VALID_CLAIM_TYPES:
            errors.append(f"claim #{i} ({c['raag']!r}): bad claim_type {c.get('claim_type')!r}")
        if c.get("confidence") not in VALID_CONFIDENCE:
            errors.append(f"claim #{i} ({c['raag']!r}): bad confidence {c.get('confidence')!r}")
        if c.get("source") not in source_names:
            errors.append(f"claim #{i} ({c['raag']!r}): uncited or unknown source {c.get('source')!r}")
        pahar = c.get("pahar")
        if pahar is not None and not (1 <= pahar <= 8):
            errors.append(f"claim #{i} ({c['raag']!r}): pahar {pahar} out of range")
        if pahar == 7:
            errors.append(f"claim #{i} ({c['raag']!r}): pahar 7 must stay empty (deliberate)")
        ts, te = c.get("time_start"), c.get("time_end")
        if pahar is not None and ts is None:
            ts, te = PAHAR_WINDOWS[pahar]
        resolved.append(dict(c, raag_name=gname, time_start=ts, time_end=te))

    if errors:
        print("ABORT: seed artifact failed validation — zero rows written:", file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    n_raags = len({c["raag_name"] for c in resolved if c["claim_type"] == "primary"})
    print(f"Validated: {len(sources)} sources, {len(resolved)} claims "
          f"({n_raags} raags with a primary claim).")
    if args.dry_run:
        for c in resolved:
            print(f"  {c['raag_name']:14s} {c['claim_type']:10s} pahar={c.get('pahar')} "
                  f"conf={c['confidence']} src={c['source']}")
        return 0

    if args.skip_baseline:
        print("WARNING: baseline check skipped (--skip-baseline; rebuild pipeline only).")
    else:
        print("Verifying scripture baseline BEFORE seeding…")
        bl.require_baseline_ok(args.db, args.baseline, when="(pre-seed)")
        print("  baseline PASS.")

    con = sqlite3.connect(str(Path(args.db).resolve()), isolation_level=None)
    try:
        con.execute("PRAGMA foreign_keys=ON")
        con.execute("BEGIN IMMEDIATE")
        try:
            src_ins = 0
            for s in sources:
                cur = con.execute(
                    "INSERT OR IGNORE INTO timing_sources(name, tradition, url, notes) "
                    "VALUES (?,?,?,?)",
                    (s["name"], s["tradition"], s.get("url"), s.get("notes")))
                src_ins += cur.rowcount
            src_ids = {n: i for i, n in
                       con.execute("SELECT id, name FROM timing_sources")}

            clm_ins = 0
            for c in resolved:
                cur = con.execute(
                    "INSERT OR IGNORE INTO raag_timing_claims("
                    "  raag_name, claim_type, pahar, time_start, time_end,"
                    "  season, occasion, source_id, confidence, notes) "
                    "VALUES (?,?,?,?,?,?,?,?,?,?)",
                    (c["raag_name"], c["claim_type"], c.get("pahar"),
                     c.get("time_start"), c.get("time_end"), c.get("season"),
                     c.get("occasion"), src_ids[c["source"]],
                     c["confidence"], c.get("notes")))
                clm_ins += cur.rowcount
            con.execute("COMMIT")
        except Exception as e:
            con.execute("ROLLBACK")
            print(f"ABORT: seeding failed, transaction rolled back cleanly: {e}",
                  file=sys.stderr)
            return 1
        fk = con.execute("PRAGMA foreign_key_check").fetchall()
        if fk:
            print(f"ABORT: foreign_key_check reported violations: {fk}", file=sys.stderr)
            return 1
    finally:
        con.close()
    print(f"Seeded: +{src_ins} sources, +{clm_ins} claims "
          f"(re-runs insert 0 — INSERT OR IGNORE vs unique index).")

    if not args.skip_baseline:
        print("Re-verifying scripture baseline AFTER seeding…")
        bl.require_baseline_ok(args.db, args.baseline, when="(post-seed)")
        print("  baseline PASS — pre-existing tables byte-identical.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
