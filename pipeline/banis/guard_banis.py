#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
guard_banis.py — standing invariants for the Nitnem bani registry (migration 002).

Exit 0 = PASS, 1 = FAIL with a per-check report. Read-only.

Checks
  * schema present (banis, bani_lines, extra_lines) and every bani_lines pointer resolves
    (line_id -> lines.id, extra_id -> extra_lines.extra_id); exactly one pointer per row;
  * seq is dense 1..n_lines per bani and n_lines/n_groups/has_extra agree with the rows;
  * one default variant per key; keys match ^[a-z0-9_]{1,32}$;
  * canonical boundaries: Japji == lines 1..385 in order; Sohila == 534..589;
    Anand == 39333..39542; Salok M9 == 60469..60585; Rehras (SGPC) contains So Dar +
    So Purakh (386..533) contiguously; Sukhmani spans 11579..13616;
  * extra_lines carries NO English column and no extra_lines text equals any SGGS line
    (catches a source mix-up); every extra line has non-empty Gurmukhi and a source;
  * reading order inside a line_group of SGGS lines is ascending line_id (printed order).

Usage: python3 pipeline/banis/guard_banis.py [--db PATH]
"""
import argparse
import re
import sqlite3
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
KEY_RE = re.compile(r'^[a-z0-9_]{1,32}$')
FAILS = []


def check(name, cond, detail=''):
    print('  [%s] %s%s' % ('PASS' if cond else 'FAIL', name, ('' if cond else ' — ' + detail)))
    if not cond:
        FAILS.append(name)


def ids(con, key, variant=None):
    if variant is None:
        q = 'SELECT bl.line_id FROM bani_lines bl JOIN banis b USING(bani_id) WHERE b.key=? AND b.is_default=1 ORDER BY bl.seq'
        return [r[0] for r in con.execute(q, (key,))]
    q = 'SELECT bl.line_id FROM bani_lines bl JOIN banis b USING(bani_id) WHERE b.key=? AND b.variant=? ORDER BY bl.seq'
    return [r[0] for r in con.execute(q, (key, variant))]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--db', default=str(ROOT / 'db' / 'sggs.sqlite'))
    args = ap.parse_args()
    con = sqlite3.connect('file:%s?mode=ro' % Path(args.db).resolve(), uri=True)
    print('GUARD (banis): %s' % args.db)
    tables = {r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='table'")}
    check('schema present', {'banis', 'bani_lines', 'extra_lines'} <= tables)
    if FAILS:
        return finish()

    n_dangling = con.execute(
        'SELECT count(*) FROM bani_lines bl LEFT JOIN lines l ON l.id = bl.line_id '
        'WHERE bl.line_id IS NOT NULL AND l.id IS NULL').fetchone()[0]
    n_dangling_e = con.execute(
        'SELECT count(*) FROM bani_lines bl LEFT JOIN extra_lines e ON e.extra_id = bl.extra_id '
        'WHERE bl.extra_id IS NOT NULL AND e.extra_id IS NULL').fetchone()[0]
    check('every pointer resolves', n_dangling == 0 and n_dangling_e == 0,
          'dangling line=%d extra=%d' % (n_dangling, n_dangling_e))
    both = con.execute('SELECT count(*) FROM bani_lines WHERE (line_id IS NULL) = (extra_id IS NULL)').fetchone()[0]
    check('exactly one pointer per row', both == 0, '%d rows' % both)

    for bid, key, variant, n_lines, n_groups, has_extra in con.execute(
            'SELECT bani_id, key, variant, n_lines, n_groups, has_extra FROM banis'):
        rows = con.execute('SELECT seq, line_group, line_id, extra_id FROM bani_lines WHERE bani_id=? ORDER BY seq',
                           (bid,)).fetchall()
        label = key + (('/' + variant) if variant else '')
        check('%s: key well-formed' % label, bool(KEY_RE.match(key)))
        check('%s: seq dense 1..n' % label, [r[0] for r in rows] == list(range(1, len(rows) + 1)))
        check('%s: n_lines/n_groups/has_extra agree' % label,
              n_lines == len(rows) and n_groups == max(r[1] for r in rows)
              and has_extra == int(any(r[3] for r in rows)))
        # printed order inside a group: ascending line ids for SGGS runs
        ok = True
        for g in range(1, n_groups + 1):
            lids = [r[2] for r in rows if r[1] == g and r[2] is not None]
            if lids != sorted(lids) or len(set(lids)) != len(lids):
                ok = False
        check('%s: SGGS groups in printed order, no repeats' % label, ok)

    keys = [r[0] for r in con.execute('SELECT key FROM banis GROUP BY key HAVING sum(is_default) <> 1')]
    check('one default variant per key', not keys, str(keys))

    check('Japji == lines 1..385', ids(con, 'japji') == list(range(1, 386)))
    check('Sohila == lines 534..589', ids(con, 'sohila') == list(range(534, 590)))
    check('Anand == lines 39333..39542', ids(con, 'anand') == list(range(39333, 39543)))
    check('Salok M9 == lines 60469..60585', ids(con, 'salok_m9') == list(range(60469, 60586)))
    r = [i for i in ids(con, 'rehras', 'sgpc') if i is not None]
    check('Rehras (SGPC) contains So Dar + So Purakh 386..533 contiguously',
          any(r[i:i + 148] == list(range(386, 534)) for i in range(len(r))))
    sk = [i for i in ids(con, 'sukhmani') if i is not None]
    check('Sukhmani spans 11579..13616 and contains 11590..13616 contiguously',
          bool(sk) and min(sk) == 11579 and max(sk) == 13616
          and any(sk[i:i + 2027] == list(range(11590, 13617)) for i in range(len(sk))))

    cols = {r[1] for r in con.execute("PRAGMA table_info('extra_lines')")}
    check('extra_lines has no English column', not (cols & {'en', 'english', 'translation', 'text_en'}))
    check('no extra translations table', not any(t.startswith('extra_trans') for t in tables))
    empty = con.execute("SELECT count(*) FROM extra_lines WHERE trim(gurmukhi)='' OR source NOT IN ('dasam','ardaas')").fetchone()[0]
    check('every extra line has text and a source', empty == 0, '%d bad' % empty)
    sggs = {unicodedata.normalize('NFC', g) for (g,) in con.execute('SELECT gurmukhi FROM lines')}
    mixed = [g for (g,) in con.execute('SELECT gurmukhi FROM extra_lines')
             if unicodedata.normalize('NFC', g) in sggs and len(g) > 20]
    check('no extra line duplicates an SGGS line (source mix-up)', not mixed, str(mixed[:3]))
    return finish()


def finish():
    print()
    if FAILS:
        print('GUARD (banis) FAIL: %s' % ', '.join(FAILS), file=sys.stderr)
        return 1
    print('GUARD (banis) PASS')
    return 0


if __name__ == '__main__':
    sys.exit(main())
