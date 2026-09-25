#!/usr/bin/env python3
"""vercel_api.py — the Vercel facts a deploy job must read, never guess.

  live DOMAIN        print the https URL of the deployment serving DOMAIN right now: the only
                     correct rollback target. (The newest READY production deployment is not:
                     a build deployed with --skip-domain whose smoke failed is READY and
                     target=production too, but it never served anyone.)
  target URL         print a deployment's target: "production" or "preview".
  has-production     exit 0 when the project has a READY production deployment, 1 when it has
                     none. The docs project's first deployment became its production deployment
                     although CI deployed it as a preview (2026-09-26), so staging never goes first.

Environment: VERCEL_TOKEN, VERCEL_ORG_ID (the team), VERCEL_PROJECT_ID (has-production only).
Exit codes: 0 ok · 1 has-production found none · 2 API or usage error · 3 live: no deployment
serves DOMAIN. Stdlib only; the token goes to api.vercel.com in a header and is never printed.
"""
import json, os, sys, urllib.error, urllib.parse, urllib.request

API = "https://api.vercel.com"


class NotFound(Exception):
    pass


def http_get(path, token, team):
    """GET API+path with the team, return parsed JSON. Raises NotFound on 404."""
    sep = "&" if "?" in path else "?"
    req = urllib.request.Request(f"{API}{path}{sep}teamId={urllib.parse.quote(team)}",
                                 headers={"Authorization": f"Bearer {token}", "User-Agent": "sggs-ci"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        if e.code == 404:
            raise NotFound(path) from None
        raise


def _host(url_or_host):
    return urllib.parse.urlsplit(url_or_host).netloc if "://" in url_or_host else url_or_host.strip("/")


def _deployment(d):
    """The deployment object, whether the API wrapped it or not."""
    return d.get("deployment", d) if isinstance(d, dict) else {}


def live_deployment(domain, get):
    """https URL of the deployment currently serving DOMAIN, or None when nothing serves it."""
    try:
        dep = _deployment(get(f"/v13/deployments/{urllib.parse.quote(_host(domain))}"))
    except NotFound:
        return None
    url = dep.get("url")
    if not url or dep.get("readyState", dep.get("state")) not in ("READY", None):
        return None
    return "https://" + _host(url)


def deployment_target(url, get):
    """'production' or 'preview' (the API reports a preview's target as null)."""
    dep = _deployment(get(f"/v13/deployments/{urllib.parse.quote(_host(url))}"))
    return dep.get("target") or "preview"


def has_production(project, get):
    q = urllib.parse.urlencode({"projectId": project, "target": "production", "state": "READY", "limit": 1})
    return bool(get(f"/v6/deployments?{q}").get("deployments"))


def main(argv, env=os.environ, get=None):
    if len(argv) < 1 or argv[0] not in ("live", "target", "has-production") or \
            (argv[0] != "has-production" and len(argv) != 2):
        print(__doc__, file=sys.stderr)
        return 2
    token, team = env.get("VERCEL_TOKEN"), env.get("VERCEL_ORG_ID")
    if get is None:
        if not token or not team:
            print("::error::vercel_api: VERCEL_TOKEN and VERCEL_ORG_ID are required", file=sys.stderr)
            return 2
        get = lambda path: http_get(path, token, team)  # noqa: E731
    try:
        if argv[0] == "live":
            url = live_deployment(argv[1], get)
            if not url:
                print(f"no deployment serves {argv[1]}", file=sys.stderr)
                return 3
            print(url)
            return 0
        if argv[0] == "target":
            print(deployment_target(argv[1], get))
            return 0
        project = env.get("VERCEL_PROJECT_ID")
        if not project:
            print("::error::vercel_api: VERCEL_PROJECT_ID is required for has-production", file=sys.stderr)
            return 2
        return 0 if has_production(project, get) else 1
    except (urllib.error.URLError, TimeoutError, OSError, ValueError, NotFound) as e:
        print(f"::error::vercel_api {argv[0]}: {type(e).__name__}: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
