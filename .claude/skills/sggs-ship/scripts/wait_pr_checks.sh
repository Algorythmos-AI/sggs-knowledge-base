#!/usr/bin/env bash
# wait_pr_checks.sh PR [REPO] — wait until every check on a PR settles, print a compact
# summary + merge state. Exit 0 if no check failed, 1 otherwise. Read-only.
set -uo pipefail
PR="${1:?usage: wait_pr_checks.sh <pr-number> [repo]}"
REPO="${2:-Algorythmos-AI/sggs-knowledge-base}"
for _ in $(seq 1 120); do            # ~30 min cap
  out=$(gh pr checks "$PR" --repo "$REPO" 2>/dev/null) || true
  if [ -n "$out" ] && ! printf '%s\n' "$out" | awk '{print $2}' | grep -qiE '^(pending|queued|in_progress|expected)$'; then
    break
  fi
  sleep 15
done
printf '%s\n' "$out" | awk -F'\t' '{printf "  %-16s %s\n", $1, $2}' | sort -u
state=UNKNOWN
for _ in 1 2 3 4 5 6; do
  state=$(gh pr view "$PR" --repo "$REPO" --json mergeStateStatus --jq .mergeStateStatus 2>/dev/null)
  [ "$state" != "UNKNOWN" ] && break; sleep 5
done
echo "mergeStateStatus: $state   (BLOCKED with all green = needs owner --admin merge)"
if printf '%s\n' "$out" | awk -F'\t' '{print $2}' | grep -qiE '^(fail|cancel)'; then
  echo "RESULT: FAIL"; exit 1
fi
echo "RESULT: ALL CHECKS PASSED"
