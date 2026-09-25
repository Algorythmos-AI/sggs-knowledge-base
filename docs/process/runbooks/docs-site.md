---
title: "Runbook: the docs site (launch and after)"
description: "Launching docs.gurbanisoul.com and keeping it honest: one-time setup, the staging walkthrough, DNS cut-over, production smoke, rollback, and the routine after launch."
sidebar:
  order: 6
verified:
  commit: efcd3edb
  date: "2026-09-25"
---
# Runbook: the docs site (launch and after)

The wiki (`docs-site/` over `docs/`, [ADR-0012](../../adr/0012-docs-site.md)) deploys through
`deploy-docs.yml` with the product's posture: CI builds, deploys, smokes by commit, promotes, rolls
back; the Vercel project's own git deployments are off. This runbook is the launch checklist and
the routine that follows it.

## 1. One-time setup (owner)

The Vercel project, the domain, the staging alias and the two secrets — steps 1–5 of
[the deploy runbook's wiki section](deploy.md#the-wiki-docsgurbanisoulcom--one-time-setup-owner).
Until they exist, every push to `integration` still runs the full `docs` job (the required check),
and `deploy-staging` fails clearly at preflight.

Then apply the ruleset that makes the docs job required:

```bash
REPO=Algorythmos-AI/sggs-platform bash scripts/gh/apply_rulesets.sh
```

## 2. Staging walkthrough (before the first promotion)

Open `https://sggs-docs-staging.vercel.app` logged in to Vercel. Run the visual pass the build
cannot judge — the same list the repository's QA script shoots
(`cd docs-site && node scripts/visual-qa.mjs <url>` writes light, dark and phone screenshots of
every section under `docs-site/qa-shots/`):

| Check | Where |
|---|---|
| The landing, the live status strip shows production's version and health | `/` |
| A poster walkthrough: Next, arrow keys, a step chip, Full size, Escape returns focus | `/architecture/request-lifecycle/` |
| The Ang explorer on Angs 1, 712, 1256; the English toggle; the outage message with the network off | `/data/line-record/` |
| The search simulator with `sat nam`, `waheguru`, `mercy`, a Gurmukhi query; the tier lights on poster 05 | `/architecture/search-waterfall/` |
| The verify playground with a line from memory; the rung lights on poster 07 | `/search/verification-engine/` |
| The API console: an Ang, a search, copy as curl | `/api/` |
| A pinned page's canonical banner and edit link | `/data/architecture/database-schema/`, `/ios/nitnem/spec/` |
| Hover-cards and a quiz; the two cited lines stack Gurmukhi, transliteration, citation | `/scripture/what-sggs-is/` |
| A learning path's ticks survive a reload | `/learning-paths/platform-engineer/` |
| Search (⌘K) finds a technical term and a scripture term | any page |
| Dark mode on every section; phone width with no horizontal scroll | every section |
| The 404 page; a page's Open Graph card (`/og/<id>.png`) | `/nope/`, `/og/index.png` |

Anything wrong is a normal pull request into `integration`; the site redeploys to staging on merge.

## 3. Production

1. Cloudflare: `CNAME docs →` Vercel's recommended target, DNS-only. Vercel: the domain is attached to
   `sggs-docs` and shows *Valid Configuration*.
2. Merge the next release PR `integration → main` (a merge commit, as always). `deploy-docs`'s
   `deploy-production` job records the deployment the domain serves now (the rollback target),
   builds, deploys unaliased, smokes by commit, promotes to `docs.gurbanisoul.com`, smokes again —
   and rolls back if the public smoke fails. Every failure opens an issue that says whether
   production changed.

   > [!NOTE]
   > **A project's first Vercel deployment became production.** On 2026-09-26 the docs
   > project's first deployment — a *preview* from `deploy-staging` — was recorded as production,
   > and `docs.gurbanisoul.com` attached to it, so the domain served an `integration` build until
   > the 1.3.10 release. `deploy-staging` now refuses to run while the project has no production
   > deployment (`scripts/ci/vercel_api.py has-production`) and fails if its own deployment is not
   > a preview. For a new Vercel project, the first deployment must come from `deploy-production`.
3. Prove it:

   ```bash
   python3 scripts/ci/docs_smoke.py https://docs.gurbanisoul.com --commit <sha>
   ```

   The smoke checks the landing, a Mermaid render, the search index, `/api/health` and `/api/meta`
   through the rewrite, the poster the architecture page links as "open full size" and an Open
   Graph card, and that `<meta name="sggs-docs-commit">` equals the commit. Nothing may redirect:
   a redirect on `/api` is how the widgets broke before launch (`trailingSlash`).
4. Owner walkthrough of section 2 on the public domain, once.

## 4. Rollback

The job rolls back on its own when the public smoke fails **after** promotion, to the deployment
the domain served before the run (read from Vercel by the domain, never "the newest production
deployment": a build deployed with `--skip-domain` whose smoke failed is also a READY production
deployment, but it never served anyone). A failure before promotion changes nothing and says so in
its issue. By hand: `python3 scripts/ci/vercel_api.py live docs.gurbanisoul.com` names the serving
deployment; Vercel → `sggs-docs` → Deployments → the previous good deployment → *Instant Rollback*,
or `vercel rollback <previous-url> --scope <team>` with the docs project's token. After a rollback
Vercel stops assigning the domain automatically; the next `deploy-production` run's `vercel promote`
restores it. The wiki carries no state, so a rollback costs nothing but the newer pages.

## 5. After launch: the routine

| When | What |
|---|---|
| every pull request | the `docs` check (required on `integration`): gates, build, links, budgets, e2e, axe on every page, Lighthouse on twenty |
| a dataset bump lands | nothing to do: the docs job installs the pinned database and re-verifies the cited lines |
| sggs-data or the app changes a document the wiki pins | `python3 tools/fetch_sibling_docs.py --update <name>` in a small pull request (a bump shows exactly which files changed) |
| Mondays | `docs-links` checks every external link and opens an issue on a failure; `security` scans the history |
| a page under process, engineering or architecture is 60 commits behind its stamp | the gate warns: re-read the page against the code and move the stamp |
| a new page | frontmatter, links, the scripture rule and the fallback rule are gated; a poster or a widget follows [the contributing guides](../../contributing/README.md) |

## 6. Sibling README links (owner, after launch)

Two small pull requests point readers of the sibling repositories at the wiki. Suggested text,
for the top of each README:

- **sggs-data** — *"The engineering wiki publishes this repository's docs at
  [docs.gurbanisoul.com/data](https://docs.gurbanisoul.com/data/), pinned at a commit; edit them here."*
- **gurbani-soul-ios** — *"The engineering wiki publishes this repository's docs at
  [docs.gurbanisoul.com/ios](https://docs.gurbanisoul.com/ios/), pinned at a commit; edit them here."*

## 7. Open review items

- The scholar review (gate G3) of [Scripture 101](../../scripture/README.md), the glossary's
  scripture terms and the contributors chronology.
- sggs-data's `database-schema.md` states 4,706 compositions and `max(comp_id)` 5,380; the pinned
  database holds 4,527 and 5,376. The wiki's pages use the database; the data repository's page
  needs its own correction.
