#!/usr/bin/env python3
"""Prove every API function of a deployment is live at this commit and holds exactly its context.

    python3 scripts/ci/verify_functions.py https://sggs-staging.vercel.app --commit SHA --env staging

For each context routed to its own function in that environment (gateway/routes.json) and for
`all`: /readyz?svc=<context> (or /readyz) answers 200, ready, with that function's contexts, the
expected commit and the matching X-Service header. And the API's databases and source are not
downloadable from the site. Sends x-vercel-protection-bypass when VERCEL_AUTOMATION_BYPASS_SECRET
is set. Retries while functions cold-start. Stdlib only.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from gen_gateway import DATA_DIR, ROUTES_FILE, environments, prefixes_by_context  # noqa: E402

NOT_PUBLISHED = (f"/{DATA_DIR}/db/all.sqlite", f"/{DATA_DIR}/db/search.sqlite", f"/{DATA_DIR}/webapp/serve.py")


def get(url: str, timeout: int = 60):
    headers = {"User-Agent": "sggs-deploy-verify"}
    if os.environ.get("VERCEL_AUTOMATION_BYPASS_SECRET"):
        headers["x-vercel-protection-bypass"] = os.environ["VERCEL_AUTOMATION_BYPASS_SECRET"]
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.headers.get("X-Service"), r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.headers.get("X-Service"), e.read()


def check_ready(base: str, name: str, contexts: list[str], commit: str) -> str | None:
    """None when the function is right, else what is wrong."""
    url = f"{base}/readyz" + ("" if name == "all" else f"?svc={name}")
    status, svc, raw = get(url)
    try:
        body = json.loads(raw)
    except ValueError:
        return f"{url}: HTTP {status}, not JSON"
    want_svc = "all" if name == "all" else name
    if status != 200 or body.get("ready") is not True:
        return f"{url}: HTTP {status} ready={body.get('ready')} missing={body.get('missing_tables')}"
    if body.get("commit") != commit:
        return f"{url}: commit {body.get('commit')} (want {commit[:12]})"
    if body.get("contexts") != contexts or svc != want_svc:
        return f"{url}: contexts {body.get('contexts')} X-Service {svc} (want {contexts} / {want_svc})"
    return None


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("base")
    ap.add_argument("--commit", required=True)
    ap.add_argument("--env", required=True)
    ap.add_argument("--attempts", type=int, default=6)
    ap.add_argument("--interval", type=int, default=15)
    a = ap.parse_args(argv)
    base = a.base.rstrip("/")
    env = environments(json.loads(ROUTES_FILE.read_text(encoding="utf-8")))[a.env]
    if env["api_platform"] != "vercel":
        print(f"{a.env}: the API is on {env['api_platform']}, not the Vercel functions — nothing to verify")
        return 0
    everything = sorted(prefixes_by_context())
    targets = [(c, [c]) for c in sorted(env["services"])] + [("all", everything)]
    failures = []
    for name, contexts in targets:
        for attempt in range(1, a.attempts + 1):
            problem = check_ready(base, name, contexts, a.commit)
            if problem is None:
                print(f"ok  {name:<9} ready at {a.commit[:12]} serving {','.join(contexts)}")
                break
            print(f"    {name}: {problem} (attempt {attempt}/{a.attempts})")
            if attempt < a.attempts:
                time.sleep(a.interval)
        else:
            failures.append(name)
    for path in NOT_PUBLISHED:
        status, _, _ = get(base + path)
        if status == 200:
            failures.append(path)
            print(f"::error::{base}{path} is downloadable — the API's files must never be published")
        else:
            print(f"ok  {path} not published (HTTP {status})")
    if failures:
        print(f"::error::API functions not right on {base}: {failures}")
        return 1
    print(f"all {len(targets)} API functions verified on {base}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
