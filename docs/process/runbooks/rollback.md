---
title: "Runbook: Rollback"
description: "Rolling the web and the API back to the previous known-good deployment on Vercel and Render."
sidebar:
  order: 2
verified:
  commit: c54f37fd
  date: "2026-09-25"
---
# Runbook: Rollback

## Web (Vercel)
The pipeline rolls back automatically if the promote or the public smoke after it fails; a failure
before promote (checkout, setup) leaves the previous deployment serving and rolls nothing back.

The rollback target is the deployment `gurbanisoul.com` resolves to when `deploy-web` starts
(`scripts/ci/vercel_api.py live`, i.e. `GET /v13/deployments/gurbanisoul.com`), printed in that job's
log as `previous production deployment:`. It is never "the newest READY production deployment": a
build that was deployed unaliased and then failed its smoke is READY and `target=production` too, but
was never promoted. If the lookup fails, or no READY deployment serves the domain, `deploy-web` stops
before building and nothing is deployed.

Manually: `vercel rollback <previous-deployment-url> --yes` with that logged URL, or Vercel →
Deployments → the deployment that last served the domain → **Instant Rollback**. Not sure which one
that was? `VERCEL_TOKEN=… VERCEL_ORG_ID=… python3 scripts/ci/vercel_api.py live gurbanisoul.com`
prints the one serving it now.

## API (Render)
Render → the service → Events → previous successful deploy → **Rollback**. Then confirm
`/api/health` returns `ok:true` and `commit` equals the rolled-back SHA. Close the incident issue
the pipeline opened, and fix forward through a normal PR.

## Data (DB / corpus)
The database is pinned by `dataset.lock.json`. To revert a dataset, revert the lock bump
(`git revert <commit>`): the image and CI install the previous object, sha256-verified, and
nothing in sggs-data is ever deleted, so every previously pinned object stays available.
Redeploy through the normal pipeline.

## iOS
In `Algorythmos-AI/gurbani-soul-ios` (its `ios-hotfix` runbook): TestFlight → expire the bad
build; the App Store has no binary rollback, so pause the phased release and ship a fix.
