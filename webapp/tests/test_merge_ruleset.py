"""scripts/gh/merge_ruleset.py: applying a committed ruleset never resets a live-only protection."""
import json, sys, unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "gh"))
import merge_ruleset as mr  # noqa: E402

LIVE = {
    "id": 1, "name": "protect-main-production", "target": "branch", "enforcement": "active",
    "conditions": {"ref_name": {"include": ["refs/heads/main"], "exclude": []}},
    "bypass_actors": [{"actor_id": None, "actor_type": "OrganizationAdmin", "bypass_mode": "always"}],
    "rules": [
        {"type": "deletion"},
        {"type": "pull_request", "parameters": {"required_approving_review_count": 1, "require_extra_approval_for_unattributed_changes": True,
                                                  "allowed_merge_methods": ["merge", "squash", "rebase"]}},
        {"type": "required_status_checks", "parameters": {"strict_required_status_checks_policy": True, "do_not_enforce_on_create": False,
                                                            "required_status_checks": [{"context": "python"}]}},
    ],
}
COMMITTED = {
    "name": "protect-main-production", "target": "branch", "enforcement": "active",
    "conditions": LIVE["conditions"], "bypass_actors": LIVE["bypass_actors"],
    "rules": [
        {"type": "deletion"},
        {"type": "pull_request", "parameters": {"required_approving_review_count": 1}},
        {"type": "required_status_checks", "parameters": {"strict_required_status_checks_policy": True,
                                                            "required_status_checks": [{"context": "python"}, {"context": "docs"}]}},
    ],
}


class MergeRuleset(unittest.TestCase):
    def test_live_only_keys_survive_and_the_file_wins_where_it_speaks(self):
        m = mr.merge(LIVE, COMMITTED)
        rules = {r["type"]: r.get("parameters") for r in m["rules"]}
        self.assertTrue(rules["pull_request"]["require_extra_approval_for_unattributed_changes"])
        self.assertEqual(rules["pull_request"]["allowed_merge_methods"], ["merge", "squash", "rebase"])
        self.assertFalse(rules["required_status_checks"]["do_not_enforce_on_create"])
        self.assertEqual(rules["required_status_checks"]["required_status_checks"], [{"context": "python"}, {"context": "docs"}])
        self.assertNotIn("id", m)                                   # read-only fields are never PUT

    def test_the_diff_names_only_the_real_change(self):
        self.assertEqual(mr.diff(LIVE, mr.merge(LIVE, COMMITTED)),
                         ['required_status_checks.required_status_checks: [{"context": "python"}] -> [{"context": "python"}, {"context": "docs"}]'])

    def test_a_live_only_rule_is_kept(self):
        live = json.loads(json.dumps(LIVE)); live["rules"].append({"type": "non_fast_forward"})
        self.assertIn("non_fast_forward", [r["type"] for r in mr.merge(live, COMMITTED)["rules"]])


if __name__ == "__main__":
    unittest.main()
