"""Unit tests for the CI deploy helpers (run with the webapp suite)."""
import sys, unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts" / "ci"))
import vercel_deploy_url as v  # noqa: E402

U = "https://sggs-knowledge-base-f6hr0j9p9-skalaliyas-projects.vercel.app"
ALIAS = "https://sggs-knowledge-base-skalaliyas-projects.vercel.app"
STDERR = (f"Uploading [====]\n  Inspect  https://vercel.com/x/y/z\n"
          f"\x1b[2K\x1b[1A\x1b[2K\x1b[G▲ Production      {U}\nCompleting…\n▲ Aliased         {ALIAS}\n")

class VercelDeployUrl(unittest.TestCase):
    def test_wrapped_json(self):
        self.assertEqual(v.resolve('{"status":"ok","deployment":{"url":"%s"}}' % U, ""), U)
    def test_flat_json_without_scheme(self):
        self.assertEqual(v.resolve('{"id":"dpl_1","url":"%s"}' % U[8:], ""), U)
    def test_json_without_url_falls_back_to_stderr(self):   # the shape that broke CI
        self.assertEqual(v.resolve('{"status":"ok","message":"done"}', STDERR), U)
    def test_empty_stdout_uses_stderr_not_alias(self):
        self.assertEqual(v.resolve("", STDERR), U)
    def test_nothing_found(self):
        self.assertIsNone(v.resolve("not json", "no urls here"))
    def test_rejects_non_vercel_urls(self):
        self.assertIsNone(v.resolve('{"url":"https://evil.example.com"}', ""))

if __name__ == "__main__":
    unittest.main()
