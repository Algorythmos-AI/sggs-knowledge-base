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

    def test_health_all_true(self):
        h = serve.api("/api/health", {})
        self.assertTrue(h["ok"], f"health not ok: {h}")
        self.assertTrue(all(h["checks"].values()), f"a health check failed: {h['checks']}")

    def test_search_returns_results(self):
        r = serve.api("/api/search", {"q": ["maya magan swad lobh"]})
        self.assertGreater(len(r.get("results", [])), 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
