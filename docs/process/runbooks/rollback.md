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
The committed DB is a Git LFS object. To revert: `git revert <commit>` (or check out
the previous `db/sggs.sqlite` and `corpus/sggs.jsonl`), confirm `MANIFEST.db_sha256`
matches, and redeploy. Each GitHub Release records the shipped `db_sha256`.

## iOS
TestFlight → expire the bad build; promote the previous build. App Store: submit the
previous archive or a hotfix.
