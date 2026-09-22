#!/usr/bin/env bash
# release_preflight.sh — read-only readiness check for an integration → main release.
set -uo pipefail
REPO=Algorythmos-AI/sggs-knowledge-base
cd "$(git rev-parse --show-toplevel)" || exit 1
bad=0
ok()   { echo "  ok   $*"; }
warn() { echo "  WARN $*"; }
fail() { echo "  FAIL $*"; bad=1; }
git fetch -q origin --prune --tags

AHEAD=$(git rev-list --count origin/main..origin/integration)
if [ "$AHEAD" -gt 0 ]; then ok "integration has $AHEAD commit(s) not on main"
else fail "nothing to release (integration not ahead of main)"; fi
git log --oneline origin/main..origin/integration | sed 's/^/       /' | head -15

TIP=$(git rev-parse origin/integration)
if python3 scripts/ci/wait_for_checks.py "$TIP" --repo "$REPO" --extra playwright \
     --interval 5 --appear-timeout 20 --timeout 40 >/tmp/sggs_pf_checks.txt 2>&1; then
  ok "integration tip ${TIP:0:7}: all required checks green"
else
  fail "integration tip ${TIP:0:7}: checks not green → $(grep -E 'error|pending' /tmp/sggs_pf_checks.txt | tail -1)"
fi

V=$(git show origin/integration:webapp/serve.py | sed -n "s/^APP_VERSION = '\([^']*\)'.*/\1/p")
TMP=$(mktemp -d)
git worktree add -q --detach "$TMP" origin/integration 2>/dev/null
if (cd "$TMP" && python3 scripts/release/check_versions.py >/dev/null); then ok "versions unified at $V"
else fail "version strings disagree (run scripts/release/check_versions.py)"; fi
if (cd "$TMP" && python3 scripts/release/release_notes.py "$V" >/dev/null 2>&1); then ok "CHANGELOG has ## [$V]"
else fail "CHANGELOG missing ## [$V] section"; fi
git worktree remove --force "$TMP" >/dev/null 2>&1

if git rev-parse -q --verify "refs/tags/v$V" >/dev/null; then
  fail "v$V is already tagged — under the one-number policy every release to main bumps at least the patch (run scripts/release/bump.py). Never redeploy the same version."
else
  ok "v$V not yet tagged — this release will tag it"
fi

# One-number policy: the iOS ledger must not already hold this version from a different commit
# (that would mean an App Store binary was archived before this release — a number mismatch).
LEDGER_SHAS=$(python3 - "$V" <<'PY' 2>/dev/null
import json, sys
v = sys.argv[1]
try:
    rows = json.load(open("ios/testflight-builds.json")).get("builds", [])
except Exception:
    rows = []
print(" ".join(sorted({r.get("source_commit","")[:12] for r in rows if r.get("version")==v and r.get("source_commit")})))
PY
)
if [ -n "$LEDGER_SHAS" ]; then
  warn "iOS $V already in the ledger from $LEDGER_SHAS — the release-complete check will require it to match the tag commit; if it was a different commit, bump instead"
else
  ok "no iOS $V upload yet — release completes when iOS $V (1) is uploaded from tag v$V (check_release_complete.py)"
fi

OPEN=$(gh pr list --repo "$REPO" --base main --state open --json number --jq 'map(.number)|join(",")')
if [ -z "$OPEN" ]; then ok "no open PR into main"; else fail "release PR already open: #$OPEN"; fi

if [ "$bad" = 0 ]; then echo "PREFLIGHT: READY to release v$V"; exit 0; fi
echo "PREFLIGHT: NOT READY"; exit 1
