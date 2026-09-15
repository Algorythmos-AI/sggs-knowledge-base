# Environments

| | Local | Staging | Production |
|---|---|---|---|
| Branch | working tree | `integration` | `main` |
| Web | `serve.py` on :7777 | `sggs-staging.vercel.app` | `sggs-knowledge-base.vercel.app` |
| API | same process | Render `sggs-api-staging` | Render `sggs-api` |
| iOS | simulator | TestFlight **Internal** | TestFlight **External** / App Store |
| DB profile | full | full | full (public profile until the English licence is recorded) |
| Who deploys | you | auto on merge to `integration` | auto on release PR to `main` |

## Same-origin API (no CORS)
The browser always calls `/api/*`; Vercel rewrites those to the Render service.
The staging rewrite is **host-conditioned**, so no frontend configuration or CORS
is needed:

```json
{ "source": "/api/:path*",
  "has": [{ "type": "host", "value": "sggs-staging.vercel.app" }],
  "destination": "https://sggs-api-staging.onrender.com/api/:path*" },
{ "source": "/api/:path*",
  "destination": "https://sggs-knowledge-base.onrender.com/api/:path*" }
```

## As-code
- Render: `render.yaml` (Blueprint) defines both services from `webapp/Dockerfile`.
- Vercel: `frontend/vercel.json` (root dir = `frontend/`) — production branch `main`,
  staging a custom environment tracking `integration`.
- `deploy-verify` CI curls `/api/health` and asserts `/api/meta.version` matches the
  branch's `APP_VERSION` after each deploy (catches a stale API).

## Rollback
Web: Vercel Instant Rollback. API: Render redeploy of the previous image. Data:
each GitHub Release attaches the DB manifest; restore from the tagged LFS object.
See [runbook: rollback](runbooks/rollback.md).

## Human-gated setup (one time)
Authorize the Vercel and Render GitHub Apps on the org, link the Render Blueprint,
create the Vercel `staging` custom environment + domain, add the App Store Connect
API-key secrets for TestFlight.
