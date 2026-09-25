# Environments

| | Local | Staging | Production |
|---|---|---|---|
| Branch | working tree | `integration` | `main` |
| Web | `serve.py` on :7777 | `sggs-staging.vercel.app` (SSO-protected; open logged in) | **`gurbanisoul.com`** (canonical) |
| API | same process | Vercel functions in the web project, one per context + `all` (ADR-0011) | Render `sggs-knowledge-base.onrender.com` |
| iOS | simulator | TestFlight **Internal** | TestFlight **External** / App Store |
| DB profile | full | full | full (public profile until the English licence is recorded) |
| Who deploys | you | `deploy-staging.yml` on push to integration | `deploy-production.yml` on push to main |

**Production domain.** The canonical public host is **`gurbanisoul.com`** (apex, 200, no redirect).
`www.gurbanisoul.com` and the legacy Vercel alias `sggs-knowledge-base.vercel.app` both **308**
→ apex, so there is one indexable host. DNS is Cloudflare DNS-only → Vercel; full topology and the
email routing are in [`docs/website/README.md`](../website/README.md).

## Same-origin API (no CORS)
The browser always calls `/api/*` on the site's own host, so no frontend configuration or CORS is
needed. On staging the rewrites are internal and **host-conditioned**: each context's prefixes go to
its function, everything else to `all`. Production proxies `/api` to the Render service. The rules
are generated (`tools/gen_gateway.py` from `gateway/routes.json`), for example:

```json
{ "source": "/api/timing(/.*)?",
  "has": [{ "type": "host", "value": "sggs-staging.vercel.app" }],
  "destination": "/api/svc/knowledge" },
{ "source": "/api/:path*",
  "destination": "https://sggs-knowledge-base.onrender.com/api/:path*" }
```

## As-code
- **Deploys are CI-gated** — see [runbook: deploy](runbooks/deploy.md). The platforms' own git
  auto-deploys are switched off after cutover.
- Render: production (`sggs-knowledge-base`, from `webapp/Dockerfile`) is a manually managed
  service; no Blueprint is committed. Staging no longer uses Render (ADR-0011).
- Vercel: `frontend/vercel.json` (root dir = `frontend/`) — production branch `main`,
  staging a custom environment tracking `integration`.
- `deploy-verify` CI curls `/api/health` and asserts `/api/meta.version` matches the
  branch's `APP_VERSION` after each deploy (catches a stale API).

## Environment variables (Vercel)
| Var | Scope | Purpose |
|---|---|---|
| `PUBLIC_NEWSLETTER_FORM_URL` | Production + Preview (unset in Development/CI/local) | Buttondown embed form endpoint for the landing's launch-notice sign-up. **Unset ⇒ the section, form and any Buttondown reference are absent from the built HTML.** Public POST endpoint, not a secret, but must never be committed (`NewsletterPrivacy` gate). See [runbook: newsletter](runbooks/newsletter.md). |

The App Store Connect API-key secrets used by TestFlight live in **GitHub Environments**
(`production`/`staging`), not Vercel — never echo a value; a pasted secret is a leaked secret.

## Rollback
Web: Vercel Instant Rollback. API: Render redeploy of the previous image. Data:
each GitHub Release attaches the DB manifest; restore from the tagged LFS object.
See [runbook: rollback](runbooks/rollback.md).

## Human-gated setup (one time)
Authorize the Vercel and Render GitHub Apps on the org, link the Render Blueprint,
create the Vercel `staging` custom environment + domain, add the App Store Connect
API-key secrets for TestFlight.
