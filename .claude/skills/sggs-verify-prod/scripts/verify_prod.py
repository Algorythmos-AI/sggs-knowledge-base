#!/usr/bin/env python3
"""Verify SGGS production: API identity + health + heading regression + web domain."""
import argparse, json, subprocess, sys, urllib.error, urllib.request

API = "https://sggs-knowledge-base.onrender.com"
WEB = "https://sggs-knowledge-base.vercel.app"
TODI = "ਟੋਡੀ ਮਹਲਾ ੫ ਘਰੁ ੨ ਚਉਪਦੇ"

def get(url, timeout=60):
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "sggs-verify"}), timeout=timeout) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, None
    except Exception as e:  # network / cold start
        return None, str(e)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--commit"); ap.add_argument("--version")
    ap.add_argument("--api", default=API); ap.add_argument("--web", default=WEB)
    a = ap.parse_args()
    fails = []
    def check(name, ok, detail=""):
        print(f"  {'ok  ' if ok else 'FAIL'} {name}{(' — ' + detail) if detail else ''}")
        if not ok: fails.append(name)

    for label, base in (("api", a.api), ("web", a.web)):
        print(f"[{label}] {base}")
        s, h = get(base + "/api/health", 90)
        ok = isinstance(h, dict) and h.get("ok") is True and all(h.get("checks", {}).values())
        check(f"{label} health", ok, f"HTTP {s} version={h.get('version') if isinstance(h, dict) else h} commit={str(h.get('commit'))[:12] if isinstance(h, dict) else '-'}")
        if isinstance(h, dict):
            if a.commit: check(f"{label} commit == {a.commit[:12]}", str(h.get("commit")) == a.commit)
            if a.version: check(f"{label} version == {a.version}", h.get("version") == a.version)
        s, d = get(base + "/api/shabad/2845")
        first = d["lines"][0]["gurmukhi"] if isinstance(d, dict) and d.get("lines") else ""
        check(f"{label} Ang 712 heading", first.startswith(TODI), first[:40])
        s, _ = get(base + "/api/shabad/2844")
        check(f"{label} gap comp 2844 → 404", s == 404, f"HTTP {s}")

    try:
        out = subprocess.run(["vercel", "inspect", a.web.replace("https://", ""), "--scope", "skalaliyas-projects"],
                             capture_output=True, text=True, timeout=60)
        ids = [l.split()[-1] for l in (out.stdout + out.stderr).splitlines() if l.strip().startswith("id")]
        print(f"[vercel] public domain served by: {ids[0] if ids else 'unknown (vercel CLI not logged in?)'}")
    except (FileNotFoundError, subprocess.TimeoutExpired):
        print("[vercel] CLI unavailable — deployment id not checked")

    print("RESULT:", "PASS" if not fails else f"FAIL ({', '.join(fails)})")
    return 1 if fails else 0

if __name__ == "__main__":
    sys.exit(main())
