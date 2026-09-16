#!/usr/bin/env python3
"""
wait_for_checks.py SHA [--extra CTX ...] — block until every required check on an
exact commit has succeeded. The deploy pipeline's gate: it never re-runs CI (which
could collide with the push-triggered runs' concurrency groups) — it waits for them.

Required contexts are read from .github/rulesets/main.json (single source of truth,
so the gate can't drift from branch protection), plus any --extra contexts.

Exit 0 when all succeeded. Exit 1 fast on any failed/cancelled/skipped required
check, if a required check hasn't appeared within --appear-timeout, or on the
overall --timeout. Uses `gh api` (GH_TOKEN in Actions).
"""
import argparse, json, subprocess, sys, time
from pathlib import Path

OK = {"success", "neutral"}
BAD = {"failure", "cancelled", "timed_out", "action_required", "startup_failure", "stale", "skipped"}

def required_contexts():
    rs = json.loads((Path(__file__).resolve().parents[2] / ".github/rulesets/main.json").read_text())
    for r in rs["rules"]:
        if r["type"] == "required_status_checks":
            return [c["context"] for c in r["parameters"]["required_status_checks"]]
    return []

def check_runs(repo, sha):
    out = subprocess.run(
        ["gh", "api", "--paginate", f"repos/{repo}/commits/{sha}/check-runs?per_page=100",
         "--jq", ".check_runs[] | {name, status, conclusion, id}"],
        capture_output=True, text=True)
    if out.returncode != 0:
        raise RuntimeError(out.stderr.strip())
    runs = [json.loads(l) for l in out.stdout.splitlines() if l.strip()]
    latest = {}
    for r in runs:                      # a re-run creates a newer check run: keep the highest id
        if r["name"] not in latest or r["id"] > latest[r["name"]]["id"]:
            latest[r["name"]] = r
    return latest

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sha")
    ap.add_argument("--repo", default=None)
    ap.add_argument("--extra", nargs="*", default=[])
    ap.add_argument("--interval", type=int, default=20)
    ap.add_argument("--appear-timeout", type=int, default=900)
    ap.add_argument("--timeout", type=int, default=2700)
    a = ap.parse_args()
    import os
    repo = a.repo or os.environ.get("GITHUB_REPOSITORY")
    if not repo:
        sys.exit("--repo or GITHUB_REPOSITORY required")
    want = list(dict.fromkeys(required_contexts() + a.extra))
    if not want:
        sys.exit("no required contexts found in .github/rulesets/main.json")
    print(f"waiting on {repo}@{a.sha[:7]} for: {', '.join(want)}")
    start = time.time()
    while True:
        try:
            latest = check_runs(repo, a.sha)
        except RuntimeError as e:
            print(f"  gh api error (retrying): {e}")
            time.sleep(a.interval); continue
        elapsed = int(time.time() - start)
        pending, done = [], []
        for ctx in want:
            r = latest.get(ctx)
            if r is None:
                if elapsed > a.appear_timeout:
                    print(f"::error::required check '{ctx}' never appeared on {a.sha[:7]} after {elapsed}s"); return 1
                pending.append(f"{ctx}(not started)")
            elif r["status"] != "completed":
                pending.append(f"{ctx}({r['status']})")
            elif r["conclusion"] in OK:
                done.append(ctx)
            else:
                print(f"::error::required check '{ctx}' concluded '{r['conclusion']}' — not deploying"); return 1
        print(f"  [{elapsed:>4}s] ok={len(done)}/{len(want)} pending={', '.join(pending) or '-'}")
        if not pending:
            print("all required checks succeeded"); return 0
        if elapsed > a.timeout:
            print(f"::error::timed out after {elapsed}s waiting for: {', '.join(pending)}"); return 1
        time.sleep(a.interval)

if __name__ == "__main__":
    sys.exit(main())
