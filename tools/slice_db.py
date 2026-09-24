#!/usr/bin/env python3
"""Cut a service's database slice from the full pinned database.

    python3 tools/slice_db.py --modules search --out build/slices/search.sqlite [--db db/sggs.sqlite]

A slice keeps exactly the tables the enabled contexts declare (serve.CONTEXT_TABLES) plus their
closure, and nothing else:
  * foreign-key targets (PRAGMA foreign_key_list), recursively;
  * for every kept FTS5 table, its shadow tables and its external content table (`fts` reads
    `lines`), so the index stays whole and `integrity-check` still passes.

The full database is copied with the SQLite backup API, everything outside the closure is dropped,
the copy is VACUUMed, and then every kept table is proven byte-identical in content to the full
database (rows in rowid order) and every kept FTS index passes FTS5 `integrity-check`. Only then is
the slice installed: same-directory temp file, fsync, os.replace. Stdlib only.
"""
from __future__ import annotations

import argparse
import hashlib
import os
import re
import sqlite3
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "webapp"))
FTS_SHADOWS = ("_data", "_idx", "_content", "_docsize", "_config")


def closure(con, declared: set[str]) -> set[str]:
    rows = con.execute("SELECT name, sql FROM sqlite_master WHERE type = 'table'").fetchall()
    sql = {n: (s or "") for n, s in rows}
    fts = {n for n, s in sql.items() if re.search(r"USING\s+fts5", s, re.I)}
    keep, todo = set(), list(declared)
    while todo:
        t = todo.pop()
        if t in keep or t not in sql:
            continue
        keep.add(t)
        if t in fts:
            keep |= {t + s for s in FTS_SHADOWS if t + s in sql}
            m = re.search(r"content\s*=\s*'?\"?(\w+)", sql[t], re.I)
            if m and m.group(1):
                todo.append(m.group(1))
        else:
            todo += [r[2] for r in con.execute(f'PRAGMA foreign_key_list("{t}")')]
    return keep


def _content_sha(con, table: str) -> str:
    """Rows in a stable order: rowid, or the primary key of a WITHOUT ROWID table (FTS5 _idx/_config)."""
    sql = con.execute("SELECT sql FROM sqlite_master WHERE name = ?", (table,)).fetchone()[0] or ""
    if "WITHOUT ROWID" in sql.upper():
        pk = [r[1] for r in sorted(con.execute(f'PRAGMA table_info("{table}")'), key=lambda r: r[5]) if r[5]]
        order = ", ".join(f'"{c}"' for c in pk)
    else:
        order = "rowid"
    h = hashlib.sha256()
    for row in con.execute(f'SELECT * FROM "{table}" ORDER BY {order}'):
        h.update(repr(row).encode("utf-8"))
    return h.hexdigest()


def slice_db(full: Path, modules: set[str], out: Path) -> dict:
    import serve  # the declarations live with the code that reads the tables
    unknown = modules - set(serve.CONTEXT_TABLES)
    if unknown:
        raise SystemExit(f"unknown contexts: {sorted(unknown)}")
    declared = set().union(*(serve.CONTEXT_TABLES[m] for m in modules))
    src = sqlite3.connect(f"file:{full.resolve()}?mode=ro&immutable=1", uri=True)
    keep = closure(src, declared)
    missing = declared - {r[0] for r in src.execute("SELECT name FROM sqlite_master WHERE type = 'table'")}
    if missing:
        raise SystemExit(f"the full database lacks declared tables {sorted(missing)}")

    out.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=f".{out.name}.", suffix=".part", dir=out.parent)
    os.close(fd)
    try:
        dst = sqlite3.connect(tmp)
        src.backup(dst)
        names = {n: s for n, s in dst.execute("SELECT name, sql FROM sqlite_master WHERE type = 'table'")}
        virtual = [n for n, s in names.items() if s and s.upper().startswith("CREATE VIRTUAL")]
        for n in virtual:                                   # a virtual table drops its own shadows
            if n not in keep:
                dst.execute(f'DROP TABLE "{n}"')
        for n in [n for n in names if n not in keep and not n.startswith("sqlite_")]:
            if dst.execute("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?", (n,)).fetchone():
                dst.execute(f'DROP TABLE "{n}"')
        for (v,) in dst.execute("SELECT name FROM sqlite_master WHERE type = 'view'").fetchall():
            dst.execute(f'DROP VIEW "{v}"')
        dst.commit()
        dst.execute("VACUUM")
        # Proof: same content as the full database, every kept FTS index whole.
        kept_real = sorted(n for n, in dst.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND sql NOT LIKE 'CREATE VIRTUAL%' "
            "AND name NOT LIKE 'sqlite_%'"))
        for t in kept_real:
            if _content_sha(dst, t) != _content_sha(src, t):
                raise SystemExit(f"slice table {t} differs from the full database")
        for n in sorted(k for k in keep if k in virtual):
            dst.execute(f"INSERT INTO \"{n}\"(\"{n}\", rank) VALUES('integrity-check', 1)")
        dst.close()
        with open(tmp, "rb") as f:
            os.fsync(f.fileno())
        os.replace(tmp, out)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)
    return {"modules": sorted(modules), "tables": sorted(keep), "bytes": out.stat().st_size,
            "sha256": hashlib.sha256(out.read_bytes()).hexdigest()}


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--db", type=Path, default=ROOT / "db" / "sggs.sqlite")
    ap.add_argument("--modules", required=True, help="comma list of contexts (reader,search,verify,insights,knowledge)")
    ap.add_argument("--out", type=Path, required=True)
    a = ap.parse_args(argv)
    t0 = time.monotonic()
    r = slice_db(a.db, {m.strip() for m in a.modules.split(",") if m.strip()}, a.out)
    print(f"{','.join(r['modules'])}: {len(r['tables'])} tables, {r['bytes'] / 1e6:.1f} MB, "
          f"sha256 {r['sha256'][:12]} ({time.monotonic() - t0:.1f}s) → {a.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
