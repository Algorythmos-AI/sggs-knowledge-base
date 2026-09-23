# -*- coding: utf-8 -*-
"""Install a build artifact over its destination atomically.

    python3 pipeline/atomic_install.py SRC DEST [--expect-sha256 HEX]

SRC is copied to a temp file in DEST's directory (same filesystem), flushed and
fsync'd, its SHA-256 checked against SRC (and --expect-sha256 when given), then
renamed over DEST with os.replace and the directory entry fsync'd. A crash, a
full disk or a failed check at any point leaves DEST exactly as it was — the
canonical corpus/DB is never observed half-written. Stdlib only; Python 3.9+.
"""
import argparse
import hashlib
import os
import shutil
import sys
import tempfile

CHUNK = 1 << 20


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(CHUNK), b''):
            h.update(chunk)
    return h.hexdigest()


def _fsync_dir(path):
    try:
        fd = os.open(path, os.O_RDONLY)
    except OSError:
        return  # platforms without directory fds: rename is still atomic
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def install(src, dest, expect_sha256=None):
    """Atomically replace dest with a verified copy of src; return its sha256."""
    src_sha = sha256_file(src)
    if expect_sha256 and src_sha != expect_sha256.lower():
        raise ValueError(f'{src}: sha256 {src_sha} != expected {expect_sha256}')
    dest_dir = os.path.dirname(os.path.abspath(dest))
    need = os.path.getsize(src)
    free = shutil.disk_usage(dest_dir).free
    if free < need * 2:  # temp copy + headroom; refuse rather than risk ENOSPC mid-write
        raise OSError(f'not enough free space in {dest_dir}: {free} bytes free, need {need * 2}')
    fd, tmp = tempfile.mkstemp(prefix='.' + os.path.basename(dest) + '.', suffix='.tmp', dir=dest_dir)
    try:
        with os.fdopen(fd, 'wb') as out, open(src, 'rb') as inp:
            shutil.copyfileobj(inp, out, CHUNK)
            out.flush()
            os.fsync(out.fileno())
        tmp_sha = sha256_file(tmp)
        if tmp_sha != src_sha:
            raise IOError(f'copy verification failed: {tmp_sha} != {src_sha}')
        if os.path.exists(dest):
            shutil.copymode(dest, tmp)
        os.replace(tmp, dest)
        _fsync_dir(dest_dir)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise
    return src_sha


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('src')
    ap.add_argument('dest')
    ap.add_argument('--expect-sha256')
    a = ap.parse_args(argv)
    sha = install(a.src, a.dest, a.expect_sha256)
    print(f'installed {a.dest} sha256={sha}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
