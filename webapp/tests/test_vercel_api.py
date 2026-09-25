"""Unit tests for scripts/ci/vercel_api.py (the deploy pipelines' rollback-target lookup)."""
import io, json, os, re, sys, unittest, urllib.error
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "ci"))
import vercel_api as v  # noqa: E402

PRJ = "prj_ojl2Klc89syjmgUcqfra3ahvOZnC"
LIVE = "sggs-knowledge-base-1xy3n2wtk-skalaliyas-projects.vercel.app"
BROKEN = "sggs-knowledge-base-zz9broken-skalaliyas-projects.vercel.app"
ENV = {"VERCEL_TOKEN": "tok-secret", "VERCEL_ORG_ID": "team_x", "VERCEL_PROJECT_ID": PRJ}

def dep(url=LIVE, **kw):
    # the shape GET /v13/deployments/gurbanisoul.com returns (verified read-only); its `alias`
    # list does not name the custom domain, so nothing may depend on it
    d = {"id": "dpl_live", "url": url, "readyState": "READY", "target": "production",
         "projectId": PRJ, "alias": ["sggs-knowledge-base-skalaliyas-projects.vercel.app"]}
    d.update(kw)
    return d

class FakeApi:
    """After a failed release: the newest READY production build is the broken one; the domain
    still resolves to the last promoted deployment."""
    def __init__(self, domain_dep=None, prod_list=None):
        self.calls, self.domain_dep = [], domain_dep or dep()
        self.prod_list = [{"url": BROKEN}] if prod_list is None else prod_list
    def __call__(self, path, **query):
        self.calls.append((path, query))
        if path.startswith("/v13/deployments/"):
            return self.domain_dep
        if path == "/v6/deployments":
            return {"deployments": self.prod_list}
        raise AssertionError(path)

@mock.patch.dict(os.environ, ENV, clear=False)
class LiveDeployment(unittest.TestCase):
    def test_after_a_failed_release_the_target_is_what_the_domain_serves(self):
        api = FakeApi()
        with mock.patch.object(v, "_get", api):
            self.assertEqual(v.live_deployment("gurbanisoul.com"), "https://" + LIVE)
        self.assertEqual(api.calls, [("/v13/deployments/gurbanisoul.com", {})])   # never the newest-build list
    def test_accepts_a_url_and_uses_its_host(self):
        api = FakeApi()
        with mock.patch.object(v, "_get", api):
            v.live_deployment("https://GurbaniSoul.com/")
        self.assertEqual(api.calls[0][0], "/v13/deployments/gurbanisoul.com")
    def test_project_given_as_nested_object(self):
        d = dep(); del d["projectId"]; d["project"] = {"id": PRJ}
        with mock.patch.object(v, "_get", FakeApi(d)):
            self.assertEqual(v.live_deployment("gurbanisoul.com"), "https://" + LIVE)
    def _refused(self, d, needle):
        with mock.patch.object(v, "_get", FakeApi(d)):
            with self.assertRaisesRegex(v.VercelError, needle):
                v.live_deployment("gurbanisoul.com")
    def test_refuses_a_deployment_that_is_not_ready(self):
        self._refused(dep(readyState="ERROR"), "readyState")
    def test_refuses_a_preview_deployment(self):
        self._refused(dep(target=None), "target")
    def test_refuses_another_projects_deployment(self):
        self._refused(dep(projectId="prj_docs"), "prj_docs")
    def test_refuses_a_deployment_without_url(self):
        self._refused(dep(url=None), "no url")
    def test_refuses_without_a_project_to_check_against(self):
        with mock.patch.dict(os.environ, {"VERCEL_PROJECT_ID": ""}), mock.patch.object(v, "_get", FakeApi()):
            with self.assertRaisesRegex(v.VercelError, "VERCEL_PROJECT_ID"):
                v.live_deployment("gurbanisoul.com")

@mock.patch.dict(os.environ, ENV, clear=False)
class HasProduction(unittest.TestCase):
    def test_yes_and_no(self):
        with mock.patch.object(v, "_get", FakeApi()):
            self.assertTrue(v.has_production())
        api = FakeApi(prod_list=[])
        with mock.patch.object(v, "_get", api):
            self.assertFalse(v.has_production())
        self.assertEqual(api.calls[0], ("/v6/deployments",
                         {"projectId": PRJ, "target": "production", "state": "READY", "limit": 1}))

@mock.patch.dict(os.environ, ENV, clear=False)
class Http(unittest.TestCase):
    def test_sends_the_token_and_team_and_parses_json(self):
        seen = {}
        def urlopen(req, timeout):
            seen["url"], seen["auth"] = req.full_url, req.get_header("Authorization")
            return io.BytesIO(json.dumps(dep()).encode())
        with mock.patch.object(v.urllib.request, "urlopen", urlopen):
            self.assertEqual(v.deployment("gurbanisoul.com")["url"], LIVE)
        self.assertEqual(seen["url"], "https://api.vercel.com/v13/deployments/gurbanisoul.com?teamId=team_x")
        self.assertEqual(seen["auth"], "Bearer tok-secret")
    def test_http_error_is_loud_and_never_prints_the_token(self):
        def urlopen(req, timeout):
            raise urllib.error.HTTPError(req.full_url, 404, "Not Found", {}, io.BytesIO(b'{"error":{"code":"not_found"}}'))
        with mock.patch.object(v.urllib.request, "urlopen", urlopen):
            with self.assertRaises(v.VercelError) as cm:
                v.deployment("gurbanisoul.com")
        self.assertIn("HTTP 404", str(cm.exception))
        self.assertNotIn("tok-secret", str(cm.exception))
    def test_missing_token(self):
        with mock.patch.dict(os.environ, {"VERCEL_TOKEN": ""}):
            with self.assertRaisesRegex(v.VercelError, "VERCEL_TOKEN"):
                v.deployment("gurbanisoul.com")

@mock.patch.dict(os.environ, ENV, clear=False)
class Cli(unittest.TestCase):
    def run_main(self, *argv, api=None):
        out, err = io.StringIO(), io.StringIO()
        with mock.patch.object(v, "_get", api or FakeApi()), redirect_stdout(out), redirect_stderr(err):
            code = v.main(list(argv))
        return code, out.getvalue(), err.getvalue()
    def test_live_prints_the_url(self):
        self.assertEqual(self.run_main("live", "gurbanisoul.com"), (0, f"https://{LIVE}\n", ""))
    def test_live_fails_loudly(self):
        code, out, err = self.run_main("live", "gurbanisoul.com", api=FakeApi(dep(readyState="BUILDING")))
        self.assertEqual((code, out), (1, ""))
        self.assertTrue(err.startswith("::error::gurbanisoul.com resolves to 'dpl_live' but"))
    def test_has_production(self):
        self.assertEqual(self.run_main("has-production")[:2], (0, "yes\n"))
        self.assertEqual(self.run_main("has-production", api=FakeApi(prod_list=[]))[:2], (0, "no\n"))

class Workflow(unittest.TestCase):
    """deploy-production.yml records the live deployment and rolls back only after the domain may have moved."""
    wf = (ROOT / ".github" / "workflows" / "deploy-production.yml").read_text(encoding="utf-8")
    def step(self, name):
        m = re.search(r"\n      - name: " + re.escape(name) + r".*?(?=\n      - |\n  \w|\Z)", self.wf, re.S)
        self.assertIsNotNone(m, name)
        return m.group(0)
    def test_rollback_target_is_the_deployment_serving_the_domain(self):
        s = self.step("Record the deployment serving the production domain")
        self.assertIn('scripts/ci/vercel_api.py live "$PROD_WEB"', s)
        self.assertNotIn("state=READY", self.wf)
    def test_rollback_fires_only_when_promote_or_the_public_smoke_failed(self):
        self.assertIn("id: promote", self.step("Promote to the production domain"))
        self.assertIn("id: public", self.step("Smoke the public production domain"))
        cond = re.search(r"if: (.*)", self.step("Roll back the web frontend")).group(1)
        self.assertIn("steps.promote.outcome == 'failure'", cond)
        self.assertIn("steps.public.outcome == 'failure'", cond)

if __name__ == "__main__":
    unittest.main()
