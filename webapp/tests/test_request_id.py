"""Request ids and the access log: one request can be followed from Vercel to the API, and the
log never records what anyone searched for (the privacy policy promises no added tracking)."""
import json
import os
import socket
import subprocess
import sys
import time
import unittest
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WEBAPP = ROOT / "webapp"
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
class RequestIdAndAccessLog(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.port = _free_port()
        env = dict(os.environ, SGGS_OPEN_BROWSER="0", SGGS_PORT=str(cls.port), SGGS_ACCESS_LOG="1")
        cls.proc = subprocess.Popen([sys.executable, "serve.py"], cwd=WEBAPP, env=env,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        for _ in range(80):
            try:
                cls.get("/healthz")
                break
            except OSError:
                time.sleep(0.25)

    @classmethod
    def tearDownClass(cls):
        cls.proc.terminate()
        out, err = cls.proc.communicate(timeout=10)
        cls.stdout, cls.log = out, err

    @classmethod
    def get(cls, path, headers=None):
        req = urllib.request.Request(f"http://127.0.0.1:{cls.port}{path}", headers=headers or {})
        with urllib.request.urlopen(req, timeout=15) as r:
            r.read()
            return r.headers.get("X-Request-Id")

    def test_the_answering_service_is_named(self):
        req = urllib.request.Request(f"http://127.0.0.1:{self.port}/api/meta")
        with urllib.request.urlopen(req, timeout=15) as r:
            self.assertEqual(r.headers.get("X-Service"), "all")

    def test_ids(self):
        generated = self.get("/api/meta")
        self.assertRegex(generated, r"^[0-9a-f]{32}$")
        self.assertEqual(self.get("/api/meta", {"X-Request-Id": "abc123def456"}), "abc123def456")
        vercel = "syd1::iad1::abcde-1790000000000-0123456789ab"
        self.assertEqual(self.get("/api/meta", {"x-vercel-id": vercel}), vercel)
        # Anything that is not a plain token is replaced, never echoed.
        self.assertRegex(self.get("/healthz", {"X-Request-Id": "a b<script>"}), r"^[0-9a-f]{32}$")

    def test_log_line_carries_the_id_but_never_the_query(self):
        rid = self.get("/api/search?q=secretphrase", {"X-Request-Id": "trace-search-0001"})
        self.assertEqual(rid, "trace-search-0001")
        # The log is read after the server stops (tearDownClass); check it there.
        type(self).expect_id = rid


def tearDownModule():
    cls = RequestIdAndAccessLog
    if not hasattr(cls, "log"):
        return
    lines = [json.loads(l) for l in cls.log.splitlines() if l.startswith("{")]
    search = [l for l in lines if l.get("id") == "trace-search-0001"]
    assert search and search[0]["p"] == "/api/search", lines
    assert "secretphrase" not in cls.log, "the access log must never contain a query string"
    start = [json.loads(l) for l in cls.stdout.splitlines() if l.startswith('{"event": "start"')]
    assert start and start[0]["version"] and start[0]["modules"], cls.stdout


if __name__ == "__main__":
    unittest.main()
