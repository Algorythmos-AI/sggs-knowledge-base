#!/usr/bin/env bash
# release_preflight.sh — read-only readiness check for an integration → main release.
set -uo pipefail
REPO=Algorythmos-AI/sggs-knowledge-base
cd "$(git rev-parse --show-toplevel)" || exit 1
fail() { echo "  FAIL $*"; bad=1; }
ok()   { echo "  ok   $*"; }
bad=0
git fetch -q origin --prune --tags
AHEAD=$(git rev-list --count origin/main..origin/integration)
[ "$AHEAD" -gt 0 ] && ok "integration has $AHEAD commit(s) not on main" || fail "nothing to release (integration not ahead of main)"
git log --oneline origin/main..origin/integration | sed 's/^/       /' | head -15

TIP=$(git rev-parse origin/integration)
if python3 scripts/ci/wait_for_checks.py "$TIP" --repo "$REPO" --extra playwright --interval 5 --appear-timeout 20 --timeout 40 >/tmp/sggs_pf_checks.txt 2>&1; then
  ok "integration tip ${TIP:0:7}: all required checks green"
else
  fail "integration tip ${TIP:0:7}: checks not green → $(grep -E 'error|pending' /tmp/sggs_pf_checks.txt | tail -1)"
fi

V=$(git show origin/integration:webapp/serve.py | sed -n "s/^APP_VERSION = '\([^']*\)'.*/\1/p")
TMP=$(mktemp -d); git worktree add -q --detach "$TMP" origin/integration 2>/dev/null
( cd "$TMP" && python3 scripts/release/check_versions.py >/dev/null ) && ok "versions unified at $V" || fail "version strings disagree (run check_versions.py)"
( cd "$TMP" && python3 scripts/release/release_notes.py "$V" >/dev/null 2>&1 ) && ok "CHANGELOG has ## [$V]" || fail "CHANGELOG missing ## [$V] section"
git worktree remove --force "$TMP" >/dev/null 2>&1

warn() { echo "  WARN $*"; }
git rev-parse -q --verify "refs/tags/v$V" >/dev/null \
  && warn "v$V is already tagged — no new tag will be cut. Fine for CI/infra-only changes; bump (scripts/release/bump.py) if users see a change" \
  || ok "v$V not yet tagged — this release will tag it"

OPEN=$(gh pr list --repo "$REPO" --base main --state open --json number --jq 'map(.number)|join(",")')
[ -z "$OPEN" ] && ok "no open PR into main" || fail "release PR already open: #$OPEN"

[ "$bad" = 0 ] && { echo "PREFLIGHT: READY to release v$V"; exit 0; } || { echo "PREFLIGHT: NOT READY"; exit 1; }
