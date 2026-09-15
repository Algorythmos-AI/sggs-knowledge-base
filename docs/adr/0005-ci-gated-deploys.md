# ADR-0005: Production deploys are performed by CI after gates, not by platform git hooks

**Status:** accepted (2026-09-15)

**Context.** After the repo moved to the org, the Vercel/Render GitHub Apps silently lost
access and production stayed on v1.0.0 with nothing alerting us. Platform git hooks also
deploy regardless of CI results, and a version-string check cannot prove which build is live.

**Decision.** `deploy-production.yml` deploys on push to `main` only after every required check
on that exact SHA succeeds. Render is triggered by a deploy hook pinned to the SHA (`ref=`);
the API must report that SHA (`/api/health.commit`). The web build is deployed unaliased,
smoke-tested, then promoted; a failed public smoke rolls back automatically. The release tag
is created only after a verified deploy. Platform auto-deploys are turned off after cutover.

**Consequences.** A deploy is observable, ordered, and provable. Secrets live in the GitHub
`production` environment. The Render/Vercel GitHub Apps are still required (Render clones the
repo to build; Vercel previews). Render rollback remains a documented manual step.
