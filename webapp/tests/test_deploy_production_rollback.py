"""deploy-production's web rollback target and trigger (the helper itself: test_docs_deploy_scripts.py)."""
import io, re, sys, unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "ci"))
import vercel_api as va  # noqa: E402

LIVE = "sggs-knowledge-base-1xy3n2wtk-skalaliyas-projects.vercel.app"
BROKEN = "sggs-knowledge-base-zz9broken-skalaliyas-projects.vercel.app"
ENV = {"VERCEL_TOKEN": "t", "VERCEL_ORG_ID": "team_x", "VERCEL_PROJECT_ID": "prj_web"}

def api(served):
    """After a failed release: the newest READY production build is the broken one, while
    gurbanisoul.com still resolves to the last promoted deployment (or nothing, or a 404)."""
    calls = []
    def get(path):
        calls.append(path)
        if path.startswith("/v13/deployments/gurbanisoul.com"):
            if served is None:
                raise va.NotFound(path)
            return served
        if path.startswith("/v6/deployments"):
            return {"deployments": [{"url": BROKEN, "readyState": "READY", "target": "production"}]}
        raise AssertionError(path)
    return get, calls

def run(served):
    get, calls = api(served)
    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        code = va.main(["live", "https://gurbanisoul.com"], env=ENV, get=get)
    return code, out.getvalue(), calls

class RollbackTarget(unittest.TestCase):
    def test_after_a_failed_release_the_target_is_what_the_domain_serves(self):
        # the shape GET /v13/deployments/gurbanisoul.com returned when checked read-only; its
        # `alias` list does not name the custom domain, so nothing may depend on it
        served = {"id": "dpl_live", "url": LIVE, "readyState": "READY", "target": "production",
                  "alias": ["sggs-knowledge-base-skalaliyas-projects.vercel.app"]}
        code, out, calls = run(served)
        self.assertEqual((code, out), (0, f"https://{LIVE}\n"))
        self.assertEqual(calls, ["/v13/deployments/gurbanisoul.com"])   # never the newest-build list
    def test_no_answer_is_a_nonzero_exit_never_a_guess(self):
        for served in (None, {"url": LIVE, "readyState": "ERROR"}, {"readyState": "READY"}):
            code, out, calls = run(served)
            self.assertNotEqual(code, 0, served)
            self.assertEqual(out, "")
            self.assertNotIn("/v6/deployments", " ".join(calls))

class Workflow(unittest.TestCase):
    wf = (ROOT / ".github" / "workflows" / "deploy-production.yml").read_text(encoding="utf-8")
    def step(self, name):
        m = re.search(r"\n      - name: " + re.escape(name) + r".*?(?=\n      - |\n  \w|\Z)", self.wf, re.S)
        self.assertIsNotNone(m, name)
        return m.group(0)
    def test_rollback_target_is_the_deployment_serving_the_domain(self):
        s = self.step("Record the deployment serving the production domain")
        self.assertIn('prev=$(python3 scripts/ci/vercel_api.py live "$PROD_WEB") || {', s)
        self.assertIn("exit 1", s)
        self.assertNotIn("state=READY", self.wf)
    def test_rollback_fires_only_when_promote_or_the_public_smoke_failed(self):
        self.assertIn("id: promote", self.step("Promote to the production domain"))
        self.assertIn("id: public", self.step("Smoke the public production domain"))
        cond = re.search(r"if: (.*)", self.step("Roll back the web frontend")).group(1)
        self.assertIn("steps.promote.outcome == 'failure'", cond)
        self.assertIn("steps.public.outcome == 'failure'", cond)

if __name__ == "__main__":
    unittest.main()
