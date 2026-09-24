#!/usr/bin/env python3
"""
wait_for_deploy.py BASE_URL --commit SHA — poll BASE_URL/api/health until the
running build reports exactly this commit AND every health check is true.

Identity, not version: a deploy that doesn't bump APP_VERSION would otherwise
"pass" against the old instance. Tolerates cold starts / 5xx during the rollout.
Fails loudly if the service reports commit 'unknown' (RENDER_GIT_COMMIT missing →
set SGGS_COMMIT on the host) rather than waiting out the timeout.
"""
import argparse, json, sys, time, urllib.request, urllib.error

def fetch(url, timeout):
    req = urllib.request.Request(url, headers={"User-Agent": "sggs-deploy-verify"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.status, json.loads(r.read().decode())

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("base_url")
    ap.add_argument("--commit", required=True)
    ap.add_argument("--timeout", type=int, default=1500)
    ap.add_argument("--interval", type=int, default=15)
    ap.add_argument("--unknown-grace", type=int, default=600,
                    help="seconds to tolerate commit=='unknown' (old build still live) before failing")
    ap.add_argument("--readyz", action="store_true",
                    help="poll /readyz (a single-context service) instead of /api/health: ready must be true")
    a = ap.parse_args()
    url = a.base_url.rstrip("/") + ("/readyz" if a.readyz else "/api/health")
    want = a.commit.strip()
    start = time.time(); last = None
    print(f"waiting for {url} to report commit {want[:12]}")
    while True:
        elapsed = int(time.time() - start)
        try:
            status, h = fetch(url, 30)
            got = str(h.get("commit", "unknown"))
            state = f"HTTP {status} version={h.get('version')} commit={got[:12]} ok={h.get('ok')}"
            if got == want:
                if (h.get("ready") is True) if a.readyz else (h.get("ok") is True and all(h.get("checks", {}).values())):
                    print(f"  [{elapsed:>4}s] {state} — deployed and healthy"); return 0
                print(f"::error::commit {want[:12]} is live but not healthy: {h.get('missing_tables') if a.readyz else h.get('checks')}"); return 1
            if got == "unknown" and elapsed > a.unknown_grace:
                print("::error::service reports commit 'unknown' — RENDER_GIT_COMMIT not visible at runtime; "
                      "set SGGS_COMMIT on the host (see docs/process/runbooks/deploy.md)"); return 1
        except (urllib.error.URLError, TimeoutError, ValueError, OSError) as e:
            state = f"unreachable ({type(e).__name__})"
        if state != last:
            print(f"  [{elapsed:>4}s] {state}"); last = state
        if elapsed > a.timeout:
            hint = (" — the service never reported a commit: RENDER_GIT_COMMIT may be missing at runtime; "
                    "set SGGS_COMMIT on the host") if "commit=unknown" in state else ""
            print(f"::error::timed out after {elapsed}s; last: {state}{hint}"); return 1
        time.sleep(a.interval)

if __name__ == "__main__":
    sys.exit(main())
