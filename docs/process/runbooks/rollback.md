# Runbook: Rollback

## Web (Vercel)
The pipeline rolls back automatically if the public smoke fails after promote. Manually:
`vercel rollback <previous-deployment-url> --yes` (the previous URL is printed in the
`deploy-web` job log), or Vercel → Deployments → previous good deploy → **Instant Rollback**.

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
