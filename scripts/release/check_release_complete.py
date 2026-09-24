#!/usr/bin/env python3
"""check_release_complete.py — prove a release is COMPLETE across all three surfaces.

The one-number policy (docs/engineering/delivery.md "Versioning convention") says web, API and the
shipped iOS binary must all report the same X.Y.Z from the same released commit.
This is the release-time, network-touching check that proves it — run as the final
step of sggs-release, and by sggs-verify-prod --ios.

For version X.Y.Z it asserts:
  1. prod API  /api/health.version == X.Y.Z  and .commit == the commit tag vX.Y.Z points at
  2. prod WEB  /api/health.version == X.Y.Z  and .commit == that same commit
  3. the app's ledger (ios/testflight-builds.json in Algorythmos-AI/gurbani-soul-ios) has a
     channel="appstore" build of X.Y.Z built against that same commit: its platform_commit
     (the platform release whose contract the binary vendors) — or, for builds made before the
     app had its own repository, its source_commit — equals it (full 40-hex).

Exit 0 if complete, 1 otherwise.
Usage: check_release_complete.py X.Y.Z [--api URL] [--web URL] [--ledger PATH]
"""
import argparse, json, os, subprocess, sys, urllib.error, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
API = "https://sggs-knowledge-base.onrender.com"
WEB = "https://gurbanisoul.com"
IOS_REPO = "Algorythmos-AI/gurbani-soul-ios"
LEDGER_PATH = "ios/testflight-builds.json"


def health(base, timeout=90):
    try:
        req = urllib.request.Request(base + "/api/health", headers={"User-Agent": "sggs-release-complete"})
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.loads(r.read().decode())
    except (urllib.error.URLError, OSError, ValueError) as e:
        return {"_error": str(e)}


def fetch_ledger(path=None):
    """The app's TestFlight ledger: a local file when given, else main of the iOS repository."""
    if path:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    headers = {"User-Agent": "sggs-release-complete", "Accept": "application/vnd.github.raw",
               "X-GitHub-Api-Version": "2022-11-28"}
    tok = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if tok:
        headers["Authorization"] = f"Bearer {tok}"
    url = f"https://api.github.com/repos/{IOS_REPO}/contents/{LEDGER_PATH}?ref=main"
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=60) as r:
        return json.loads(r.read().decode())


def built_against(row):
    """The platform commit a ledger row was built against (see the module docstring)."""
    return row.get("platform_commit") or row.get("source_commit")


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
    ap.add_argument("--ledger", help=f"read the ledger from this file instead of {IOS_REPO}")
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
        rows = fetch_ledger(a.ledger).get("builds", [])
    except (OSError, urllib.error.URLError, json.JSONDecodeError) as e:
        check("app ledger readable", False, str(e))
        rows = []
    appstore = [r for r in rows if r.get("version") == v and r.get("channel") == "appstore"]
    check(f"ledger has an appstore build of {v}", bool(appstore),
          f"builds: {[r.get('build') for r in appstore] or 'none'}")
    if appstore and commit:
        from_tag = [r for r in appstore if built_against(r) == commit]
        check(f"ledger {v} built against the tag commit", bool(from_tag),
              "platform commit matches" if from_tag
              else f"built against {[str(built_against(r))[:12] for r in appstore]} != {commit[:12]}")

    print()
    if fails:
        print(f"RESULT: INCOMPLETE — {len(fails)} check(s) failed: {', '.join(fails)}")
        return 1
    print(f"RESULT: COMPLETE — web, API and the iOS binary all report {v} from {commit[:12]}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
