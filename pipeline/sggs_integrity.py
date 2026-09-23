# -*- coding: utf-8 -*-
"""Dataset fingerprints — one definition of "this is the same data", used everywhere.

    python3 pipeline/sggs_integrity.py DB [--out FILE.json] [--compare OTHER.json]

A fingerprint is a JSON document describing a database by content, not by bytes:

  scripture_sha256   id + gurmukhi of every line — the EXISTING definition from
                     pipeline/build_ios_db.py:scripture_checksum (the iOS manifests carry it)
  t0_sha256          id, ang, gurmukhi, text, markers of every line (the T0 scripture tier)
  tables.<t>.content_sha256
                     every real table, rows in rowid order, JSON cells, repr floats — the
                     scripture guard's definition (baseline_lib.table_data_sha256) with the
                     build-stamp values named in STAMPS blanked, so two builds of the same
                     data from different commits compare equal
  fts_index.<t>      the FTS5 index itself, dumped through fts5vocab(instance) — term, doc,
                     column, offset. A content-table hash cannot see a stale index; this can.
  db_sha256          bytes of the file (informational: VACUUM output varies by SQLite version)

FTS5 index-segment shadow tables (<fts>_data, <fts>_idx) are excluded from `tables`: their
bytes depend on the SQLite version and merge history, and fts_index covers the index. Opens
the DB read-only; writes nothing. Stdlib only; Python 3.9+.
"""
import argparse
import hashlib
import json
import sqlite3
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "timing"))
import baseline_lib as bl  # noqa: E402
from build_ios_db import scripture_checksum  # noqa: E402

SCHEMA = 1
T0_COLUMNS = ("id", "ang", "gurmukhi", "text", "markers")
# Build stamps: values that legitimately change with the build instant, never with the data.
# (table, key-column, key-predicate or None for every row, stamped column)
STAMPS = (
    ("meta", "key", lambda k: k == "built", "value"),
    ("analytics_meta", "key", lambda k: k == "built" or str(k).endswith("_built"), "value"),
    ("sources", None, None, "ingest_date"),
    ("timing_migrations", None, None, "applied_at"),
)
FTS_SHADOW_INDEX = ("_data", "_idx")


def connect(db):
    # mode=ro + immutable: the database file cannot be written through this connection.
    # (Not query_only: fts5vocab needs a TEMP virtual table, which lives outside the file.)
    return sqlite3.connect(f"file:{Path(db).resolve()}?mode=ro&immutable=1", uri=True)


def fts5_tables(con):
    return [n for (n,) in con.execute(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND lower(sql) LIKE 'create virtual table%using fts5%' ORDER BY name")]


def _hash_rows(rows):
    h, n = hashlib.sha256(), 0
    for row in rows:
        h.update(json.dumps([bl._cell(v) for v in row], ensure_ascii=False, separators=(",", ":")).encode("utf-8"))
        h.update(b"\n")
        n += 1
    return h.hexdigest(), n


def content_sha256(con, table):
    """baseline_lib's table hash, with the named build-stamp values blanked."""
    cols = [r[1] for r in con.execute(f'PRAGMA table_info("{table}")')]
    rules = [s for s in STAMPS if s[0] == table]
    try:
        cur = con.execute(f'SELECT * FROM "{table}" ORDER BY rowid')
    except sqlite3.OperationalError:
        cur = con.execute(f'SELECT * FROM "{table}" ORDER BY ' + ", ".join(f'"{c}"' for c in cols))
    if not rules:
        return _hash_rows(cur)

    def blank(row):
        row = list(row)
        for _, key_col, pred, col in rules:
            if col in cols and (key_col is None or pred(row[cols.index(key_col)])):
                row[cols.index(col)] = None
        return row
    return _hash_rows(blank(r) for r in cur)


def fts_index_sha256(con, table):
    vocab = f"_fp_vocab_{table}"
    con.execute(f'CREATE VIRTUAL TABLE IF NOT EXISTS temp."{vocab}" USING fts5vocab(main, "{table}", "instance")')
    try:
        return _hash_rows(con.execute(f'SELECT term, doc, col, offset FROM temp."{vocab}" ORDER BY term, doc, col, offset'))
    finally:
        con.execute(f'DROP TABLE IF EXISTS temp."{vocab}"')


def t0_sha256(con):
    return _hash_rows(con.execute(f"SELECT {', '.join(T0_COLUMNS)} FROM lines ORDER BY id"))[0]


def fingerprint(db):
    con = connect(db)
    try:
        fts = fts5_tables(con)
        shadow = {f + s for f in fts for s in FTS_SHADOW_INDEX}
        tables = {}
        for name, info in bl.list_tables(con).items():
            if info["virtual"] or name in shadow or name.startswith("sqlite_"):
                continue
            digest, rows = content_sha256(con, name)
            tables[name] = {"class": bl.classify(name), "rows": rows, "content_sha256": digest}
        return {
            "schema": SCHEMA,
            "sqlite_version": sqlite3.sqlite_version,
            "db_sha256": bl.file_sha256(db),
            "scripture_sha256": scripture_checksum(con),
            "t0_sha256": t0_sha256(con),
            "tables": tables,
            "fts_index": {t: dict(zip(("sha256", "instances"), fts_index_sha256(con, t))) for t in fts},
        }
    finally:
        con.close()


def compare(a, b):
    """Differences between two fingerprints, ignoring file bytes and SQLite version."""
    diffs = [k for k in ("scripture_sha256", "t0_sha256") if a.get(k) != b.get(k)]
    for section in ("tables", "fts_index"):
        for t in sorted(set(a[section]) | set(b[section])):
            if a[section].get(t) != b[section].get(t):
                diffs.append(f"{section}.{t}")
    return diffs


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("db")
    ap.add_argument("--out", help="write the fingerprint JSON here (default: stdout)")
    ap.add_argument("--compare", help="a fingerprint JSON to compare against; exit 1 on any difference")
    a = ap.parse_args(argv)
    fp = fingerprint(a.db)
    text = json.dumps(fp, ensure_ascii=False, indent=1, sort_keys=True) + "\n"
    if a.out:
        Path(a.out).write_text(text, encoding="utf-8")
    elif not a.compare:
        sys.stdout.write(text)
    if a.compare:
        diffs = compare(json.loads(Path(a.compare).read_text(encoding="utf-8")), fp)
        for d in diffs:
            print("DIFF", d)
        print(f"fingerprint compare: {'identical' if not diffs else f'{len(diffs)} difference(s)'}")
        return 1 if diffs else 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
