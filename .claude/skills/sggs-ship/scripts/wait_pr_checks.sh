#!/usr/bin/env bash
# wait_pr_checks.sh PR [REPO] — wait until every check on the PR's CURRENT head commit has
# settled (guards against reading a previous push's finished checks right after a push),
# then print a compact summary + merge state. Exit 0 if no check failed, 1 otherwise. Read-only.
set -uo pipefail
PR="${1:?usage: wait_pr_checks.sh <pr-number> [repo]}"
REPO="${2:-Algorythmos-AI/sggs-knowledge-base}"
settled=0
for _ in $(seq 1 120); do            # ~30 min cap
  head=$(gh pr view "$PR" --repo "$REPO" --json headRefOid --jq .headRefOid 2>/dev/null)
  counts=$(gh api "repos/$REPO/commits/$head/check-runs?per_page=100" \
            --jq '"\(.total_count) \([.check_runs[] | select(.status != "completed")] | length)"' 2>/dev/null)
  total=${counts%% *}; pending=${counts##* }
  if [ -n "$head" ] && [ "${total:-0}" -gt 0 ] && [ "${pending:-1}" -eq 0 ]; then settled=1; break; fi
  sleep 15
done
echo "head: ${head:0:7}  check runs: ${total:-0}  pending: ${pending:-?}"
[ "$settled" = 1 ] || echo "WARN: timed out before all checks settled"
out=$(gh pr checks "$PR" --repo "$REPO" 2>/dev/null) || true
printf '%s\n' "$out" | awk -F'\t' '{printf "  %-24s %s\n", $1, $2}' | sort -u
state=UNKNOWN
for _ in 1 2 3 4 5 6; do
  state=$(gh pr view "$PR" --repo "$REPO" --json mergeStateStatus --jq .mergeStateStatus 2>/dev/null)
  [ "$state" != "UNKNOWN" ] && break; sleep 5
done
echo "mergeStateStatus: $state   (BLOCKED with all green = needs owner --admin merge)"
if [ "$settled" != 1 ] || printf '%s\n' "$out" | awk -F'\t' '{print $2}' | grep -qiE '^(fail|cancel)'; then
  echo "RESULT: NOT ALL GREEN"; exit 1
fi
echo "RESULT: ALL CHECKS PASSED"
