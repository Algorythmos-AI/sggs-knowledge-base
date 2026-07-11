#!/usr/bin/env python3
"""
Re-stamp MANIFEST.json after the timing layer lands (user-approved policy):
`db_sha256` is a whole-file freshness stamp and legitimately changes when
additive tables are created; the committed per-table baseline
(audit/scripture-baseline.json) is the scripture invariant of record.

Refuses to stamp unless guard_scripture.py passes first.

Usage: python3 pipeline/timing/stamp_manifest.py [--db PATH]
"""

import argparse
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import baseline_lib as bl

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default=str(ROOT / "db" / "sggs.sqlite"))
    args = ap.parse_args()

    print("Running guard_scripture.py before touching MANIFEST…")
    r = subprocess.run([sys.executable, str(HERE / "guard_scripture.py"),
                        "--db", args.db])
    if r.returncode != 0:
        print("REFUSING to stamp MANIFEST: guard failed.", file=sys.stderr)
        return 1

    manifest_path = ROOT / "MANIFEST.json"
    m = json.loads(manifest_path.read_text(encoding="utf-8"))
    old = m.get("db_sha256")
    new = bl.file_sha256(args.db)
    m["db_sha256"] = new
    m["scripture_baseline"] = "audit/scripture-baseline.json"
    m["timing_layer"] = (
        "v1 — attributed raag timing claims + bani forms metadata; additive "
        "NEW tables only (timing_sources, raag_timing_claims, shabd_raag_map, "
        "shabd_musical_markers, shabd_structural_form, shabd_poetic_genre, "
        "timing_migrations); scripture proven byte-identical by "
        "pipeline/timing/guard_scripture.py against the committed baseline")
    manifest_path.write_text(json.dumps(m, indent=2, ensure_ascii=False) + "\n",
                             encoding="utf-8")
    print(f"MANIFEST stamped: db_sha256 {old[:12]}… -> {new[:12]}… "
          f"(+ scripture_baseline, timing_layer keys)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
