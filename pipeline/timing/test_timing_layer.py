#!/usr/bin/env python3
"""
Gate tests for the raag-timing layer schema + data (standalone, repo style —
no pytest). Runs against a THROWAWAY COPY of the given DB so constraint
tests can attempt bad inserts without ever touching the real file.

Covers (per task spec):
  * schema CHECK / UNIQUE / FK constraints actually reject bad rows;
  * seed idempotency: re-running seed_timing.py inserts 0 rows;
  * claim queries: divergence set is exactly the disputed raags;
  * bani-forms spot checks against known Angs;
  * pahar-7 emptiness (deliberate, displayed content).

Usage: python3 pipeline/timing/test_timing_layer.py [--db PATH]
"""

import argparse
import shutil
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent

PASS, FAIL = 0, 0


def check(name, cond, detail=""):
    global PASS, FAIL
    status = "PASS" if cond else "FAIL"
    if cond:
        PASS += 1
    else:
        FAIL += 1
    print(f"  [{status}] {name}" + (f" — {detail}" if detail and not cond else ""))


def expect_reject(con, name, sql, params):
    con.execute("BEGIN")
    try:
        con.execute(sql, params)
        check(name, False, "insert was ACCEPTED but must be rejected")
    except sqlite3.IntegrityError:
        check(name, True)
    finally:
        con.execute("ROLLBACK")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default=str(ROOT / "db" / "sggs.sqlite"))
    args = ap.parse_args()

    tmp = Path(tempfile.mkdtemp()) / "timing_test.sqlite"
    shutil.copy2(args.db, tmp)
    print(f"Testing against throwaway copy: {tmp}\n")

    con = sqlite3.connect(str(tmp), isolation_level=None)
    con.execute("PRAGMA foreign_keys=ON")

    print("— schema constraints —")
    src_id = con.execute("SELECT id FROM timing_sources LIMIT 1").fetchone()[0]
    expect_reject(con, "claim_type CHECK rejects bad value",
                  "INSERT INTO raag_timing_claims(raag_name, claim_type, source_id, confidence) "
                  "VALUES ('ਆਸਾ','sometimes',?, 'majority')", (src_id,))
    expect_reject(con, "confidence CHECK rejects bad value",
                  "INSERT INTO raag_timing_claims(raag_name, claim_type, source_id, confidence) "
                  "VALUES ('ਆਸਾ','primary',?, 'certain')", (src_id,))
    expect_reject(con, "pahar CHECK rejects 9",
                  "INSERT INTO raag_timing_claims(raag_name, claim_type, pahar, source_id, confidence) "
                  "VALUES ('ਆਸਾ','primary',9,?, 'majority')", (src_id,))
    expect_reject(con, "FK rejects unknown raag_name",
                  "INSERT INTO raag_timing_claims(raag_name, claim_type, source_id, confidence) "
                  "VALUES ('NotARaag','primary',?, 'majority')", (src_id,))
    expect_reject(con, "FK rejects unknown source_id",
                  "INSERT INTO raag_timing_claims(raag_name, claim_type, source_id, confidence) "
                  "VALUES ('ਆਸਾ','primary',99999,'majority')", ())
    expect_reject(con, "tradition CHECK rejects bad value",
                  "INSERT INTO timing_sources(name, tradition) VALUES ('x','carnatic')", ())
    expect_reject(con, "ghar CHECK rejects 18",
                  "INSERT INTO shabd_musical_markers(comp_id, ghar) VALUES (999999, 18)", ())
    expect_reject(con, "genre CHECK rejects 'lavan' (headings-only rule)",
                  "INSERT INTO shabd_poetic_genre(comp_id, genre) VALUES (999999,'lavan')", ())
    # duplicate-claim idempotency at the SQL level (COALESCE unique index)
    n0 = con.execute("SELECT COUNT(*) FROM raag_timing_claims").fetchone()[0]
    con.execute("INSERT OR IGNORE INTO raag_timing_claims(raag_name, claim_type, "
                "season, source_id, confidence) SELECT raag_name, claim_type, season, "
                "source_id, confidence FROM raag_timing_claims WHERE claim_type='seasonal'")
    n1 = con.execute("SELECT COUNT(*) FROM raag_timing_claims").fetchone()[0]
    check("NULL-pahar duplicate is ignored (COALESCE unique index)", n0 == n1,
          f"{n1 - n0} duplicates slipped in")

    print("— seed idempotency (full script re-run) —")
    r = subprocess.run([sys.executable, str(HERE / "seed_timing.py"),
                        "--db", str(tmp), "--skip-baseline"],
                       capture_output=True, text=True)
    check("seed re-run exits 0", r.returncode == 0, r.stderr[-300:])
    check("seed re-run inserts 0 rows", "+0 sources, +0 claims" in r.stdout,
          r.stdout[-300:])

    print("— claim queries —")
    disputed = {r[0] for r in con.execute(
        "SELECT DISTINCT raag_name FROM raag_timing_claims WHERE confidence='disputed'")}
    expected = {"ਗਉੜੀ", "ਤਿਲੰਗ", "ਗੋਂਡ", "ਰਾਮਕਲੀ", "ਕੇਦਾਰਾ"}
    check("disputed raag set is exactly {Gauri, Tilang, Gaund, Ramkali, Kedara}",
          disputed == expected, f"got {disputed}")
    n7 = con.execute("SELECT COUNT(*) FROM raag_timing_claims WHERE pahar=7").fetchone()[0]
    check("pahar 7 has zero raags (deliberate absence)", n7 == 0)
    primaries = con.execute(
        "SELECT COUNT(DISTINCT raag_name) FROM raag_timing_claims "
        "WHERE claim_type='primary'").fetchone()[0]
    check("all 31 raags have a primary claim", primaries == 31, f"got {primaries}")
    uncited = con.execute(
        "SELECT COUNT(*) FROM raag_timing_claims c LEFT JOIN timing_sources s "
        "ON s.id=c.source_id WHERE s.id IS NULL").fetchone()[0]
    check("every claim cites an existing source", uncited == 0)

    print("— bani forms (derived from verified headings) —")
    def one(sql, *p):
        r = con.execute(sql, p).fetchone()
        return r[0] if r else None
    check("Ang 74 comp is genre 'pahare' (from header, comp_type disagrees)",
          one("SELECT g.genre FROM shabd_poetic_genre g JOIN shabd_raag_map m "
              "USING(comp_id) WHERE m.first_ang=74 AND g.genre='pahare'") == "pahare")
    check("9 vaars carry a dhunni (matches tradition)",
          one("SELECT COUNT(*) FROM shabd_musical_markers WHERE dhunni IS NOT NULL") == 9)
    check("partaal compositions detected",
          (one("SELECT COUNT(*) FROM shabd_musical_markers WHERE partaal=1") or 0) > 0)
    check("shabd_raag_map covers every composition",
          one("SELECT COUNT(*) FROM shabd_raag_map") ==
          one("SELECT COUNT(DISTINCT comp_id) FROM lines"))
    check("no form guessed without a heading (Japji pauris stay NULL)",
          one("SELECT COUNT(*) FROM shabd_structural_form f JOIN shabd_raag_map m "
              "USING(comp_id) WHERE m.first_ang BETWEEN 1 AND 8 AND f.form IS NOT NULL "
              "AND f.form != 'salok'") == 0)
    check("Mundavani present at Ang 1429",
          one("SELECT COUNT(*) FROM shabd_poetic_genre g JOIN shabd_raag_map m "
              "USING(comp_id) WHERE g.genre='mundavani' AND m.first_ang=1429") == 1)

    con.close()
    shutil.rmtree(tmp.parent, ignore_errors=True)
    print(f"\n{PASS} passed, {FAIL} failed.")
    return 1 if FAIL else 0


if __name__ == "__main__":
    sys.exit(main())
