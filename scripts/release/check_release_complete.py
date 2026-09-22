#!/usr/bin/env python3
"""check_release_complete.py — prove a release is COMPLETE across all three surfaces.

The one-number policy (CLAUDE.md "Versioning convention") says web, API and the
shipped iOS binary must all report the same X.Y.Z from the same released commit.
This is the release-time, network-touching check that proves it — run as the final
step of sggs-release, and by sggs-verify-prod --ios.

For version X.Y.Z it asserts:
  1. prod API  /api/health.version == X.Y.Z  and .commit == the commit tag vX.Y.Z points at
  2. prod WEB  /api/health.version == X.Y.Z  and .commit == that same commit
  3. the ledger ios/testflight-builds.json has a channel="appstore" build of X.Y.Z
     whose source_commit == that same commit (full 40-hex; a tag resolves to it)

Exit 0 if complete, 1 otherwise. Usage: check_release_complete.py X.Y.Z [--api URL] [--web URL]
"""
import argparse, json, subprocess, sys, urllib.error, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
API = "https://sggs-knowledge-base.onrender.com"
WEB = "https://gurbanisoul.com"


def health(base, timeout=90):
    try:
        req = urllib.request.Request(base + "/api/health", headers={"User-Agent": "sggs-release-complete"})
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.loads(r.read().decode())
    except (urllib.error.URLError, OSError, ValueError) as e:
        return {"_error": str(e)}


def tag_commit(version):
    """Full 40-hex commit that annotated/lightweight tag vX.Y.Z resolves to, or None."""
    try:
        out = subprocess.run(["git", "rev-list", "-n", "1", f"v{version}"],
                             cwd=ROOT, capture_output=True, text=True)
        sha = out.stdout.strip()
        return sha if len(sha) == 40 else None
    except OSError:
        return None


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("version")
    ap.add_argument("--api", default=API)
    ap.add_argument("--web", default=WEB)
    a = ap.parse_args(argv)
    v = a.version
    fails = []

    def check(name, ok, detail=""):
        print(f"  {'ok  ' if ok else 'FAIL'} {name}{(' — ' + detail) if detail else ''}")
        if not ok:
            fails.append(name)

    commit = tag_commit(v)
    check(f"tag v{v} resolves to a commit", bool(commit), commit or "no such tag (run the release first)")

    for label, base in (("api", a.api), ("web", a.web)):
        h = health(base)
        if "_error" in h:
            check(f"{label} reachable", False, h["_error"])
            continue
        check(f"{label} version == {v}", h.get("version") == v, f"got {h.get('version')}")
        if commit:
            check(f"{label} commit == {commit[:12]}", str(h.get("commit")) == commit, f"got {str(h.get('commit'))[:12]}")

    # Ledger: an appstore upload of this version from the tagged commit.
    try:
        rows = json.loads((ROOT / "ios/testflight-builds.json").read_text(encoding="utf-8")).get("builds", [])
    except (FileNotFoundError, json.JSONDecodeError):
        rows = []
    appstore = [r for r in rows if r.get("version") == v and r.get("channel") == "appstore"]
    check(f"ledger has an appstore build of {v}", bool(appstore),
          f"builds: {[r.get('build') for r in appstore] or 'none'}")
    if appstore and commit:
        from_tag = [r for r in appstore if r.get("source_commit") == commit]
        check(f"ledger {v} built from tag commit", bool(from_tag),
              "source_commit matches" if from_tag
              else f"source_commit(s) {[str(r.get('source_commit'))[:12] for r in appstore]} != {commit[:12]}")

    print()
    if fails:
        print(f"RESULT: INCOMPLETE — {len(fails)} check(s) failed: {', '.join(fails)}")
        return 1
    print(f"RESULT: COMPLETE — web, API and the iOS binary all report {v} from {commit[:12]}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
