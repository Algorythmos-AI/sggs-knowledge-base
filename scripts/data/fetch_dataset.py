#!/usr/bin/env python3
"""Fetch the pinned scripture database from sggs-data and install it, verified.

The platform does not own the database: it consumes the exact object recorded in
dataset.lock.json (a commit of Algorythmos-AI/sggs-data plus the database's sha256 and
size). This script is the only way CI and the image build obtain it.

    python3 scripts/data/fetch_dataset.py                 # install db/sggs.sqlite from the pin
    python3 scripts/data/fetch_dataset.py --check-pin     # prove sggs-data@commit holds that object

Guarantees (fail closed on any of them):
  * the bytes written equal the lock's sha256 and size (Git LFS oids are content sha256s,
    so this is the same identity the data repository records);
  * the destination is replaced atomically (same-directory temp file, fsync, os.replace) —
    a failed or interrupted fetch never leaves a truncated database behind;
  * --check-pin reads the LFS pointer committed at the pinned sggs-data commit and requires
    it to name the same oid and size, so a lock cannot point at an object the data
    repository never published.

Stdlib only. A token (GH_TOKEN or GITHUB_TOKEN) is sent when present, which is what a
private sggs-data needs; a public one works without it.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import shutil
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LOCK = ROOT / "dataset.lock.json"
CHUNK = 1 << 20
RETRIES = 4


def load_lock(path: Path = LOCK) -> dict:
    lock = json.loads(path.read_text(encoding="utf-8"))
    db = lock.get("database") or {}
    for key, ok in (
        ("repository", isinstance(lock.get("repository"), str) and lock["repository"].count("/") == 1),
        ("commit", isinstance(lock.get("commit"), str) and len(lock["commit"]) == 40),
        ("database.path", isinstance(db.get("path"), str) and db["path"]),
        ("database.sha256", isinstance(db.get("sha256"), str) and len(db["sha256"]) == 64),
        ("database.size", isinstance(db.get("size"), int) and db["size"] > 0),
    ):
        if not ok:
            raise SystemExit(f"dataset.lock.json: missing or malformed {key}")
    return lock


def _token() -> str | None:
    return os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN") or None


def _request(url: str, *, data: bytes | None = None, headers: dict | None = None,
             token_scheme: str | None = None):
    hdrs = {"User-Agent": "sggs-fetch-dataset"}
    hdrs.update(headers or {})
    tok = _token()
    if tok and token_scheme == "bearer":
        hdrs["Authorization"] = f"Bearer {tok}"
    elif tok and token_scheme == "basic":
        hdrs["Authorization"] = "Basic " + base64.b64encode(f"x-access-token:{tok}".encode()).decode()
    return urllib.request.Request(url, data=data, headers=hdrs)


def _open(req, timeout: int = 60):
    """urlopen with bounded retries on transient failures (5xx, 429, network).

    A 401/403 while sending a token is retried once without it: a CI token scoped to another
    repository must not stop an anonymous read of a public sggs-data.
    """
    for attempt in range(1, RETRIES + 1):
        try:
            return urllib.request.urlopen(req, timeout=timeout)
        except urllib.error.HTTPError as e:
            if e.code in (401, 403) and req.has_header("Authorization"):
                req.remove_header("Authorization")
                continue
            if e.code < 500 and e.code != 429 or attempt == RETRIES:
                raise
        except (urllib.error.URLError, TimeoutError, ConnectionError):
            if attempt == RETRIES:
                raise
        time.sleep(2 ** attempt)
    raise AssertionError("unreachable")


def sha256_file(path: Path) -> tuple[str, int]:
    h, n = hashlib.sha256(), 0
    with open(path, "rb") as f:
        while chunk := f.read(CHUNK):
            h.update(chunk)
            n += len(chunk)
    return h.hexdigest(), n


def _matches(path: Path, sha: str, size: int) -> bool:
    return path.is_file() and path.stat().st_size == size and sha256_file(path) == (sha, size)


def _download_href(lock: dict) -> tuple[str, dict]:
    """Ask the Git LFS batch API of sggs-data where the pinned object lives."""
    db = lock["database"]
    body = json.dumps({
        "operation": "download", "transfers": ["basic"], "ref": {"name": "refs/heads/main"},
        "objects": [{"oid": db["sha256"], "size": db["size"]}],
    }).encode()
    req = _request(f"https://github.com/{lock['repository']}.git/info/lfs/objects/batch", data=body,
                   headers={"Accept": "application/vnd.git-lfs+json",
                            "Content-Type": "application/vnd.git-lfs+json"},
                   token_scheme="basic")
    with _open(req) as r:
        resp = json.load(r)
    obj = (resp.get("objects") or [{}])[0]
    if "error" in obj:
        raise SystemExit(f"sggs-data LFS: {obj['error'].get('message', obj['error'])}")
    action = (obj.get("actions") or {}).get("download") or {}
    if not action.get("href"):
        raise SystemExit("sggs-data LFS: no download action returned for the pinned object")
    return action["href"], action.get("header") or {}


def _stream_verified(lock: dict, dest: Path) -> None:
    """Download into a same-directory temp file, verify, fsync, then atomically replace dest."""
    db = lock["database"]
    href, headers = _download_href(lock)
    dest.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=f".{dest.name}.", suffix=".part", dir=dest.parent)
    try:
        h, n = hashlib.sha256(), 0
        with os.fdopen(fd, "wb") as out, _open(_request(href, headers=headers), timeout=300) as r:
            while chunk := r.read(CHUNK):
                h.update(chunk)
                n += len(chunk)
                if n > db["size"]:
                    raise SystemExit(f"download exceeded the pinned size ({db['size']} bytes)")
                out.write(chunk)
            out.flush()
            os.fsync(out.fileno())
        if (h.hexdigest(), n) != (db["sha256"], db["size"]):
            raise SystemExit(f"download does not match the pin: sha256 {h.hexdigest()} size {n}")
        os.replace(tmp, dest)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def _install_copy(src: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=f".{dest.name}.", suffix=".part", dir=dest.parent)
    try:
        with os.fdopen(fd, "wb") as out, open(src, "rb") as f:
            shutil.copyfileobj(f, out, CHUNK)
            out.flush()
            os.fsync(out.fileno())
        os.replace(tmp, dest)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def fetch(lock: dict, dest: Path, cache_dir: Path | None) -> str:
    db = lock["database"]
    sha, size = db["sha256"], db["size"]
    if _matches(dest, sha, size):
        return "already installed"
    if cache_dir is not None:
        cached = cache_dir / sha
        if not _matches(cached, sha, size):
            _stream_verified(lock, cached)
            how = "downloaded"
        else:
            how = "from cache"
        _install_copy(cached, dest)
    else:
        _stream_verified(lock, dest)
        how = "downloaded"
    if not _matches(dest, sha, size):          # belt and braces: re-read what was installed
        raise SystemExit(f"{dest} does not match the pin after install")
    return how


def check_pin(lock: dict) -> None:
    """The LFS pointer committed at sggs-data@commit must name exactly the pinned object."""
    db = lock["database"]
    url = (f"https://api.github.com/repos/{lock['repository']}/contents/{db['path']}"
           f"?ref={lock['commit']}")
    req = _request(url, headers={"Accept": "application/vnd.github.raw",
                                 "X-GitHub-Api-Version": "2022-11-28"}, token_scheme="bearer")
    with _open(req) as r:
        pointer = r.read(1024).decode("utf-8", "replace")
    fields = dict(line.split(" ", 1) for line in pointer.strip().splitlines() if " " in line)
    oid = fields.get("oid", "").removeprefix("sha256:")
    size = int(fields.get("size", "-1"))
    if (oid, size) != (db["sha256"], db["size"]):
        raise SystemExit(f"pin mismatch: {lock['repository']}@{lock['commit'][:12]}:{db['path']} "
                         f"is oid {oid or '?'} size {size}, lock says {db['sha256']} {db['size']}")


def check_repo(lock: dict) -> list[str]:
    """Every in-repo record of the database identity must agree with the lock."""
    import subprocess

    sha = lock["database"]["sha256"]
    problems = []
    for rel, key in (("MANIFEST.json", "db_sha256"), ("contract/_meta.json", "db_sha256")):
        path = ROOT / rel
        if path.exists():
            got = json.loads(path.read_text(encoding="utf-8")).get(key)
            if got != sha:
                problems.append(f"{rel}:{key} = {got}, lock = {sha}")
    version_file = ROOT / "DATASET_VERSION"
    if version_file.exists() and version_file.read_text().strip() != lock.get("dataset_version"):
        problems.append(f"DATASET_VERSION = {version_file.read_text().strip()}, "
                        f"lock = {lock.get('dataset_version')}")
    # While the database is still tracked here, its committed LFS pointer must name the pin.
    pointer = subprocess.run(["git", "-C", str(ROOT), "cat-file", "-p", f"HEAD:{lock['database']['path']}"],
                             capture_output=True, text=True)
    if pointer.returncode == 0 and pointer.stdout.startswith("version https://git-lfs"):
        fields = dict(l.split(" ", 1) for l in pointer.stdout.splitlines() if " " in l)
        oid = fields.get("oid", "").removeprefix("sha256:")
        if (oid, int(fields.get("size", "-1"))) != (sha, lock["database"]["size"]):
            problems.append(f"tracked {lock['database']['path']} is oid {oid}, lock = {sha}")
    return problems


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--lock", type=Path, default=LOCK)
    ap.add_argument("--dest", type=Path, help="install path (default: the lock's database.path)")
    ap.add_argument("--cache-dir", type=Path, help="keep verified objects here, keyed by sha256")
    ap.add_argument("--check-pin", action="store_true",
                    help="only verify that sggs-data@commit publishes the pinned object")
    ap.add_argument("--check-repo", action="store_true",
                    help="only verify MANIFEST, contract/_meta.json and DATASET_VERSION agree with the lock")
    a = ap.parse_args(argv)
    lock = load_lock(a.lock)
    db = lock["database"]
    if a.check_repo:
        problems = check_repo(lock)
        for p in problems:
            print(f"::error::{p}")
        if problems:
            return 1
        print(f"lock OK: dataset {lock.get('dataset_version')} {db['sha256'][:12]} agrees with this repository")
        return 0
    if a.check_pin:
        check_pin(lock)
        print(f"pin OK: {lock['repository']}@{lock['commit'][:12]} {db['path']} = {db['sha256'][:12]}")
        return 0
    dest = a.dest or (ROOT / db["path"])
    how = fetch(lock, dest, a.cache_dir)
    print(f"dataset {lock.get('dataset_version', '?')} {db['sha256'][:12]} -> {dest} ({how})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
