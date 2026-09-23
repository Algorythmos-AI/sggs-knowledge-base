# -*- coding: utf-8 -*-
"""Refuse to install a database that is structurally unsound or incomplete.

    python3 pipeline/db_integrity_gate.py DB [--require TABLE ...]

Checks, all of which must pass (exit 1 otherwise):
  * PRAGMA integrity_check == ok and PRAGMA foreign_key_check is empty
  * every FTS5 table passes 'integrity-check' with rank=1, which also compares
    the index against its content table (catches a stale external-content index)
  * every required table exists and is non-empty (REQUIRED plus --require)
  * the canonical scripture shape: 60,658 lines over 1,430 contiguous Angs

Opens the DB read-write only because FTS5 integrity-check is issued as an
INSERT; it changes nothing and the connection is rolled back. Stdlib only.
"""
import argparse
import sqlite3
import sys

LINES = 60658
ANGS = 1430

# Tables the API, the iOS build and the analytics layer read. A build that
# silently skipped one of these must not reach db/sggs.sqlite.
REQUIRED = (
    'lines', 'fts', 'fts_en', 'fts_shabad', 'fts_tri', 'translations', 'variants',
    'canon_tokens', 'word_freq', 'concepts', 'concept_lines', 'raags', 'sections',
    'authors', 'meta', 'analytics_meta', 'theme_network', 'theme_fingerprint',
    'author_analytics', 'raag_analytics', 'shabad_neighbors', 'line_neighbors',
    'author_resonance', 'vaars', 'vaar_units', 'raag_timing_claims', 'timing_sources',
    'banis', 'bani_lines',
)


def fts5_tables(con):
    return [n for (n,) in con.execute(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND lower(sql) LIKE 'create virtual table%using fts5%' ORDER BY name")]


def check(db, required=REQUIRED):
    """Return a list of failure strings (empty == pass)."""
    fails = []
    con = sqlite3.connect(db)
    try:
        ic = [r[0] for r in con.execute('PRAGMA integrity_check')]
        if ic != ['ok']:
            fails.append(f'integrity_check: {ic[:5]}')
        fk = con.execute('PRAGMA foreign_key_check').fetchall()
        if fk:
            fails.append(f'foreign_key_check: {len(fk)} violation(s), first {fk[0]}')
        for t in fts5_tables(con):
            try:
                con.execute(f'INSERT INTO "{t}"("{t}", rank) VALUES(\'integrity-check\', 1)')
            except sqlite3.DatabaseError as e:
                fails.append(f'fts5 integrity-check {t}: {e}')
        have = {n for (n,) in con.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        for t in required:
            if t not in have:
                fails.append(f'missing table: {t}')
            elif con.execute(f'SELECT EXISTS(SELECT 1 FROM "{t}")').fetchone()[0] == 0:
                fails.append(f'empty table: {t}')
        if 'lines' in have:
            n, lo, hi, distinct = con.execute(
                'SELECT count(*), min(ang), max(ang), count(DISTINCT ang) FROM lines').fetchone()
            if n != LINES:
                fails.append(f'lines: {n} rows, expected {LINES}')
            if (lo, hi, distinct) != (1, ANGS, ANGS):
                fails.append(f'angs: min={lo} max={hi} distinct={distinct}, expected 1..{ANGS} contiguous')
    finally:
        con.rollback()
        con.close()
    return fails


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('db')
    ap.add_argument('--require', nargs='*', default=[], help='extra required tables')
    a = ap.parse_args(argv)
    fails = check(a.db, tuple(REQUIRED) + tuple(a.require))
    for f in fails:
        print('FAIL', f)
    if fails:
        print(f'integrity gate: {len(fails)} failure(s) — NOT installing')
        return 1
    print('integrity gate: PASS')
    return 0


if __name__ == '__main__':
    sys.exit(main())
