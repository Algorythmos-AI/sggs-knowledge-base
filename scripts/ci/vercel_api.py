#!/usr/bin/env python3
"""
vercel_api.py — the read-only Vercel REST lookups the deploy pipelines make (stdlib only).

  vercel_api.py live DOMAIN        print the https URL of the deployment serving DOMAIN right now
  vercel_api.py deployment URL     print the deployment a hostname resolves to (JSON)
  vercel_api.py has-production     print "yes" if the project has a READY production deployment, else "no"

Env: VERCEL_TOKEN; VERCEL_ORG_ID (the team); VERCEL_PROJECT_ID (the project DOMAIN must belong to).

The rollback target is the deployment the production domain resolves to, never "the newest READY
production deployment": a build made with `vercel deploy --prebuilt --prod --skip-domain` whose smoke
then failed is READY and target=production too, but it was never promoted, so the next release would
record it as "previous" and a rollback would restore it. GET /v13/deployments/<host> resolves an alias
hostname to the deployment it points at (the same answer as the alias table). Anything short of a
READY production deployment of this project is an error (exit 1, `::error::`), never a guess.
"""
import argparse, json, os, sys, urllib.error, urllib.parse, urllib.request

API = "https://api.vercel.com"

class VercelError(RuntimeError):
    pass

def _get(path, **query):
    token = os.environ.get("VERCEL_TOKEN", "")
    if not token:
        raise VercelError("VERCEL_TOKEN is not set")
    if os.environ.get("VERCEL_ORG_ID"):
        query["teamId"] = os.environ["VERCEL_ORG_ID"]
    url = API + path + ("?" + urllib.parse.urlencode(query) if query else "")
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}", "User-Agent": "sggs-ci"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        body = e.read(300).decode("utf-8", "replace").strip()
        raise VercelError(f"GET {path} → HTTP {e.code}: {body}") from None
    except (urllib.error.URLError, TimeoutError, ValueError) as e:
        raise VercelError(f"GET {path} failed: {e}") from None

def _host(url):
    h = (url or "").strip().split("://", 1)[-1]
    return h.split("/", 1)[0].lower()

def _project_id(project_id):
    pid = project_id or os.environ.get("VERCEL_PROJECT_ID", "")
    if not pid:
        raise VercelError("VERCEL_PROJECT_ID is not set")
    return pid

def deployment(url):
    """The deployment a hostname resolves to: a unique deployment URL, or an alias such as the production domain."""
    host = _host(url)
    if not host:
        raise VercelError("no hostname given")
    return _get("/v13/deployments/" + urllib.parse.quote(host, safe=""))

def live_deployment(domain, project_id=None):
    """https URL of the deployment serving `domain` right now — the only safe rollback target."""
    pid = _project_id(project_id)
    d = deployment(domain)
    problems = []
    if not d.get("url"):
        problems.append("it has no url")
    if d.get("readyState") != "READY":
        problems.append(f"readyState is {d.get('readyState')!r}, not 'READY'")
    if d.get("target") != "production":
        problems.append(f"target is {d.get('target')!r}, not 'production'")
    got = d.get("projectId") or (d.get("project") or {}).get("id")
    if got != pid:
        problems.append(f"it belongs to project {got!r}, not {pid!r}")
    if problems:
        raise VercelError(f"{_host(domain)} resolves to {d.get('id')!r} but " + "; ".join(problems))
    return "https://" + _host(d["url"])

def has_production(project_id=None):
    """Whether the project has any READY production deployment (false only before its first release)."""
    d = _get("/v6/deployments", projectId=_project_id(project_id), target="production", state="READY", limit=1)
    return bool(d.get("deployments"))

def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("live").add_argument("domain")
    sub.add_parser("deployment").add_argument("url")
    sub.add_parser("has-production")
    a = p.parse_args(argv)
    try:
        if a.cmd == "live":
            print(live_deployment(a.domain))
        elif a.cmd == "deployment":
            print(json.dumps(deployment(a.url), indent=2))
        else:
            print("yes" if has_production() else "no")
    except VercelError as e:
        sys.stderr.write(f"::error::{e}\n")
        return 1
    return 0

if __name__ == "__main__":
    sys.exit(main())
