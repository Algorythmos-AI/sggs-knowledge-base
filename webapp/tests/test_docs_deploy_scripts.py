"""The docs deploy helpers: scripts/ci/vercel_api.py (rollback target, first-deployment guard) and
scripts/ci/docs_smoke.py (identity, no redirects, poster discovery) against a local fake site."""
import http.server, json, subprocess, sys, threading, unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "ci"))
import vercel_api as va  # noqa: E402

LIVE = "sggs-docs-live1-team.vercel.app"
FAILED = "sggs-docs-failed2-team.vercel.app"


def fake_api(routes):
    """A `get` for vercel_api: path prefix -> JSON (or va.NotFound)."""
    def get(path):
        for prefix, answer in routes.items():
            if path.startswith(prefix):
                if answer is va.NotFound:
                    raise va.NotFound(path)
                return answer
        raise AssertionError(f"unexpected API call {path}")
    return get


class VercelApi(unittest.TestCase):
    def test_live_is_the_deployment_serving_the_domain_not_the_newest_production_one(self):
        # the newest READY production deployment is FAILED (deployed --skip-domain, smoke failed);
        # the domain still serves LIVE, so LIVE is the rollback target
        get = fake_api({"/v13/deployments/docs.example.org": {"id": "dpl_live", "url": LIVE, "readyState": "READY",
                                                              "target": "production"},
                        "/v6/deployments": {"deployments": [{"url": FAILED}]}})
        self.assertEqual(va.live_deployment("docs.example.org", get), "https://" + LIVE)
        self.assertEqual(va.live_deployment("https://docs.example.org/", get), "https://" + LIVE)

    def test_live_accepts_the_wrapped_shape(self):
        get = fake_api({"/v13/deployments/": {"deployment": {"url": LIVE, "readyState": "READY"}}})
        self.assertEqual(va.live_deployment("docs.example.org", get), "https://" + LIVE)

    def test_live_none_when_nothing_serves_the_domain(self):
        self.assertIsNone(va.live_deployment("docs.example.org", fake_api({"/v13/deployments/": va.NotFound})))

    def test_live_none_when_the_serving_deployment_is_not_ready(self):
        get = fake_api({"/v13/deployments/": {"url": LIVE, "readyState": "ERROR"}})
        self.assertIsNone(va.live_deployment("docs.example.org", get))

    def test_target_of_a_preview_is_preview(self):
        self.assertEqual(va.deployment_target("https://" + LIVE, fake_api({"/v13/deployments/": {"target": None}})), "preview")
        self.assertEqual(va.deployment_target(LIVE, fake_api({"/v13/deployments/": {"target": "production"}})), "production")

    def test_has_production(self):
        self.assertTrue(va.has_production("prj", fake_api({"/v6/deployments": {"deployments": [{"url": LIVE}]}})))
        self.assertFalse(va.has_production("prj", fake_api({"/v6/deployments": {"deployments": []}})))

    def test_cli_exit_codes(self):
        env = {"VERCEL_PROJECT_ID": "prj"}
        none = fake_api({"/v13/deployments/": va.NotFound, "/v6/deployments": {"deployments": []}})
        self.assertEqual(va.main(["live", "docs.example.org"], env, none), 3)
        self.assertEqual(va.main(["has-production"], env, none), 1)
        self.assertEqual(va.main(["target", LIVE], env, none), 2)          # 404 on a URL is an error
        self.assertEqual(va.main(["has-production"], {}, none), 2)         # no project id
        self.assertEqual(va.main(["bogus"], env, none), 2)
        self.assertEqual(va.main(["live"], {}, None), 2)                   # no token, no team

    def test_token_is_never_printed(self):
        canary = "-".join(["never", "printed", "canary"])   # built at run time: not a secret-shaped literal
        r = subprocess.run([sys.executable, str(ROOT / "scripts/ci/vercel_api.py"), "has-production"],
                           env={"VERCEL_TOKEN": canary, "PATH": "/usr/bin:/bin"},
                           capture_output=True, text=True, timeout=30)
        self.assertEqual(r.returncode, 2)
        self.assertNotIn(canary, r.stdout + r.stderr)


class _Site(http.server.BaseHTTPRequestHandler):
    COMMIT = "a" * 40
    REDIRECT_API = False

    def log_message(self, *a):
        pass

    def _send(self, status, ctype, body, extra=None):
        self.send_response(status)
        self.send_header("content-type", ctype)
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        p = self.path
        if self.REDIRECT_API and p.startswith("/api/") and not p.endswith("/"):
            return self._send(308, "text/plain", b"", {"location": p + "/"})
        pages = {
            "/": ("text/html", f'<meta name="sggs-docs-commit" content="{self.COMMIT}"/>Sri Guru Granth Sahib'.encode()),
            "/architecture/overview/": ("text/html", b'<div data-diagram="mermaid"></div><a href="/posters/01-system-landscape.svg">open full size</a>'),
            "/pagefind/pagefind-entry.json": ("application/json", b'{"version":"1.3.0"}'),
            "/api/health": ("application/json", b'{"ok":true}'),
            "/api/meta": ("application/json", b'{"version":"1.3.10"}'),
            "/og/index.png": ("image/png", b"\x89PNG\r\n\x1a\n...."),
            "/posters/01-system-landscape.svg": ("image/svg+xml", b"<svg xmlns='http://www.w3.org/2000/svg'/>"),
        }
        if p in pages:
            return self._send(200, *pages[p])
        return self._send(404, "text/html", b"nope")


class DocsSmoke(unittest.TestCase):
    def serve(self, **attrs):
        handler = type("Site", (_Site,), attrs)
        srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
        threading.Thread(target=srv.serve_forever, daemon=True).start()
        self.addCleanup(srv.shutdown)
        return f"http://127.0.0.1:{srv.server_address[1]}"

    def smoke(self, base, commit=_Site.COMMIT):
        return subprocess.run([sys.executable, str(ROOT / "scripts/ci/docs_smoke.py"), base, "--commit", commit,
                               "--timeout", "3", "--interval", "1"], capture_output=True, text=True, timeout=60)

    def test_a_whole_site_passes_and_the_poster_is_discovered(self):
        r = self.smoke(self.serve())
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("/posters/01-system-landscape.svg -> 200", r.stdout)
        self.assertIn("/api/meta -> 200", r.stdout)

    def test_a_redirect_on_api_fails_the_smoke(self):   # the trailing-slash loop that broke the widgets
        r = self.smoke(self.serve(REDIRECT_API=True))
        self.assertEqual(r.returncode, 1)
        self.assertIn("BAD /api/health -> 308 redirect -> /api/health/", r.stdout)

    def test_the_wrong_commit_times_out(self):
        r = self.smoke(self.serve(), commit="b" * 40)
        self.assertEqual(r.returncode, 1)
        self.assertIn("timed out", r.stdout)


if __name__ == "__main__":
    unittest.main()
