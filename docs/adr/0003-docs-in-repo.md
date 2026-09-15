# ADR-0003: The engineering wiki lives in `docs/`

**Status:** accepted (2026-09-15)

**Context.** No wiki or diagrams existed; GitHub Wiki needs Pro on a private repo
and is not PR-reviewed. 20+ loose audit reports sat at the repo root.

**Decision.** Keep the wiki as Markdown + Mermaid under `docs/`, versioned with the
code and reviewed in PRs. Migrate the loose reports into `docs/reports/`.

**Consequences.** Diagrams render natively on GitHub in any plan; docs cannot drift
from the code they ship with. A `lychee` link-check runs in CI (roadmap).
