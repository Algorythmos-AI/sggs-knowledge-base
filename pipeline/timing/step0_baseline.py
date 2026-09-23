#!/usr/bin/env python3
"""
Step 0 for the raag-timing knowledge layer — MUST run before any migration.

1. Timestamped copy of db/sggs.sqlite into db/backups/ ; streamed SHA-256 of
   source and copy must match or we abort.
2. Integrity snapshot of EVERY existing table (row count, data hash, schema
   hash) plus whole-file hashes of the DB and corpus/sggs.jsonl, cross-checked
   against MANIFEST.json.
3. Written to audit/scripture-baseline.json (committed). Refuses to overwrite
   an existing baseline without --force.

Usage: python3 pipeline/timing/step0_baseline.py [--db PATH] [--force]
"""

import argparse
import json
import shutil
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import baseline_lib as bl

ROOT = Path(__file__).resolve().parents[2]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default=str(ROOT / "db" / "sggs.sqlite"))
    ap.add_argument("--force", action="store_true",
                    help="overwrite an existing baseline (conscious act)")
    ap.add_argument("--skip-backup", action="store_true",
                    help="baseline only (used when targeting a scratch copy)")
    args = ap.parse_args()

    db_path = Path(args.db).resolve()
    baseline_path = ROOT / "audit" / "scripture-baseline.json"
    if baseline_path.exists() and not args.force:
        print(f"REFUSING: {baseline_path} already exists. Use --force to re-baseline "
              f"(only after a deliberate pipeline rebuild).", file=sys.stderr)
        return 1

    # --- 1. backup ---------------------------------------------------------
    backup_entry = None
    if not args.skip_backup:
        stamp = time.strftime("%Y%m%d-%H%M%S")
        backup_dir = ROOT / "db" / "backups"
        backup_dir.mkdir(parents=True, exist_ok=True)
        backup_path = backup_dir / f"sggs-pre-timing-{stamp}.sqlite"
        print(f"[1/3] Backing up {db_path.name} -> {backup_path.relative_to(ROOT)}")
        src_sha = bl.file_sha256(db_path)
        shutil.copy2(db_path, backup_path)
        dst_sha = bl.file_sha256(backup_path)
        if src_sha != dst_sha:
            backup_path.unlink(missing_ok=True)
            print("ABORT: backup checksum mismatch — copy discarded.", file=sys.stderr)
            return 2
        print(f"      backup verified sha256={dst_sha[:16]}…")
        backup_entry = {"path": str(backup_path.relative_to(ROOT)), "sha256": dst_sha}
    else:
        src_sha = bl.file_sha256(db_path)

    # --- 2. snapshot -------------------------------------------------------
    print("[2/3] Snapshotting every table (rows + data hash + schema hash)…")
    con = bl.connect_ro(db_path)
    try:
        existing_timing = bl.TIMING_LAYER_TABLES & set(bl.list_tables(con))
        if existing_timing:
            print(f"ABORT: timing-layer tables already present ({sorted(existing_timing)}). "
                  f"Baseline must be recorded on a pre-migration DB.", file=sys.stderr)
            return 3
        tables = bl.snapshot_tables(con)
    finally:
        con.close()
    for name in sorted(tables):
        t = tables[name]
        rows = "virtual" if t["virtual"] else f"{t['rows']:>6}"
        print(f"      {name:28s} {rows}  {t['class']}")

    corpus_path = ROOT / "corpus" / "sggs.jsonl"
    corpus_sha = bl.file_sha256(corpus_path) if corpus_path.exists() else None

    manifest_note = {}
    manifest_path = ROOT / "MANIFEST.json"
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest_note = {
            "manifest_db_sha256_at_baseline": manifest.get("db_sha256"),
            "manifest_corpus_sha256_at_baseline": manifest.get("corpus_sha256"),
        }
        if manifest.get("corpus_sha256") and corpus_sha and \
           manifest["corpus_sha256"] != corpus_sha:
            print("ABORT: corpus/sggs.jsonl hash disagrees with MANIFEST.json — "
                  "resolve before baselining.", file=sys.stderr)
            return 4
        if manifest.get("db_sha256") and manifest["db_sha256"] != src_sha:
            print("WARNING: db file hash differs from MANIFEST db_sha256 "
                  "(MANIFEST may be stale from a prior change) — recording both.")

    # --- 3. write baseline -------------------------------------------------
    baseline = {
        "created": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "db_path": str(db_path.relative_to(ROOT)) if db_path.is_relative_to(ROOT) else f"<external>/{db_path.name}",  # no machine paths in tracked files
        "db_file_sha256": src_sha,
        "corpus_path": "corpus/sggs.jsonl",
        "corpus_sha256": corpus_sha,
        **manifest_note,
        "method": bl.METHOD,
        "backup": backup_entry,
        "tables": tables,
    }
    baseline_path.parent.mkdir(parents=True, exist_ok=True)
    baseline_path.write_text(
        json.dumps(baseline, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"[3/3] Baseline written: {baseline_path.relative_to(ROOT)} "
          f"({len(tables)} tables). Commit this file.")

    ok, failures = bl.verify_against_baseline(db_path, baseline_path, verbose=False)
    if not ok:
        print("ABORT: self-verification of the fresh baseline failed:", file=sys.stderr)
        for f in failures:
            print("  " + f, file=sys.stderr)
        return 5
    print("      self-verification PASS — baseline is reproducible.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
