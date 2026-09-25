#!/usr/bin/env python3
"""Install the sibling repositories' documentation at pinned commits, verified (docs-site/sources.lock.json).

The wiki (docs.gurbanisoul.com) publishes sggs-data's and gurbani-soul-ios's docs next to this
repository's, but never copies them into git: exactly like the dataset (ADR-0008) it records a
commit plus the sha256 of every file, and installs those bytes under docs-site/.sources/ at build.

    python3 tools/fetch_sibling_docs.py                  # install every pinned file (skips ones already present and matching)
    python3 tools/fetch_sibling_docs.py --check          # the lock is well-formed and every file exists at its commit (no install)
    python3 tools/fetch_sibling_docs.py --update NAME    # re-pin NAME to its `ref` (tip of a branch or a tag) and rewrite the lock

Installed copies are normalised for the site: a page without frontmatter gets `title` (its H1)
and `description` (its first paragraph), plus `source: {repository, commit, path}` so the site can
say where the canonical file lives. The raw bytes are what the sha256 covers.

Stdlib only. GH_TOKEN / GITHUB_TOKEN / SGGS_READ_TOKEN is sent when present (a private repository
needs it); a 401/403 with a token is retried once without it.
"""
from __future__ import annotations

import argparse
import base64
import fnmatch
import hashlib
import json
import os
import re
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCK = ROOT / "docs-site" / "sources.lock.json"
DEST = ROOT / "docs-site" / ".sources"
API = "https://api.github.com"
RETRIES = 4


def _token() -> str | None:
    return os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN") or os.environ.get("SGGS_READ_TOKEN") or None


def _get(url: str, accept: str = "application/vnd.github+json") -> bytes:
    hdrs = {"User-Agent": "sggs-fetch-sibling-docs", "Accept": accept, "X-GitHub-Api-Version": "2022-11-28"}
    tok = _token()
    if tok:
        hdrs["Authorization"] = f"Bearer {tok}"
    req = urllib.request.Request(url, headers=hdrs)
    for attempt in range(1, RETRIES + 1):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code in (401, 403) and req.has_header("Authorization"):
                req.remove_header("Authorization")
                continue
            if (e.code < 500 and e.code != 429) or attempt == RETRIES:
                raise
        except (urllib.error.URLError, TimeoutError, ConnectionError):
            if attempt == RETRIES:
                raise
        time.sleep(2 ** attempt)
    raise AssertionError("unreachable")


def load_lock() -> dict:
    lock = json.loads(LOCK.read_text(encoding="utf-8"))
    for name, s in lock.get("sources", {}).items():
        for key, ok in (("repository", isinstance(s.get("repository"), str) and s["repository"].count("/") == 1),
                        ("ref", isinstance(s.get("ref"), str) and s["ref"]),
                        ("commit", isinstance(s.get("commit"), str) and re.fullmatch(r"[0-9a-f]{40}", s["commit"])),
                        ("alias", isinstance(s.get("alias"), str) and re.fullmatch(r"[a-z][a-z0-9-]*", s["alias"])),
                        ("include", isinstance(s.get("include"), list) and all(isinstance(g, str) for g in s["include"])),
                        ("files", isinstance(s.get("files"), dict))):
            if not ok:
                raise SystemExit(f"sources.lock.json: {name}: missing or malformed {key}")
        for path, rec in s["files"].items():
            if not (isinstance(rec, dict) and re.fullmatch(r"[0-9a-f]{64}", str(rec.get("sha256", "")))
                    and re.fullmatch(r"[0-9a-f]{40}", str(rec.get("blob", "")))):
                raise SystemExit(f"sources.lock.json: {name}: {path} needs sha256 and blob")
    return lock


def _glob_match(path: str, patterns: list[str]) -> bool:
    for g in patterns:
        rx = re.escape(g).replace(r"\*\*/", "(?:.*/)?").replace(r"\*\*", ".*").replace(r"\*", "[^/]*")
        if re.fullmatch(rx, path):
            return True
    return False


def tree(repo: str, commit: str) -> dict[str, str]:
    """path -> git blob sha for every file at the commit."""
    data = json.loads(_get(f"{API}/repos/{repo}/git/trees/{commit}?recursive=1"))
    if data.get("truncated"):
        raise SystemExit(f"{repo}@{commit[:7]}: tree listing truncated by GitHub")
    return {t["path"]: t["sha"] for t in data["tree"] if t["type"] == "blob"}


def fetch_blob(repo: str, blob: str) -> bytes:
    data = json.loads(_get(f"{API}/repos/{repo}/git/blobs/{blob}"))
    if data.get("encoding") != "base64":
        raise SystemExit(f"{repo}: blob {blob[:7]} not base64")
    return base64.b64decode(data["content"])


def git_blob_sha(content: bytes) -> str:
    return hashlib.sha1(b"blob %d\0" % len(content) + content).hexdigest()


def normalise(raw: bytes, src: dict, path: str) -> bytes:
    text = raw.decode("utf-8")
    meta = f'source:\n  repository: "{src["repository"]}"\n  commit: "{src["commit"]}"\n  path: "{path}"\n'
    if text.startswith("---\n"):
        end = text.find("\n---\n", 4)
        if end != -1:
            return (text[:end + 1] + meta + text[end + 1:]).encode("utf-8")
    h1 = re.search(r"^# (.+)$", text, re.M)
    title = re.sub(r"`([^`]*)`", r"\1", h1.group(1)).strip() if h1 else Path(path).stem.replace("-", " ")
    title = title[:120]
    para = ""
    for block in re.split(r"\n\s*\n", text[h1.end():] if h1 else text):
        b = " ".join(block.strip().splitlines())
        if b and not b.startswith(("#", "|", "```", "<", "-", "*", ">", "!")):
            para = re.sub(r"[*_`\[\]]", "", b)
            break
    if len(para) < 40:
        para = f"{title} — documentation from {src['repository']} at the pinned commit {src['commit'][:7]}."
    para = para[:197] + "…" if len(para) > 200 else para
    q = lambda s: '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'
    fm = f"---\ntitle: {q(title)}\ndescription: {q(para)}\n{meta}---\n"
    return (fm + text).encode("utf-8")


def install(lock: dict) -> int:
    n = 0
    for name, src in lock["sources"].items():
        base = DEST / name
        stamp = base / ".installed.json"
        have = json.loads(stamp.read_text()) if stamp.exists() else {}
        for path, rec in sorted(src["files"].items()):
            dest = base / path
            if dest.exists() and have.get(path) == rec["sha256"]:
                continue
            raw = fetch_blob(src["repository"], rec["blob"])
            got = hashlib.sha256(raw).hexdigest()
            if got != rec["sha256"]:
                raise SystemExit(f"{name}: {path}: sha256 {got[:12]} != pinned {rec['sha256'][:12]}")
            dest.parent.mkdir(parents=True, exist_ok=True)
            out = normalise(raw, src, path) if path.endswith(".md") else raw
            fd, tmp = tempfile.mkstemp(dir=dest.parent, prefix=".tmp-")
            with os.fdopen(fd, "wb") as f:
                f.write(out)
                f.flush()
                os.fsync(f.fileno())
            os.replace(tmp, dest)
            have[path] = rec["sha256"]
            n += 1
        base.mkdir(parents=True, exist_ok=True)
        stamp.write_text(json.dumps(have, indent=1, sort_keys=True))
        print(f"{name}@{src['commit'][:7]}: {len(src['files'])} file(s) pinned, {n} installed")
    return 0


def check(lock: dict) -> int:
    bad = 0
    for name, src in lock["sources"].items():
        listing = tree(src["repository"], src["commit"])
        for path, rec in src["files"].items():
            if listing.get(path) != rec["blob"]:
                print(f"::error::{name}: {path} is not blob {rec['blob'][:7]} at {src['commit'][:7]}")
                bad += 1
        extra = [p for p in listing if _glob_match(p, src["include"]) and p not in src["files"]]
        if extra:
            print(f"::warning::{name}: {len(extra)} file(s) match include but are not pinned (run --update {name}): {extra[:5]}")
        print(f"{name}@{src['commit'][:7]}: {len(src['files'])} pinned file(s) verified against the tree")
    return 1 if bad else 0


def update(lock: dict, name: str) -> int:
    src = lock["sources"][name]
    commit = json.loads(_get(f"{API}/repos/{src['repository']}/commits/{src['ref']}"))["sha"]
    listing = tree(src["repository"], commit)
    files = {}
    for path, blob in sorted(listing.items()):
        if not _glob_match(path, src["include"]):
            continue
        raw = fetch_blob(src["repository"], blob)
        if git_blob_sha(raw) != blob:
            raise SystemExit(f"{name}: {path}: downloaded bytes do not match blob {blob[:7]}")
        files[path] = {"blob": blob, "sha256": hashlib.sha256(raw).hexdigest()}
    src["commit"], src["files"] = commit, files
    LOCK.write_text(json.dumps(lock, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"{name}: pinned {src['ref']} -> {commit[:7]} ({len(files)} files)")
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--update", metavar="NAME")
    a = ap.parse_args(argv)
    lock = load_lock()
    if a.update:
        if a.update not in lock["sources"]:
            raise SystemExit(f"unknown source {a.update!r}; known: {sorted(lock['sources'])}")
        return update(lock, a.update)
    if a.check:
        return check(lock)
    return install(lock)


if __name__ == "__main__":
    sys.exit(main())
