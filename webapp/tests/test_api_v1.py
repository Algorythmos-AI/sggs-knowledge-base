"""/api/v1/* serves the same bodies as /api/*, with strict semantics: an unknown endpoint is 404 and
every error is {"error": {"code", "message", "request_id"}}. Legacy /api/* is unchanged."""
import json
import os
import socket
import subprocess
import sys
import time
import unittest
import urllib.error
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
class ApiV1(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.port = _free_port()
        env = dict(os.environ, SGGS_OPEN_BROWSER="0", SGGS_PORT=str(cls.port), SGGS_ACCESS_LOG="0")
        cls.proc = subprocess.Popen([sys.executable, "serve.py"], cwd=ROOT / "webapp", env=env,
                                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(80):
            try:
                cls.get("/healthz")
                break
            except OSError:
                time.sleep(0.25)

    @classmethod
    def tearDownClass(cls):
        cls.proc.terminate()
        cls.proc.wait(timeout=10)

    @classmethod
    def get(cls, path):
        try:
            with urllib.request.urlopen(f"http://127.0.0.1:{cls.port}{path}", timeout=20) as r:
                return r.status, r.read(), r.headers
        except urllib.error.HTTPError as e:
            with e:
                return e.code, e.read(), e.headers

    def test_same_bodies_as_legacy(self):
        for path in ("ang/712", "search?q=naam", "shabad/2", "timing/clock", "verify?q=sochai%20soch",
                     "themes/network", "meta"):
            with self.subTest(path=path):
                legacy, v1 = self.get(f"/api/{path}"), self.get(f"/api/v1/{path}")
                self.assertEqual((v1[0], v1[1]), (legacy[0], legacy[1]))

    def test_unknown_endpoint_is_404_with_the_envelope(self):
        status, body, headers = self.get("/api/v1/nope")
        err = json.loads(body)["error"]
        self.assertEqual((status, err["code"]), (404, "not_found"))
        self.assertEqual(err["request_id"], headers["X-Request-Id"])

    def test_errors_use_the_envelope(self):
        status, body, _ = self.get("/api/v1/shabad/1")          # a comp_id gap
        self.assertEqual((status, json.loads(body)["error"]["code"]), (404, "not_found"))
        status, body, _ = self.get("/api/v1/ang/abc")
        self.assertEqual((status, json.loads(body)["error"]["code"]), (400, "invalid_request"))

    def test_legacy_semantics_are_unchanged(self):
        status, body, _ = self.get("/api/nope")
        self.assertEqual((status, json.loads(body)), (400, {"error": "invalid request: unknown endpoint"}))


if __name__ == "__main__":
    unittest.main()
