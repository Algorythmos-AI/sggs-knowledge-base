"""scripts/ci/wait_for_deploy.py --readyz: a single-context service is proven by /readyz (the exact
commit and ready: true), because it does not serve /api/health."""
import os
import socket
import subprocess
import sys
import time
import unittest
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REAL_DB = ROOT / "db" / "sggs.sqlite"


def _is_real_sqlite(p):
    try:
        with open(p, "rb") as f:
            return f.read(16) == b"SQLite format 3\x00"
    except OSError:
        return False


def _free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


@unittest.skipUnless(_is_real_sqlite(REAL_DB), "needs the real db/sggs.sqlite")
class WaitReadyz(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.port = _free_port()
        env = dict(os.environ, SGGS_OPEN_BROWSER="0", SGGS_ACCESS_LOG="0", SGGS_PORT=str(cls.port),
                   SGGS_MODULES="knowledge", SGGS_COMMIT="c0ffee1234567890")
        env.pop("RENDER_GIT_COMMIT", None)
        cls.proc = subprocess.Popen([sys.executable, "serve.py"], cwd=ROOT / "webapp", env=env,
                                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(80):
            try:
                urllib.request.urlopen(f"http://127.0.0.1:{cls.port}/healthz", timeout=2).read()
                break
            except OSError:
                time.sleep(0.25)

    @classmethod
    def tearDownClass(cls):
        cls.proc.terminate()
        cls.proc.wait(timeout=10)

    def wait(self, commit):
        return subprocess.run([sys.executable, str(ROOT / "scripts/ci/wait_for_deploy.py"),
                               f"http://127.0.0.1:{self.port}", "--readyz", "--commit", commit,
                               "--timeout", "3", "--interval", "1", "--unknown-grace", "0"],
                              capture_output=True, text=True, timeout=60)

    def test_ready_at_the_expected_commit(self):
        r = self.wait("c0ffee1234567890")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("/readyz", r.stdout)

    def test_a_single_context_service_names_itself(self):
        with urllib.request.urlopen(f"http://127.0.0.1:{self.port}/readyz", timeout=5) as r:
            self.assertEqual(r.headers.get("X-Service"), "knowledge")

    def test_a_different_commit_times_out(self):
        self.assertNotEqual(self.wait("deadbeef00000000").returncode, 0)


if __name__ == "__main__":
    unittest.main()
