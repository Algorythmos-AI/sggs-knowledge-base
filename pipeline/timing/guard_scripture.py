#!/usr/bin/env python3
"""
Standing guard test for the raag-timing layer (required by the task spec):
after all migrations and seeding, EVERY scripture-bearing (and other
pre-existing) table's row count, data SHA-256, and schema SHA-256 must match
the committed Step-0 baseline (audit/scripture-baseline.json), the corpus
file hash must be unchanged, and PRAGMA foreign_key_check must be empty.

Exit 0 = PASS, exit 1 = FAIL (with a per-table report).

Usage: python3 pipeline/timing/guard_scripture.py [--db PATH] [--baseline PATH]
"""

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import baseline_lib as bl

ROOT = Path(__file__).resolve().parents[2]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default=str(ROOT / "db" / "sggs.sqlite"))
    ap.add_argument("--baseline", default=str(ROOT / "audit" / "scripture-baseline.json"))
    args = ap.parse_args()

    print(f"GUARD: {args.db}\n  vs baseline {args.baseline}\n")
    ok, failures = bl.verify_against_baseline(args.db, args.baseline, verbose=True)

    baseline = bl.load_baseline(args.baseline)
    corpus = ROOT / baseline.get("corpus_path", "corpus/sggs.jsonl")
    if baseline.get("corpus_sha256") and corpus.exists():
        cur = bl.file_sha256(corpus)
        status = "PASS" if cur == baseline["corpus_sha256"] else "FAIL"
        print(f"  [{status}] {baseline.get('corpus_path')} (source corpus file)")
        if status == "FAIL":
            failures.append(f"corpus file hash mismatch: {cur}")
            ok = False

    con = bl.connect_ro(args.db)
    try:
        fk = con.execute("PRAGMA foreign_key_check").fetchall()
    finally:
        con.close()
    print(f"  [{'PASS' if not fk else 'FAIL'}] foreign_key_check "
          f"({len(fk)} violations)")
    if fk:
        failures.append(f"foreign_key_check violations: {fk[:10]}")
        ok = False

    print()
    if not ok:
        print("GUARD FAIL — scripture integrity NOT proven:", file=sys.stderr)
        for f in failures:
            print("  " + f, file=sys.stderr)
        return 1
    n = len(baseline["tables"])
    print(f"GUARD PASS — all {n} pre-existing tables byte-identical to the "
          f"committed Step-0 baseline; corpus unchanged; FKs clean.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
