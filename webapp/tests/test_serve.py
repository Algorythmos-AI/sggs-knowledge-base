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
