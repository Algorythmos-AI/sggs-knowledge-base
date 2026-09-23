#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Gate tests for the Nitnem bani registry (standalone, repo style — no pytest).
Runs against a THROWAWAY COPY of the DB so constraint tests can attempt bad
inserts without touching the real file.

Covers
  * the converter tables stay in step with pipeline/shabados_ingest.py;
  * verbatim mode keeps nukta/addak/udaat, fold mode removes them, both move sihari;
  * schema CHECK / FK constraints reject bad rows (two pointers, no pointer, bad source);
  * rebuild idempotency: re-running build_banis.py on the copy yields identical tables;
  * scripture untouched: `lines` byte-identical before/after a rebuild;
  * guard_banis.py passes on the copy.

Usage: python3 pipeline/banis/test_banis_layer.py [--db PATH] [--shabados PATH]
"""
import argparse
import hashlib
import shutil
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import anmol  # noqa: E402

PASS = FAIL = 0


def check(name, cond, detail=''):
    global PASS, FAIL
    PASS += cond
    FAIL += (not cond)
    print('  [%s] %s%s' % ('PASS' if cond else 'FAIL', name, '' if cond or not detail else ' — ' + detail))


def table_hash(con, table):
    h = hashlib.sha256()
    for row in con.execute('SELECT * FROM "%s" ORDER BY rowid' % table):
        h.update(repr(row).encode('utf-8'))
    return h.hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--db', default=str(ROOT / 'db' / 'sggs.sqlite'))
    ap.add_argument('--shabados', default=str(ROOT / 'database.sqlite'))
    args = ap.parse_args()

    print('converter')
    ingest = (ROOT / 'pipeline' / 'shabados_ingest.py').read_text(encoding='utf-8')
    for k, v in anmol.MAP.items():
        if k in ("'", '\\', ' '):
            continue
        check('MAP %r in shabados_ingest.py' % k, ('%r:%r' % (k, v)) in ingest.replace(' ', ''),
              'converter tables drifted apart')
    check('verbatim keeps nukta', anmol.to_unicode('^wlsw', fold=False) == 'ਖ਼ਾਲਸਾ')
    check('verbatim keeps addak', anmol.to_unicode('is`KW', fold=False) == 'ਸਿੱਖਾਂ')
    check('fold removes nukta+addak', anmol.to_unicode('^wlsw is`KW', fold=True) == 'ਖਾਲਸਾ ਸਿਖਾਂ')
    check('sihari moves after its consonant', anmol.to_unicode('inrBau', fold=False) == 'ਨਿਰਭਉ')
    check('vishraam marks dropped', anmol.to_unicode('sUrju; eyko, ruiq.', fold=False) == 'ਸੂਰਜੁ ਏਕੋ ਰੁਤਿ')
    check('Ardaas fill-in slot kept', '…' in anmol.to_unicode('Awp dy hzUr ... dI', fold=False))
    check('Ik Onkar', anmol.to_unicode('<> siqgur pRswid ]', fold=False) == 'ੴ ਸਤਿਗੁਰ ਪ੍ਰਸਾਦਿ ॥')

    tmp = Path(tempfile.mkdtemp(prefix='banis-test-'))
    try:
        db = tmp / 'db.sqlite'
        shutil.copy(args.db, db)
        con = sqlite3.connect(str(db))
        lines_before = table_hash(con, 'lines')
        has = con.execute("SELECT count(*) FROM sqlite_master WHERE name='banis'").fetchone()[0]
        con.close()

        print('build (copy)')
        cmd = [sys.executable, str(HERE / 'build_banis.py'), '--db', str(db),
               '--shabados', args.shabados, '--skip-baseline']
        r = subprocess.run(cmd, capture_output=True, text=True)
        check('build_banis.py exits 0', r.returncode == 0, (r.stderr or r.stdout)[-400:])
        con = sqlite3.connect(str(db))
        check('lines byte-identical after build', table_hash(con, 'lines') == lines_before)
        h1 = {t: table_hash(con, t) for t in ('banis', 'bani_lines', 'extra_lines')}
        n_banis = con.execute('SELECT count(*) FROM banis').fetchone()[0]
        check('23 bani variants', n_banis == 23, str(n_banis))
        con.close()

        print('constraints')
        con = sqlite3.connect(str(db))
        con.execute('PRAGMA foreign_keys=ON')
        bid = con.execute("SELECT bani_id FROM banis WHERE key='japji'").fetchone()[0]

        def rejects(sql, params):
            try:
                con.execute(sql, params)
                con.execute('ROLLBACK') if con.in_transaction else None
                return False
            except sqlite3.IntegrityError:
                return True
        check('two pointers rejected', rejects(
            'INSERT INTO bani_lines VALUES (?, 99999, 1, 1, 1)', (bid,)))
        check('no pointer rejected', rejects(
            'INSERT INTO bani_lines VALUES (?, 99999, 1, NULL, NULL)', (bid,)))
        check('dangling line_id rejected', rejects(
            'INSERT INTO bani_lines VALUES (?, 99999, 1, 99999999, NULL)', (bid,)))
        check('bad extra source rejected', rejects(
            "INSERT INTO extra_lines(source, gurmukhi, translit, shabados_line_id) VALUES ('sggs','x','x','ZZZZ')", ()))
        check('bad category rejected', rejects(
            "INSERT INTO banis(key, title_gm, title_en, category, order_no, n_lines, n_groups, has_extra, source_label) "
            "VALUES ('x','x','x','nope',1,1,1,0,'x')", ()))
        con.rollback()
        con.close()

        print('idempotency')
        r = subprocess.run(cmd, capture_output=True, text=True)
        check('second build exits 0', r.returncode == 0, (r.stderr or r.stdout)[-400:])
        con = sqlite3.connect(str(db))
        h2 = {t: table_hash(con, t) for t in ('banis', 'bani_lines', 'extra_lines')}
        check('registry tables identical on rebuild', h1 == h2)
        check('lines still byte-identical', table_hash(con, 'lines') == lines_before)
        con.close()

        print('guard')
        r = subprocess.run([sys.executable, str(HERE / 'guard_banis.py'), '--db', str(db)],
                           capture_output=True, text=True)
        check('guard_banis.py passes', r.returncode == 0, (r.stderr or r.stdout)[-600:])
        if has:
            print('  (source DB already carried the registry; rebuilt from scratch on the copy)')
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    print('\n%d passed, %d failed' % (PASS, FAIL))
    return 1 if FAIL else 0


if __name__ == '__main__':
    sys.exit(main())
