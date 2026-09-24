"""The editorial ledger gate: scripture text changes only through a registered entry."""
import json, sys, unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline"))
import ledger_check as lc  # noqa: E402

LEDGER = lc.parse_ledger((ROOT / lc.LEDGER).read_text(encoding="utf-8"))
SOURCE = (ROOT / lc.PIPELINE).read_text(encoding="utf-8")
PDF_SHA = json.loads((ROOT / "validation/reconcile-attestation.json").read_text())["pdf_sha256"]


def corpus(rows):
    return "\n".join(json.dumps(r, ensure_ascii=False) for r in rows) + "\n"


BASE = [{"id": 1, "ang": 1, "gurmukhi": "ੴ ਸਤਿ ਨਾਮੁ", "text": "ੴ ਸਤਿ ਨਾਮੁ", "markers": [], "comp_id": 2},
        {"id": 2, "ang": 1, "gurmukhi": "ਆਦਿ ਸਚੁ", "text": "ਆਦਿ ਸਚੁ", "markers": [], "comp_id": 2}]


class CommittedLedger(unittest.TestCase):
    def test_ledger_is_well_formed_and_bound_to_the_attested_pdf(self):
        self.assertEqual(lc.check_ledger(LEDGER, PDF_SHA), [])

    def test_code_rules_equal_ledger_rules(self):
        self.assertEqual(lc.check_code_matches_ledger(LEDGER, SOURCE), [])
        self.assertEqual(len(lc.code_editorial_rules(SOURCE)), 4)

    def test_every_documented_application_is_recorded(self):
        angs = sorted(e["ang"] for e in LEDGER if e.get("kind") == "application")
        self.assertEqual(angs, [573, 586, 727, 1354, 1358, 1387, 1398, 1402, 1406, 1408, 1409])


class CodeDrift(unittest.TestCase):
    def test_new_rule_in_code_without_ledger_fails(self):
        src = SOURCE.replace("for a, b in [('\\u0a4d\\u0a30", "for a, b in [('\\u0a15', '\\u0a16'), ('\\u0a4d\\u0a30", 1)
        self.assertNotEqual(src, SOURCE, "fixture did not apply")
        fails = lc.check_code_matches_ledger(LEDGER, src)
        self.assertTrue(any("not registered" in f for f in fails))

    def test_rule_removed_from_code_fails(self):
        ledger = LEDGER + [{"kind": "rule", "id": "R9", "class": "editorial", "match": "literal",
                            "before": "ਕ", "after": "ਖ"}]
        self.assertTrue(any("no longer in fix_text" in f for f in lc.check_code_matches_ledger(ledger, SOURCE)))

    def test_wrong_pdf_binding_fails(self):
        self.assertTrue(any("evidence PDF" in f for f in lc.check_ledger(LEDGER, "0" * 64)))


class CorpusDiff(unittest.TestCase):
    def test_unchanged_corpus_passes(self):
        self.assertEqual(lc.check_corpus_diff(corpus(BASE), corpus(BASE), LEDGER, LEDGER), ([], []))

    def test_structure_only_change_is_not_a_scripture_change(self):
        head = [dict(r, comp_id=3) for r in BASE]           # T1 (comp_id) is governed by verify_regroup
        self.assertEqual(lc.check_corpus_diff(corpus(BASE), corpus(head), LEDGER, LEDGER), ([], []))

    def test_unregistered_text_change_fails(self):
        head = [BASE[0], dict(BASE[1], gurmukhi="ਆਦਿ ਸਚੁ ॥")]
        fails, changed = lc.check_corpus_diff(corpus(BASE), corpus(head), LEDGER, LEDGER)
        self.assertEqual(changed, [2])
        self.assertTrue(fails)

    def test_registered_text_change_passes(self):
        head = [BASE[0], dict(BASE[1], gurmukhi="ਆਦਿ ਸਚੁ ॥")]
        new = LEDGER + [{"kind": "application", "id": "E999", "rule": "R1", "candidate_line_ids": [2],
                         "review": "approved by two scripture reviewers"}]
        self.assertEqual(lc.check_corpus_diff(corpus(BASE), corpus(head), LEDGER, new)[0], [])

    def test_old_entry_cannot_cover_a_new_change(self):
        head = [BASE[0], dict(BASE[1], text="changed")]
        old = LEDGER + [{"kind": "application", "id": "E998", "rule": "R1", "candidate_line_ids": [2], "review": "x"}]
        self.assertTrue(lc.check_corpus_diff(corpus(BASE), corpus(head), old, old)[0])

    def test_added_or_removed_lines_always_fail(self):
        self.assertTrue(lc.check_corpus_diff(corpus(BASE), corpus(BASE[:1]), LEDGER, LEDGER)[0])


if __name__ == "__main__":
    unittest.main()
