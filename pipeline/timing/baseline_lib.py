#!/usr/bin/env python3
"""
baseline_lib — shared integrity primitives for the raag-timing knowledge layer.

Used by step0_baseline.py (record), apply_migration.py / seed_timing.py /
derive_bani_forms.py (verify before & after every write), and
guard_scripture.py (the standing guard test).

Method (self-describing, restated inside the baseline JSON):
  * data hash   = SHA-256 over newline-joined rows of `SELECT * FROM "t" ORDER BY rowid`
                  (fallback: ORDER BY all columns for WITHOUT ROWID tables),
                  each row serialized as compact JSON (ensure_ascii=False),
                  BLOBs hex-encoded, floats via repr for bit-stability.
  * schema hash = SHA-256 of the table's canonical `sqlite_master.sql` text
                  (catches any ALTER TABLE even if data is unchanged).
  * virtual tables (FTS5 etc.) get a schema hash only — their real storage is
    in shadow tables, which are hashed as ordinary tables.

Nothing in this module ever writes to the database: connections are opened
with mode=ro.
"""

import hashlib
import json
import sqlite3
import sys
from pathlib import Path

METHOD = (
    "data: sha256 of newline-joined compact-JSON rows, SELECT * ORDER BY rowid "
    "(fallback: ORDER BY all columns); blobs hex; floats repr. "
    "schema: sha256 of sqlite_master.sql. virtual tables: schema hash only."
)

# Classification of pre-existing tables (anything unlisted → 'metadata').
SCRIPTURE = {"lines"}
SCRIPTURE_DERIVED_PREFIXES = ("fts",)  # fts, fts_en, fts_shabad, fts_tri + shadows
SCRIPTURE_DERIVED = {
    "canon_tokens", "variants", "word_freq", "vaars", "vaar_units",
    "concept_lines", "line_neighbors", "shabad_neighbors",
}
COMPANION_TEXT = {"translations"}

# Tables owned by the timing layer itself.
TIMING_LAYER_TABLES = {
    "timing_sources", "raag_timing_claims", "shabd_raag_map",
    "shabd_musical_markers", "shabd_structural_form", "shabd_poetic_genre",
    "timing_migrations",
}
# Tables owned by the Nitnem bani registry (pipeline/banis/, migration 002).
# `extra_lines` holds NON-SGGS text (Sri Dasam Granth / Ardaas) — a companion layer,
# drift-guarded byte-for-byte once baselined, never part of scripture.
BANI_LAYER_TABLES = {"banis", "bani_lines", "extra_lines"}
# Every additive layer that may legitimately appear on top of a baseline.
ADDITIVE_LAYER_TABLES = TIMING_LAYER_TABLES | BANI_LAYER_TABLES


def connect_ro(db_path):
    p = Path(db_path).resolve()
    if not p.exists():
        raise FileNotFoundError(f"database not found: {p}")
    con = sqlite3.connect(f"file:{p}?mode=ro", uri=True)
    con.execute("PRAGMA query_only=ON")
    return con


def file_sha256(path, chunk=1 << 20):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            b = f.read(chunk)
            if not b:
                break
            h.update(b)
    return h.hexdigest()


def classify(table):
    if table in SCRIPTURE:
        return "scripture"
    if table in SCRIPTURE_DERIVED or table.startswith(SCRIPTURE_DERIVED_PREFIXES):
        return "scripture_derived"
    if table in COMPANION_TEXT or table == "extra_lines":
        return "companion_text"
    if table in BANI_LAYER_TABLES:
        return "scripture_derived"   # pointers into `lines`
    return "metadata"


def list_tables(con):
    """All tables from sqlite_master: name -> {sql, virtual}."""
    out = {}
    for name, sql in con.execute(
        "SELECT name, sql FROM sqlite_master WHERE type='table' ORDER BY name"
    ):
        virtual = bool(sql) and sql.lstrip().upper().startswith("CREATE VIRTUAL TABLE")
        out[name] = {"sql": sql or "", "virtual": virtual}
    return out


def _cell(v):
    if isinstance(v, bytes):
        return "x'" + v.hex() + "'"
    if isinstance(v, float):
        return repr(v)
    return v


def table_data_sha256(con, table):
    """Deterministic content hash of a real (non-virtual) table."""
    h = hashlib.sha256()
    try:
        cur = con.execute(f'SELECT * FROM "{table}" ORDER BY rowid')
    except sqlite3.OperationalError:
        cols = [r[1] for r in con.execute(f'PRAGMA table_info("{table}")')]
        order = ", ".join(f'"{c}"' for c in cols)
        cur = con.execute(f'SELECT * FROM "{table}" ORDER BY {order}')
    n = 0
    for row in cur:
        h.update(
            json.dumps([_cell(v) for v in row], ensure_ascii=False,
                       separators=(",", ":")).encode("utf-8")
        )
        h.update(b"\n")
        n += 1
    return h.hexdigest(), n


def schema_sha256(sql):
    return hashlib.sha256((sql or "").encode("utf-8")).hexdigest()


def snapshot_tables(con, skip=frozenset()):
    """Full integrity snapshot: table -> {class, virtual, rows, data_sha256, schema_sha256}."""
    snap = {}
    for name, info in list_tables(con).items():
        if name in skip:
            continue
        entry = {
            "class": classify(name),
            "virtual": info["virtual"],
            "schema_sha256": schema_sha256(info["sql"]),
        }
        if info["virtual"]:
            entry["rows"] = None
            entry["data_sha256"] = None
        else:
            digest, rows = table_data_sha256(con, name)
            entry["rows"] = rows
            entry["data_sha256"] = digest
        snap[name] = entry
    return snap


def load_baseline(baseline_path):
    with open(baseline_path, "r", encoding="utf-8") as f:
        return json.load(f)


def verify_against_baseline(db_path, baseline_path, verbose=True):
    """
    Recompute every baselined table and compare. New tables NOT in the baseline
    are allowed only if they belong to ADDITIVE_LAYER_TABLES (timing layer or
    bani registry); anything else is a failure (an unknown table appeared).
    Returns (ok, failures:list[str]).
    """
    baseline = load_baseline(baseline_path)
    con = connect_ro(db_path)
    failures = []
    try:
        current = snapshot_tables(con)
    finally:
        con.close()

    for name, base in sorted(baseline["tables"].items()):
        cur = current.get(name)
        if cur is None:
            failures.append(f"{name}: MISSING (was in baseline)")
            continue
        for key in ("rows", "data_sha256", "schema_sha256"):
            if cur[key] != base[key]:
                failures.append(
                    f"{name}: {key} mismatch (baseline={base[key]} current={cur[key]})"
                )
    for name in sorted(set(current) - set(baseline["tables"])):
        if name not in ADDITIVE_LAYER_TABLES:
            failures.append(f"{name}: UNEXPECTED new table (not an additive layer)")

    if verbose:
        for name in sorted(baseline["tables"]):
            status = "FAIL" if any(f.startswith(name + ":") for f in failures) else "PASS"
            cls = baseline["tables"][name]["class"]
            print(f"  [{status}] {name:28s} ({cls})")
        extras = sorted(set(current) - set(baseline["tables"]))
        if extras:
            print(f"  new tables present: {', '.join(extras)}")
    return (not failures), failures


def require_baseline_ok(db_path, baseline_path, when=""):
    """Abort the calling script (exit 2) unless the baseline verifies clean."""
    ok, failures = verify_against_baseline(db_path, baseline_path, verbose=False)
    if not ok:
        print(f"INTEGRITY FAILURE {when}: scripture baseline does not verify.",
              file=sys.stderr)
        for f in failures:
            print("  " + f, file=sys.stderr)
        sys.exit(2)
    return True
