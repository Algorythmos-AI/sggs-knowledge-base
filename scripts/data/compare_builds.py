#!/usr/bin/env python3
"""Prove two database builds are content-identical, table by table.

    python3 scripts/data/compare_builds.py A.sqlite B.sqlite

Uses the scripture guard's own hash (pipeline/timing/baseline_lib.snapshot_tables:
every real table, including FTS5 shadow tables, rows in rowid order, JSON cells,
repr floats) so "identical" here means exactly what guard_scripture means by it.
Prints every table whose schema, row count or content differs, with its class
(scripture / scripture_derived / companion_text / metadata). Exit 0 only if the
two builds are identical in every table. Use it to prove a rebuild is
reproducible (same commit + PDF + toolchain => same content).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "pipeline" / "timing"))
import baseline_lib as bl  # noqa: E402


def compare(a, b):
    """Return a list of (table, class, reason) for every difference."""
    sa = bl.snapshot_tables(bl.connect_ro(a))
    sb = bl.snapshot_tables(bl.connect_ro(b))
    diffs = []
    for t in sorted(set(sa) | set(sb)):
        if t not in sa or t not in sb:
            diffs.append((t, (sa.get(t) or sb.get(t))["class"], "only in " + ("B" if t not in sa else "A")))
            continue
        x, y = sa[t], sb[t]
        for key in ("schema_sha256", "rows", "data_sha256"):
            if x[key] != y[key]:
                diffs.append((t, x["class"], f"{key}: {x[key]} != {y[key]}"))
                break
    return diffs, len(sa)


def main(argv):
    if len(argv) != 3:
        print(__doc__.strip().splitlines()[2].strip())
        return 2
    diffs, n = compare(argv[1], argv[2])
    for t, cls, why in diffs:
        print(f"DIFF  {t:32s} ({cls})  {why}")
    if diffs:
        print(f"NOT reproducible: {len(diffs)} of {n} tables differ")
        return 1
    print(f"reproducible: all {n} tables identical (schema, row count, content)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
