#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_ios_db.py — derive the GURMUKHI-ONLY iOS database from the full corpus DB.

Why: NOTICE.md restricts the bundled English (Khalsa/ShabadOS) translation to personal,
non-commercial use; App Store distribution is public redistribution. So the iOS v1 ships a
variant with the `translations` table + the `fts_en` index removed. The English layer returns
in a later version once licensed in writing.

Prime directive: this NEVER alters scripture. Only the translation layer is dropped; the
`lines` table (the verbatim Gurmukhi) is byte-for-byte unchanged — proven below by comparing
the line count and a checksum of every `gurmukhi` value against the source DB.

Usage:  python3 pipeline/build_ios_db.py [source-db] [dest-db]
  defaults: db/sggs.sqlite  ->  ios/Resources/sggs-ios.sqlite
"""
import os, sys, json, shutil, sqlite3, hashlib

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'db', 'sggs.sqlite')
DEST = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, 'ios', 'Resources', 'sggs-ios.sqlite')

# Tables/indexes dropped for the Gurmukhi-only build (translation layer only).
DROP = ['translations', 'fts_en']


def scripture_checksum(con):
    """Order-independent-but-deterministic checksum of the verbatim scripture column."""
    h = hashlib.sha256()
    for (lid, g) in con.execute("SELECT id, gurmukhi FROM lines ORDER BY id"):
        h.update(str(lid).encode()); h.update(b'\x00'); h.update((g or '').encode('utf-8')); h.update(b'\n')
    return h.hexdigest()


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def invariants(con):
    """The /api/health-equivalent integrity invariants the iOS app will re-assert at launch."""
    lines = con.execute("SELECT count(*) FROM lines").fetchone()[0]
    angs = con.execute("SELECT count(DISTINCT ang) FROM lines").fetchone()[0]
    ik = con.execute("SELECT count(*) FROM (SELECT rowid FROM fts WHERE text MATCH 'ੴ')").fetchone()[0]
    fts_ok = con.execute("SELECT count(*) FROM fts WHERE text MATCH 'ਨਾਮੁ'").fetchone()[0] > 0
    mool = (con.execute("SELECT gurmukhi FROM lines WHERE id=1").fetchone()[0] or '').startswith(
        'ੴ ਸਤਿ ਨਾਮੁ ਕਰਤਾ ਪੁਰਖੁ ਨਿਰਭਉ ਨਿਰਵੈਰੁ')
    return {'lines': lines, 'angs': angs, 'ik_onkar': ik, 'fts_ok': fts_ok, 'mool_mantar': mool}


def main():
    if not os.path.exists(SRC):
        sys.exit(f'source DB not found: {SRC}')
    os.makedirs(os.path.dirname(DEST), exist_ok=True)

    # baseline scripture checksum from the source (read-only)
    src = sqlite3.connect(f'file:{SRC}?mode=ro&immutable=1', uri=True)
    src_ck = scripture_checksum(src)
    src_inv = invariants(src)
    src.close()
    print(f'source: {src_inv}  scripture_sha={src_ck[:16]}…')

    print(f'copy {SRC} -> {DEST}')
    shutil.copyfile(SRC, DEST)

    con = sqlite3.connect(DEST)
    present = {r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type IN ('table','view')")}
    for t in DROP:
        if t in present:
            con.execute(f'DROP TABLE IF EXISTS "{t}"')
            print(f'  dropped {t}')
        else:
            print(f'  (skip {t}: not present)')
    con.commit()
    con.execute('VACUUM')
    con.commit()

    # verify scripture is byte-identical and invariants still hold
    dst_ck = scripture_checksum(con)
    dst_inv = invariants(con)
    remaining = {r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type IN ('table','view')")}
    con.close()

    assert dst_ck == src_ck, 'SCRIPTURE CHANGED — aborting (this must never happen)'
    assert dst_inv['lines'] == src_inv['lines'] == 60658, f"line count {dst_inv['lines']}"
    assert dst_inv['angs'] == 1430, f"ang count {dst_inv['angs']}"
    assert dst_inv['ik_onkar'] >= 560, f"ੴ count {dst_inv['ik_onkar']}"
    assert dst_inv['fts_ok'] and dst_inv['mool_mantar'], 'FTS/Mool Mantar check failed'
    assert 'translations' not in remaining and 'fts_en' not in remaining, 'translation layer not removed'

    db_sha = sha256_file(DEST)
    manifest = {
        'name': 'SGGS iOS DB (Gurmukhi-only)',
        'derived_from': os.path.relpath(SRC, ROOT),
        'dropped': DROP,
        'bytes': os.path.getsize(DEST),
        'db_sha256': db_sha,
        'scripture_sha256': dst_ck,
        'invariants': dst_inv,
    }
    mpath = os.path.join(os.path.dirname(DEST), 'sggs-ios.manifest.json')
    with open(mpath, 'w', encoding='utf-8') as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write('\n')

    src_mb = os.path.getsize(SRC) / 1e6
    dst_mb = manifest['bytes'] / 1e6
    print(f'OK  scripture byte-identical ✓  invariants ✓  translations removed ✓')
    print(f'    size {src_mb:.1f} MB -> {dst_mb:.1f} MB   db_sha256={db_sha[:16]}…')
    print(f'    manifest -> {mpath}')


if __name__ == '__main__':
    main()
