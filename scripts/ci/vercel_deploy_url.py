#!/usr/bin/env python3
"""
vercel_deploy_url.py STDOUT_FILE STDERR_FILE — print the unique deployment URL
produced by `vercel deploy --format=json`, independent of the CLI's output shape.

Real-world shapes seen: {"status":"ok","deployment":{"url":"https://..."}} (agent /
local), a flat deployment object {"url":"host.vercel.app", ...}, and stdout shapes
that differ in GitHub Actions (a KeyError here broke the first gated deploy). The
human progress line on stderr — `▲ Production  https://<deployment>.vercel.app` — is
the stable fallback. Exit 1 (with a diagnostic) if no deployment URL can be found.
"""
import json, re, sys

URL_RE = re.compile(r"https://[a-z0-9-]+\.vercel\.app", re.I)

def _norm(u):
    if not isinstance(u, str) or not u.strip():
        return None
    u = u.strip()
    if not u.startswith("http"):
        u = "https://" + u
    return u if URL_RE.fullmatch(u) else None

def from_json(text):
    for chunk in (text, *text.splitlines()):          # whole blob, then line-delimited JSON
        chunk = chunk.strip()
        if not chunk.startswith("{"):
            continue
        try:
            d = json.loads(chunk)
        except ValueError:
            continue
        dep = d.get("deployment") if isinstance(d.get("deployment"), dict) else {}
        for cand in (dep.get("url"), d.get("url")):
            u = _norm(cand)
            if u:
                return u
    return None

def from_stderr(text):
    # the deployment line, never the "Aliased" line (a shared team alias, not unique)
    for line in text.splitlines():
        line = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", line)   # strip ANSI cursor codes
        if "Production" in line or "Preview" in line:
            m = URL_RE.search(line)
            if m:
                return m.group(0)
    return None

def resolve(stdout, stderr):
    return from_json(stdout) or from_stderr(stderr)

def main():
    out = open(sys.argv[1], encoding="utf-8", errors="replace").read()
    err = open(sys.argv[2], encoding="utf-8", errors="replace").read()
    url = resolve(out, err)
    if not url:
        sys.stderr.write("::error::could not find the deployment URL in vercel output\n")
        return 1
    print(url)
    return 0

if __name__ == "__main__":
    sys.exit(main())
