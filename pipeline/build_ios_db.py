#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_ios_db.py — derive the iOS database from the full corpus DB, in one of two PROFILES.

  --profile personal  (default; the bundled ios/Resources/sggs-ios.sqlite)
      Keeps the `translations` table + `fts_en` index (Dr. Sant Singh Khalsa English,
      via ShabadOS — see NOTICE.md). PERSONAL, LOCAL, NON-COMMERCIAL USE ONLY.
      Any public/App Store release with this profile is BLOCKED by
      pipeline/check_release_license.sh until the translation is licensed in writing.

  --profile public
      Gurmukhi-only: drops `translations` + `fts_en`. This is the only profile eligible
      for public distribution today. Written to a separate (git-ignored) artifact so it
      can never silently replace the bundled personal DB.

Both profiles carry every other table verbatim — including the v2.12.0 additive timing
layer (timing_sources, raag_timing_claims, shabd_* form tables) when present in the source.

Prime directive: this NEVER alters scripture. The `lines` table (the verbatim Gurmukhi)
is byte-for-byte unchanged — proven below by comparing the line count and a checksum of
every `gurmukhi` value against the source DB.

Usage:  python3 pipeline/build_ios_db.py [--profile personal|public] [source-db] [dest-db]
  defaults: source db/sggs.sqlite
            dest   personal -> ios/Resources/sggs-ios.sqlite
                   public   -> ios/Resources/sggs-ios-public.sqlite  (git-ignored)
"""
import argparse, os, sys, json, shutil, sqlite3, hashlib

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

# The translation layer (the only license-restricted content in the DB).
TRANSLATION_LAYER = ['translations', 'fts_en']
# Timing-layer tables expected from DB v2.12.0+ (additive; informational detection only).
TIMING_TABLES = ['timing_sources', 'raag_timing_claims', 'shabd_raag_map',
                 'shabd_musical_markers', 'shabd_structural_form', 'shabd_poetic_genre']
# Nitnem bani registry (migration 002; additive). `extra_lines` is non-SGGS text (Sri Dasam
# Granth / Ardaas) — a separate labelled layer that must never carry an English column.
BANI_TABLES = ['banis', 'bani_lines', 'extra_lines']


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
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--profile', choices=['personal', 'public'], default='personal')
    ap.add_argument('source', nargs='?', default=os.path.join(ROOT, 'db', 'sggs.sqlite'))
    ap.add_argument('dest', nargs='?', default=None)
    args = ap.parse_args()

    profile = args.profile
    src_path = args.source
    dest = args.dest or os.path.join(
        ROOT, 'ios', 'Resources',
        'sggs-ios.sqlite' if profile == 'personal' else 'sggs-ios-public.sqlite')
    drop = [] if profile == 'personal' else list(TRANSLATION_LAYER)

    if not os.path.exists(src_path):
        sys.exit(f'source DB not found: {src_path}')
    os.makedirs(os.path.dirname(dest), exist_ok=True)

    # baseline scripture checksum from the source (read-only)
    src = sqlite3.connect(f'file:{src_path}?mode=ro&immutable=1', uri=True)
    src_ck = scripture_checksum(src)
    src_inv = invariants(src)
    src.close()
    print(f'profile: {profile}')
    print(f'source: {src_inv}  scripture_sha={src_ck[:16]}…')

    print(f'copy {src_path} -> {dest}')
    shutil.copyfile(src_path, dest)

    con = sqlite3.connect(dest)
    present = {r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type IN ('table','view')")}
    for t in drop:
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
    extra_cols = ({r[1] for r in con.execute("PRAGMA table_info('extra_lines')")}
                  if 'extra_lines' in remaining else set())
    con.close()

    assert dst_ck == src_ck, 'SCRIPTURE CHANGED — aborting (this must never happen)'
    assert dst_inv['lines'] == src_inv['lines'] == 60658, f"line count {dst_inv['lines']}"
    assert dst_inv['angs'] == 1430, f"ang count {dst_inv['angs']}"
    assert dst_inv['ik_onkar'] >= 560, f"ੴ count {dst_inv['ik_onkar']}"
    assert dst_inv['fts_ok'] and dst_inv['mool_mantar'], 'FTS/Mool Mantar check failed'

    en_bundled = 'translations' in remaining and 'fts_en' in remaining
    timing_bundled = all(t in remaining for t in TIMING_TABLES)
    banis_bundled = all(t in remaining for t in BANI_TABLES)
    if banis_bundled:
        assert not (extra_cols & {'en', 'english', 'translation'}), 'extra_lines must never carry English'
        assert not any(t.startswith('extra_trans') for t in remaining), 'no translations for extra text'
    if profile == 'public':
        assert not en_bundled and 'translations' not in remaining and 'fts_en' not in remaining, \
            'translation layer not removed from the PUBLIC profile'
    else:
        assert en_bundled, 'personal profile expected translations + fts_en in the source DB'

    db_sha = sha256_file(dest)
    manifest = {
        'name': f'SGGS iOS DB ({ "personal — bundled English" if profile == "personal" else "Gurmukhi-only" })',
        'profile': profile,
        'en_bundled': en_bundled,
        'timing_bundled': timing_bundled,
        'banis_bundled': banis_bundled,
        'derived_from': os.path.relpath(src_path, ROOT),
        'dropped': drop,
        'bytes': os.path.getsize(dest),
        'db_sha256': db_sha,
        'scripture_sha256': dst_ck,
        'invariants': dst_inv,
    }
    stem = os.path.splitext(os.path.basename(dest))[0]
    mpath = os.path.join(os.path.dirname(dest), f'{stem}.manifest.json')
    with open(mpath, 'w', encoding='utf-8') as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write('\n')

    src_mb = os.path.getsize(src_path) / 1e6
    dst_mb = manifest['bytes'] / 1e6
    layer = 'translations kept ✓' if en_bundled else 'translations removed ✓'
    print(f'OK  scripture byte-identical ✓  invariants ✓  {layer}  timing={"✓" if timing_bundled else "ABSENT"}  banis={"✓" if banis_bundled else "ABSENT"}')
    print(f'    size {src_mb:.1f} MB -> {dst_mb:.1f} MB   db_sha256={db_sha[:16]}…')
    print(f'    manifest -> {mpath}')
    if en_bundled:
        print()
        print('  ⚠ LICENSE (NOTICE.md): this build embeds the Khalsa English translation —')
        print('    personal, local, non-commercial use ONLY. Do NOT distribute (TestFlight or')
        print('    App Store) until the licence is recorded in ios/Resources/TRANSLATION-LICENSE.md')
        print('    (LICENSED: true) — pipeline/check_release_license.sh enforces this.')


if __name__ == '__main__':
    main()
