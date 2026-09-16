---
name: sggs-verify-prod
description: Prove what the SGGS Knowledge Base production site is actually serving — version, running commit, health, the Ang 712 heading regression, and which Vercel deployment owns the public domain. Use whenever the user asks "is it live", "check production", "verify prod", "did the deploy work", "what version is live", after any deploy or release, or before telling the user something is shipped. Never claim production state without running this.
---

# Verify production (SGGS Knowledge Base)

Production = web on Vercel (`https://sggs-knowledge-base.vercel.app`) + API on Render
(`https://sggs-knowledge-base.onrender.com`). The web proxies `/api/*` to Render, so a
healthy `/api` through the web domain does NOT prove the website build changed — check
both the API identity and the Vercel deployment serving the domain.

## Run
```bash
python3 .claude/skills/sggs-verify-prod/scripts/verify_prod.py [--commit <sha>] [--version X.Y.Z]
```
- `--commit`: expected running SHA (usually `git rev-parse origin/main`). The API reports
  it in `/api/health.commit`; identity beats version (a deploy may not bump the version).
- It exits non-zero on any failure and prints one line per check.

It checks: API health (all checks true), commit/version match, Ang 712 composition opens
with `ਟੋਡੀ ਮਹਲਾ ੫ ਘਰੁ ੨ ਚਉਪਦੇ`, gap comp_id 2844 → 404, the same through the web domain,
and (if the Vercel CLI is logged in) which deployment id serves the public domain.

## Report
State the result plainly: version, commit (short), deployment id, pass/fail per check.
If the web assets matter (UI change shipped), also compare the public page's
`/_astro/Base.*.css` hash with the expected build.

For a deeper data check against the committed DB (needs `db/sggs.sqlite` via LFS):
```bash
python3 pipeline/api_superset_check.py --db db/sggs.sqlite --url https://sggs-knowledge-base.onrender.com --sample 100
```
