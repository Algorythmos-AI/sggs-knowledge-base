#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check_ios_db_pair.py — is the iOS DB on disk the one its manifest describes?

The app bundles ios/Resources/sggs-ios.sqlite + sggs-ios.manifest.json and fail-closes at launch
("Scripture integrity check failed") when the DB does not hash to the manifest's db_sha256. The DB
is git-ignored, so it survives branch switches and is absent from a fresh worktree; the manifest is
tracked. This check is READ-ONLY: it never writes, rebuilds, or runs a git command that changes
the working tree.

  HARD (exit 1) — the app/tests WILL break: DB missing, not a SQLite file (LFS pointer / partial
                  write), sha256 != the on-disk manifest, or the manifest is the wrong profile.
  WARN (exit 0) — the pair is consistent but the manifest differs from HEAD. Do not commit it
                  unless this is an intentional DB re-baseline (sggs-rebuild-db).

Usage:  python3 pipeline/check_ios_db_pair.py [manifest] [db] [--expect-profile personal|public]
"""
import argparse, hashlib, json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
REPAIR = 'make ios-db-repair   (= python3 pipeline/build_ios_db.py --profile personal)'


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def sqlite_writer_version(path):
    """SQLITE_VERSION_NUMBER of the library that last wrote the file (header bytes 96-99)."""
    with open(path, 'rb') as f:
        f.seek(96)
        n = int.from_bytes(f.read(4), 'big')
    return f'{n // 1000000}.{n // 1000 % 1000}.{n % 1000}'


def check(manifest_path, db_path, expect_profile='personal'):
    """Returns (hard_failures, warnings) — two lists of strings."""
    hard, warn = [], []
    if not os.path.isfile(manifest_path):
        return [f'manifest missing: {manifest_path}'], warn
    try:
        with open(manifest_path, encoding='utf-8') as f:
            manifest = json.load(f)
        want, profile = manifest['db_sha256'], manifest['profile']
    except (ValueError, KeyError) as e:
        return [f'manifest unreadable ({manifest_path}): {e!r}'], warn

    if not os.path.isfile(db_path):
        return [f'DB missing: {db_path} (git-ignored — a fresh clone/worktree has none)'], warn
    with open(db_path, 'rb') as f:
        if f.read(16) != b'SQLite format 3\x00':
            return [f'not a SQLite file: {db_path} (LFS pointer or interrupted write)'], warn

    if profile != expect_profile:
        hard.append(f'manifest profile is "{profile}", expected "{expect_profile}"')
    got = sha256_file(db_path)
    if got != want:
        hard.append(f'DB sha256 {got[:16]}… != manifest db_sha256 {want[:16]}… '
                    f'(DB last written by SQLite {sqlite_writer_version(db_path)}; usual causes: '
                    f'a branch switch, or a build for another profile/branch)')

    if not hard:
        rel = os.path.relpath(os.path.abspath(manifest_path), ROOT)
        if not rel.startswith('..'):
            r = subprocess.run(['git', '-C', ROOT, 'diff', '--quiet', 'HEAD', '--', rel],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if r.returncode == 1:
                warn.append(f'{rel} differs from HEAD (DB written by SQLite '
                            f'{sqlite_writer_version(db_path)}) — the pair is consistent, but do NOT '
                            f'commit the manifest unless this is an intentional DB re-baseline')
    return hard, warn


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('manifest', nargs='?', default=os.path.join(ROOT, 'ios', 'Resources', 'sggs-ios.manifest.json'))
    ap.add_argument('db', nargs='?', default=None)
    ap.add_argument('--expect-profile', choices=['personal', 'public'], default='personal')
    args = ap.parse_args(argv)
    db = args.db or args.manifest[:-len('.manifest.json')] + '.sqlite'

    hard, warn = check(args.manifest, db, args.expect_profile)
    for w in warn:
        print(f'  WARN  {w}')
    if hard:
        for h in hard:
            print(f'  FAIL  {h}')
        print(f'  the iOS app will show "Scripture integrity check failed" and tests will fail.')
        print(f'  repair: {REPAIR}')
        return 1
    print(f'ios-db pair: OK ({args.expect_profile}) — DB hashes to its manifest')
    return 0


if __name__ == '__main__':
    sys.exit(main())
