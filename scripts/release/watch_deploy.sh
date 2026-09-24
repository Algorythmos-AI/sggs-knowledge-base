#!/usr/bin/env bash
# watch_deploy.sh [SHA] — follow deploy-production for a commit, printing job transitions.
# Exit 0 if the run succeeds, 1 otherwise. Read-only.
set -uo pipefail
REPO=Algorythmos-AI/sggs-platform
git fetch -q origin 2>/dev/null
SHA="${1:-$(git rev-parse origin/main)}"
echo "commit: $SHA ($(git log -1 --pretty=%s "$SHA" 2>/dev/null))"
RUN=""
for _ in $(seq 1 30); do
  RUN=$(gh run list --repo "$REPO" --workflow deploy-production.yml --commit "$SHA" --limit 1 --json databaseId --jq '.[0].databaseId // empty' 2>/dev/null)
  [ -n "$RUN" ] && break; sleep 10
done
[ -n "$RUN" ] || { echo "no deploy-production run found for $SHA (was it pushed to main?)"; exit 1; }
echo "run: https://github.com/$REPO/actions/runs/$RUN"
last=""
for _ in $(seq 1 240); do          # ~60 min cap
  line=$(gh run view "$RUN" --repo "$REPO" --json status,conclusion,jobs \
    --jq '"\(.status)/\(.conclusion // "-")  " + ([.jobs[] | "\(.name)=\(.conclusion // .status)"] | join(" "))' 2>/dev/null)
  [ -n "$line" ] && [ "$line" != "$last" ] && { echo "[$(date '+%H:%M:%S')] $line"; last="$line"; }
  case "$line" in completed/*) break ;; esac
  sleep 15
done
case "$last" in
  completed/success*) echo "DEPLOY: SUCCESS"; exit 0 ;;
  *) echo "DEPLOY: NOT SUCCESSFUL — inspect: gh run view $RUN --repo $REPO --log-failed"; exit 1 ;;
esac
