# Runbook: Rollback

## Web (Vercel)
Vercel → the project → Deployments → previous good deploy → **Instant Rollback**.

## API (Render)
Render → the service → Events/Deploys → **Redeploy** the previous image. Health at
`/api/health` must return `ok:true`.

## Data (DB / corpus)
The committed DB is a Git LFS object. To revert: `git revert <commit>` (or check out
the previous `db/sggs.sqlite` and `corpus/sggs.jsonl`), confirm `MANIFEST.db_sha256`
matches, and redeploy. Each GitHub Release records the shipped `db_sha256`.

## iOS
TestFlight → expire the bad build; promote the previous build. App Store: submit the
previous archive or a hotfix.
