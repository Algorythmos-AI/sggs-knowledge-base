"""contract_http: the HTTP replay shares the generator's projections and only the documented normalisations."""
import sys, unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
_argv = sys.argv
sys.argv = sys.argv[:1]
import contract_http as ch  # noqa: E402
sys.argv = _argv


class Normalisation(unittest.TestCase):
    def test_search_null_related_themes_equals_empty_list(self):
        self.assertEqual(ch.normalise("search", {"related_themes": None}), {"related_themes": []})

    def test_other_suites_are_untouched(self):
        self.assertEqual(ch.normalise("timing", {"related_themes": None}), {"related_themes": None})

    def test_tuples_compare_as_lists(self):
        self.assertEqual(ch.normalise("reader", {"x": (1, 2)}), {"x": [1, 2]})

    def test_only_empty_verify_claims_are_excluded(self):
        rows = [{"claim": ""}, {"claim": "  "}, {"claim": "ਨਾਮੁ"}, {"claim": '"'}]
        self.assertEqual(ch._comparable("verify", rows), [{"claim": "ਨਾਮੁ"}, {"claim": '"'}])

    def test_generator_defaults_to_in_process_transport(self):
        self.assertTrue(ch.g.HUKAM)
        self.assertEqual(ch.g.API.__module__, "gen_golden_vectors")

    def test_hukam_is_the_only_reader_exclusion(self):
        kinds = {r.get("kind") for r in ch.committed("reader")}
        self.assertNotIn("hukam", kinds)
        self.assertTrue({"ang", "shabad", "neighbors"} <= kinds)


if __name__ == "__main__":
    unittest.main()
