#!/usr/bin/env python3
"""docs_smoke.py BASE_URL --commit SHA — prove a deployed wiki is this commit and whole.

Identity, not just liveness: the page must carry <meta name="sggs-docs-commit" content=SHA>,
search must be indexed (Pagefind), a poster must be served as SVG when any exists, and the
same-origin /api rewrite must reach the API. Retries while a deployment warms up. Sends the
Vercel protection-bypass header when VERCEL_DOCS_BYPASS_SECRET is set.
"""
import argparse, json, os, re, sys, time, urllib.error, urllib.request

def fetch(base, path, bypass, timeout=30):
    req = urllib.request.Request(base.rstrip("/") + path, headers={"User-Agent": "sggs-docs-smoke",
                                 **({"x-vercel-protection-bypass": bypass} if bypass else {})})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.status, r.headers.get("content-type", ""), r.read()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("base_url")
    ap.add_argument("--commit", required=True)
    ap.add_argument("--timeout", type=int, default=300)
    ap.add_argument("--interval", type=int, default=10)
    ap.add_argument("--poster", default="", help="a poster path to expect, e.g. /posters/01-system-landscape.svg")
    a = ap.parse_args()
    bypass = os.environ.get("VERCEL_DOCS_BYPASS_SECRET") or None
    start, last = time.time(), None
    while True:
        try:
            status, ctype, body = fetch(a.base_url, "/", bypass)
            html = body.decode("utf-8", "replace")
            m = re.search(r'<meta name="sggs-docs-commit" content="([^"]+)"', html)
            got = m.group(1) if m else "none"
            if status == 200 and got == a.commit:
                break
            state = f"HTTP {status}, commit {got[:12]} (want {a.commit[:12]})"
        except (urllib.error.URLError, TimeoutError, OSError) as e:
            state = f"unreachable ({type(e).__name__})"
        if state != last:
            print(f"  [{int(time.time() - start):>4}s] {state}"); last = state
        if time.time() - start > a.timeout:
            print(f"::error::docs smoke: timed out; last: {state}"); return 1
        time.sleep(a.interval)
    print(f"home page serves commit {a.commit[:12]}")
    checks = [("/", "text/html", lambda b: b"Sri Guru Granth Sahib" in b),
              ("/architecture/overview/", "text/html", lambda b: b'data-diagram="mermaid"' in b),
              ("/pagefind/pagefind-entry.json", "application/json", lambda b: json.loads(b).get("version")),
              ("/api/health", "application/json", lambda b: json.loads(b).get("ok") is True)]
    if a.poster:
        checks.append((a.poster, "image/svg+xml", lambda b: b.startswith(b"<svg") or b"<svg" in b[:500]))
    bad = 0
    for path, want_type, ok in checks:
        try:
            status, ctype, body = fetch(a.base_url, path, bypass)
            good = status == 200 and want_type in ctype and bool(ok(body))
        except Exception as e:  # noqa: BLE001 — a smoke check reports, never raises
            status, ctype, good = "ERR", type(e).__name__, False
        print(f"  {'ok ' if good else 'BAD'} {path} -> {status} {ctype}")
        bad += not good
    if bad:
        print(f"::error::docs smoke: {bad} check(s) failed"); return 1
    print("docs smoke: all checks passed"); return 0

if __name__ == "__main__":
    sys.exit(main())
