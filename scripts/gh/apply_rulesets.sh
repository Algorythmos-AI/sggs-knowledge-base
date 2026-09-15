#!/usr/bin/env bash
# Apply .github/rulesets/*.json to the repo via the GitHub API (idempotent:
# updates a ruleset with the same name if it already exists). Requires GitHub
# Team/Pro on the repo owner, and `gh auth` with admin on the repo.
#   REPO=Algorythmos-AI/sggs-knowledge-base bash scripts/gh/apply_rulesets.sh
set -euo pipefail
REPO="${REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
echo "Applying rulesets to $REPO"
existing="$(gh api "repos/$REPO/rulesets" --jq '.[] | "\(.id) \(.name)"' 2>/dev/null || true)"
for f in .github/rulesets/*.json; do
  name="$(python3 -c "import json,sys;print(json.load(open('$f'))['name'])")"
  id="$(echo "$existing" | awk -v n="$name" '$2==n{print $1}')"
  if [ -n "$id" ]; then
    echo "  updating '$name' (id $id) from $f"
    gh api -X PUT "repos/$REPO/rulesets/$id" --input "$f" >/dev/null
  else
    echo "  creating '$name' from $f"
    gh api -X POST "repos/$REPO/rulesets" --input "$f" >/dev/null
  fi
done
echo "Done. Verify in GitHub → Settings → Rules → Rulesets."
