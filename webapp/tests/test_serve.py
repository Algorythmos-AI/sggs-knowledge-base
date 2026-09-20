#!/usr/bin/env python3
"""
Stdlib unittest smoke suite for webapp/serve.py — runs in CI (web-ci) with no
extra deps. Needs the LFS DB present (db/sggs.sqlite). Run:
    python3 -m unittest discover -s webapp/tests -v
"""
import os, sys, unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "webapp"))
import serve  # noqa: E402

DB_PRESENT = os.path.exists(serve.DB)
skip_no_db = unittest.skipUnless(DB_PRESENT, "db/sggs.sqlite not present (run `git lfs pull`)")


class IntParsing(unittest.TestCase):
    def test_clamps_into_range(self):
        self.assertEqual(serve._int_str("5", 1, 10), 5)
        self.assertEqual(serve._int_str("0", 1, 10), 1)      # below → lo
        self.assertEqual(serve._int_str("99", 1, 10), 10)    # above → hi

    def test_rejects_oversized_digit_string(self):
        with self.assertRaises(ValueError):
            serve._int_str("9" * 40, 0, serve._ID_MAX)       # would OverflowError SQLite

    def test_rejects_non_integer(self):
        with self.assertRaises(ValueError):
            serve._int_str("abc", 0, 10)

    def test_int_reads_query_dict(self):
        self.assertEqual(serve._int({"limit": ["7"]}, "limit", 20, 1, 100), 7)
        self.assertEqual(serve._int({}, "limit", 20, 1, 100), 20)   # default


class FtsClean(unittest.TestCase):
    def test_strips_operator_chars(self):
        self.assertEqual(serve._fts_clean('naam"'), "naam")
        self.assertEqual(serve._fts_clean("naam*"), "naam")
        self.assertEqual(serve._fts_clean('a"*b'), "ab")


@skip_no_db
class ShabadEndpoint(unittest.TestCase):
    def test_shabad_includes_heading_run(self):
        # Ang 712 Todi shabad (comp 2845) must lead with the printed title header.
        d = serve.api("/api/shabad/2845", {})
        self.assertTrue(d["lines"], "shabad returned no lines")
        self.assertEqual(d["lines"][0]["is_header"], 1)
        self.assertTrue(d["lines"][0]["gurmukhi"].startswith("ਟੋਡੀ ਮਹਲਾ ੫ ਘਰੁ ੨"),
                        f"unexpected first line: {d['lines'][0]['gurmukhi']!r}")

    def test_gap_comp_id_raises_404(self):
        # comp 2844 folded away → gap → ApiError(404)
        with self.assertRaises(serve.ApiError) as ctx:
            serve.api("/api/shabad/2844", {})
        self.assertEqual(ctx.exception.status, 404)

    def test_meta_and_health_expose_commit(self):
        # deploy verification polls this to prove the running build is the tested SHA
        serve._META_CACHE = None
        self.assertIn("commit", serve.api("/api/meta", {}))
        self.assertIn("commit", serve.api("/api/health", {}))

    def test_health_all_true(self):
        h = serve.api("/api/health", {})
        self.assertTrue(h["ok"], f"health not ok: {h}")
        self.assertTrue(all(h["checks"].values()), f"a health check failed: {h['checks']}")

    def test_search_returns_results(self):
        r = serve.api("/api/search", {"q": ["maya magan swad lobh"]})
        self.assertGreater(len(r.get("results", [])), 0)


@skip_no_db
class BaniEndpoints(unittest.TestCase):
    """Nitnem registry: SGGS lines are verbatim pointers, non-SGGS text is a labelled layer."""

    def test_list_is_available_and_ordered(self):
        d = serve.api("/api/banis", {})
        self.assertTrue(d["available"])
        keys = [b["key"] for b in d["banis"]]
        self.assertEqual(keys[:5], ["japji", "jaap", "savaiye", "chaupai", "anand"])
        self.assertEqual(sum(1 for b in d["banis"] if b["key"] == "rehras"), 2)

    def test_japji_is_lines_1_to_385_verbatim(self):
        d = serve.api("/api/bani/japji", {})
        self.assertEqual([ln["id"] for ln in d["lines"]], list(range(1, 386)))
        self.assertTrue(d["lines"][0]["gurmukhi"].startswith("ੴ ਸਤਿ ਨਾਮੁ ਕਰਤਾ ਪੁਰਖੁ"))
        self.assertEqual((d["ang_first"], d["ang_last"]), (1, 8))
        self.assertTrue(all(ln["source"] == "sggs" for ln in d["lines"]))

    def test_rehras_default_and_variant(self):
        d = serve.api("/api/bani/rehras", {})
        self.assertEqual(d["bani"]["variant"], "sgpc")
        self.assertEqual(d["variants"], ["sgpc", "taksal"])
        t = serve.api("/api/bani/rehras", {"variant": ["taksal"]})
        self.assertGreater(len(t["lines"]), len(d["lines"]))

    def test_extra_lines_are_labelled_and_never_carry_english(self):
        d = serve.api("/api/bani/rehras", {})
        extra = [ln for ln in d["lines"] if ln["source"] != "sggs"]
        self.assertTrue(extra, "Rehras should contain the Dasam layer")
        for ln in extra:
            self.assertIn(ln["source"], ("dasam", "ardaas"))
            self.assertNotIn("en", ln)
            self.assertNotIn("ang", ln)          # never cited as an Ang
            self.assertIn("extra_id", ln)

    def test_unknown_key_is_404_and_bad_input_rejected(self):
        with self.assertRaises(serve.ApiError) as ctx:
            serve.api("/api/bani/no_such_bani", {})
        self.assertEqual(ctx.exception.status, 404)
        with self.assertRaises(ValueError):
            serve.api("/api/bani/../etc", {})
        with self.assertRaises(ValueError):
            serve.api("/api/bani/rehras", {"variant": ["x' OR 1=1"]})

    def test_meta_and_health_flag_the_registry(self):
        serve._META_CACHE = None
        self.assertTrue(serve.api("/api/meta", {})["banis_available"])
        self.assertTrue(serve.api("/api/health", {})["checks"]["banis_ok"])


if __name__ == "__main__":
    unittest.main(verbosity=2)


@skip_no_db
class AbuseResistance(unittest.TestCase):
    """One request must not be able to pin a core, and bad numbers are a 400, never a 500."""

    def test_oversized_verify_claim_is_rejected_fast(self):
        import time
        claim = " ".join(["waheguru"] * 2500)            # ~22 KB; measured ~7 s of CPU before the cap
        t0 = time.monotonic()
        with self.assertRaises(ValueError):
            serve.api("/api/verify", {"q": [claim]})
        self.assertLess(time.monotonic() - t0, 0.5)

    def test_verify_claim_at_the_limit_still_works(self):
        claim = ("ik oankar sat nam " * 40)[: serve.MAX_CLAIM_CHARS]
        self.assertIn("verdict", serve.api("/api/verify", {"q": [claim]}))

    def test_verify_ang_goes_through_int_parsing(self):
        for bad in ("abc", "1" * 40, "1e3"):
            with self.assertRaises(ValueError, msg=bad):
                serve.api("/api/verify", {"q": ["ik oankar"], "ang": [bad]})

    def test_ang_path_goes_through_int_parsing(self):
        for bad in ("abc", "1" * 40):
            with self.assertRaises(ValueError, msg=bad):
                serve.api(f"/api/ang/{bad}", {})
        self.assertEqual(serve.api("/api/ang/99999", {})["ang"], 1430)   # clamped, as before

    def test_resonance_min_lift_is_clamped(self):
        base = serve.api("/api/analytics/resonance", {})
        for weird in ("nan", "inf", "-inf", "banana"):
            r = serve.api("/api/analytics/resonance", {"min_lift": [weird]})
            self.assertEqual(len(r["edges"]), len(base["edges"]), weird)   # falls back to the default 1.0


@skip_no_db
class HttpBehaviour(unittest.TestCase):
    """The wire-level guarantees: caching, the idle-socket timeout, the worker ceiling."""

    @classmethod
    def setUpClass(cls):
        import threading
        serve._ACCESS_LOG = False
        cls._old_timeout = serve.H.timeout
        serve.H.timeout = 1
        cls.srv = serve.BoundedThreadingHTTPServer(("127.0.0.1", 0), serve.H, max_workers=2)
        cls.port = cls.srv.server_address[1]
        cls.thread = threading.Thread(target=cls.srv.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.srv.shutdown(); cls.srv.server_close()
        serve.H.timeout = cls._old_timeout

    def get(self, path, headers=None):
        import http.client
        con = http.client.HTTPConnection("127.0.0.1", self.port, timeout=10)
        con.request("GET", path, headers=headers or {})
        res = con.getresponse(); body = res.read(); con.close()
        return res, body

    def test_scripture_is_cacheable_with_an_etag(self):
        res, body = self.get("/api/ang/1")
        self.assertEqual(res.status, 200)
        self.assertIn("s-maxage", res.getheader("Cache-Control"))
        etag = res.getheader("ETag")
        self.assertTrue(etag)
        again, empty = self.get("/api/ang/1", {"If-None-Match": etag})
        self.assertEqual(again.status, 304)
        self.assertEqual(empty, b"")

    def test_live_endpoints_are_never_cached(self):
        for path in ("/api/health", "/api/meta", "/api/random", "/api/search?q=waheguru"):
            res, _ = self.get(path)
            self.assertEqual(res.getheader("Cache-Control"), "no-store", path)
            self.assertIsNone(res.getheader("ETag"), path)

    def test_errors_are_never_cached(self):
        res, _ = self.get("/api/ang/abc")
        self.assertEqual(res.status, 400)
        self.assertEqual(res.getheader("Cache-Control"), "no-store")

    def test_security_headers(self):
        res, _ = self.get("/api/meta")
        self.assertEqual(res.getheader("X-Content-Type-Options"), "nosniff")
        self.assertEqual(res.getheader("X-Frame-Options"), "DENY")
        self.assertIn("max-age", res.getheader("Strict-Transport-Security"))

    def test_idle_connection_is_dropped(self):
        import socket, time
        s = socket.create_connection(("127.0.0.1", self.port), timeout=5)
        t0 = time.monotonic()
        self.assertEqual(s.recv(1), b"")                  # server closes; a slow-loris gets no thread forever
        self.assertLess(time.monotonic() - t0, 4)
        s.close()

    def test_worker_slots_are_released(self):
        # 2 slots, 12 sequential requests, plus idle sockets that time out: no slot may leak.
        import socket, time
        idle = [socket.create_connection(("127.0.0.1", self.port), timeout=5) for _ in range(2)]
        time.sleep(1.6)                                    # both idle sockets time out and free their slots
        for _ in range(12):
            res, _ = self.get("/api/meta")
            self.assertEqual(res.status, 200)
        for s in idle: s.close()
