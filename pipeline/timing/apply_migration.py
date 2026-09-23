#!/usr/bin/env python3
"""
Transactional, whitelist-enforced migration runner for the raag-timing layer.

Safety model:
  * requires audit/scripture-baseline.json and verifies EVERY baselined table
    (rows + data hash + schema hash) BEFORE and AFTER the migration;
  * every SQL statement must be CREATE TABLE / CREATE INDEX on a timing-layer
    table (or DROP TABLE IF EXISTS of one, in rollback mode) — anything else
    aborts before the DB is opened read-write;
  * all statements run individually inside one BEGIN IMMEDIATE transaction
    (never executescript, which auto-commits); any error -> ROLLBACK + report;
  * refuses to run while another process holds the DB file (serve.py opens it
    immutable — writing underneath it is undefined behaviour).

Usage:
  python3 apply_migration.py [--db PATH] [--baseline PATH]
  python3 apply_migration.py --rollback [--db PATH] [--baseline PATH]
"""

import argparse
import re
import sqlite3
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import baseline_lib as bl
from build_clock import stamp

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
MIGRATION_NAME = "001_timing_layer"

NEW_TABLES = bl.TIMING_LAYER_TABLES
NEW_INDEXES = {"ux_timing_claim", "ix_timing_claims_raag", "ix_shabd_raag"}

CREATE_TABLE_RE = re.compile(r'^\s*CREATE\s+TABLE\s+"?(\w+)"?\s*\(', re.I | re.S)
CREATE_INDEX_RE = re.compile(
    r'^\s*CREATE\s+(?:UNIQUE\s+)?INDEX\s+"?(\w+)"?\s+ON\s+"?(\w+)"?', re.I | re.S)
DROP_TABLE_RE = re.compile(r'^\s*DROP\s+TABLE\s+IF\s+EXISTS\s+"?(\w+)"?\s*$', re.I | re.S)


def split_statements(sql_text):
    """Strip -- comments, split on ';'. Our migration SQL contains no string
    literals with semicolons; the whitelist below rejects anything surprising."""
    lines = []
    for line in sql_text.splitlines():
        lines.append(line.split("--", 1)[0])
    return [s.strip() for s in "\n".join(lines).split(";") if s.strip()]


def whitelist_check(statements, rollback):
    """Every statement must target ONLY timing-layer objects. Returns error list."""
    errors = []
    for stmt in statements:
        if rollback:
            m = DROP_TABLE_RE.match(stmt)
            if m and m.group(1) in NEW_TABLES:
                continue
            errors.append(f"NOT WHITELISTED (rollback): {stmt[:80]!r}")
            continue
        m = CREATE_TABLE_RE.match(stmt)
        if m:
            if m.group(1) in NEW_TABLES:
                continue
            errors.append(f"CREATE TABLE on non-timing table: {m.group(1)}")
            continue
        m = CREATE_INDEX_RE.match(stmt)
        if m:
            if m.group(1) in NEW_INDEXES and m.group(2) in NEW_TABLES:
                continue
            errors.append(f"CREATE INDEX outside whitelist: {m.group(1)} ON {m.group(2)}")
            continue
        errors.append(f"NOT WHITELISTED: {stmt[:80]!r}")
    return errors


def db_in_use(db_path):
    """Best-effort: is any other process holding the DB file open?"""
    try:
        out = subprocess.run(["lsof", "-t", str(db_path)],
                             capture_output=True, text=True, timeout=15)
        return bool(out.stdout.strip())
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False  # lsof unavailable — proceed (documented residual risk)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default=str(ROOT / "db" / "sggs.sqlite"))
    ap.add_argument("--baseline", default=str(ROOT / "audit" / "scripture-baseline.json"))
    ap.add_argument("--rollback", action="store_true")
    ap.add_argument("--allow-live", action="store_true",
                    help="skip the open-file-handle check (rebuild pipeline temp DBs)")
    ap.add_argument("--skip-baseline", action="store_true",
                    help="ONLY for rebuild_all.sh temp DBs (fresh build already "
                         "gated by reconcile.py + golden_test.py; derived tables "
                         "legitimately differ from the committed baseline)")
    args = ap.parse_args()

    db_path = Path(args.db).resolve()
    sql_file = HERE / ("rollback_001.sql" if args.rollback else "migrate_001_timing_layer.sql")
    mode = "ROLLBACK" if args.rollback else "APPLY"

    statements = split_statements(sql_file.read_text(encoding="utf-8"))
    errors = whitelist_check(statements, args.rollback)
    if errors:
        print(f"ABORT ({mode}): migration SQL failed the whitelist check:", file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print(f"[{mode}] {len(statements)} statements whitelisted "
          f"(only timing-layer tables/indexes named).")

    if not args.allow_live and db_in_use(db_path):
        print(f"ABORT: {db_path} is open in another process (serve.py?). "
              f"Stop it first — it holds the DB in immutable mode.", file=sys.stderr)
        return 1

    if args.skip_baseline:
        print(f"[{mode}] WARNING: baseline check skipped (--skip-baseline; "
              f"sanctioned only inside rebuild_all.sh).")
    else:
        print(f"[{mode}] Verifying scripture baseline BEFORE any write…")
        bl.require_baseline_ok(db_path, args.baseline, when="(pre-migration)")
        print("        baseline PASS.")

    con = sqlite3.connect(str(db_path), isolation_level=None)
    try:
        con.execute("PRAGMA foreign_keys=ON")
        if not args.rollback:
            try:
                done = con.execute(
                    "SELECT 1 FROM timing_migrations WHERE name=?",
                    (MIGRATION_NAME,)).fetchone()
                if done:
                    print(f"[{mode}] {MIGRATION_NAME} already applied — nothing to do.")
                    return 0
            except sqlite3.OperationalError:
                pass  # timing_migrations doesn't exist yet: first run

        con.execute("BEGIN IMMEDIATE")
        try:
            for stmt in statements:
                con.execute(stmt)
            if not args.rollback:
                con.execute(
                    "INSERT INTO timing_migrations(name, applied_at, baseline_verified) "
                    "VALUES (?, ?, 1)",
                    (MIGRATION_NAME, stamp("%Y-%m-%dT%H:%M:%S%z")))
            con.execute("COMMIT")
        except Exception as e:
            con.execute("ROLLBACK")
            print(f"ABORT: statement failed, transaction rolled back cleanly: {e}",
                  file=sys.stderr)
            return 1
    finally:
        con.close()
    print(f"[{mode}] Transaction committed.")

    if not args.skip_baseline:
        print(f"[{mode}] Re-verifying scripture baseline AFTER commit…")
        bl.require_baseline_ok(db_path, args.baseline, when="(post-migration)")
        print("        baseline PASS — pre-existing tables byte-identical.")

    if args.rollback:
        con = bl.connect_ro(db_path)
        try:
            leftover = bl.TIMING_LAYER_TABLES & set(bl.list_tables(con))
        finally:
            con.close()
        if leftover:
            print(f"ABORT: rollback left timing tables behind: {sorted(leftover)}",
                  file=sys.stderr)
            return 1
        print("[ROLLBACK] Proven: all timing-layer tables dropped, baseline intact.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
