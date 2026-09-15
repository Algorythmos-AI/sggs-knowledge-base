# ADR-0001: `integration` is the trunk; `main` is production

**Status:** accepted (2026-09-15)

**Context.** The repo shipped straight from `main` with no staging and no gates.
The team wants to test on integration/staging before production.

**Decision.** `integration` becomes the default branch and trunk (auto-deploys
staging). `main` is a protected production branch that only receives release PRs
from `integration`/`hotfix`. Rulesets enforce this once the owner is on GitHub Team.

**Consequences.** A merge to `integration` is always safe to stage; production is
always a deliberate, tagged release. Requires GitHub Team for enforced protection.
