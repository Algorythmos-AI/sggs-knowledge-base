# Runbook: move production onto the per-context services

Staging already runs every bounded context as its own service behind the generated gateway
(ADR-0010). Production still runs the single API. When the hosting spend is approved, production
moves the same way — one context at a time, each proven before the next, each reversible in one line.

## Prerequisites
- Budget approved for five always-on paid Render instances (the smallest class fits every slice).
- A green staging deploy with every context routed (`deploy-staging` → verify: every probe `ok`,
  the golden contract PASS through the gateway).

## Steps
1. **Declare the services.** Add `sggs-prod-<context>` services to a production Blueprint (not the
   staging `render.yaml`, which must never create production services): `runtime: docker`,
   `dockerfilePath: ./webapp/Dockerfile`, a paid always-on plan, `healthCheckPath: /readyz`,
   `autoDeploy: false`, env `SGGS_MODULES=<context>`. Create them from the dashboard.
2. **Deploy them from CI.** Add a `deploy-services` job to `deploy-production.yml` mirroring staging's
   (Render API, exact commit, `wait_for_deploy.py --readyz`), with `RENDER_API_KEY` in the
   `production` environment. It runs after `verify-api` and before `deploy-web`.
3. **Route one context.** In `gateway/routes.json` set `production.service_origin` to
   `https://sggs-prod-{context}.onrender.com` and add the first context (knowledge) to
   `production.services`; run `python3 tools/gen_gateway.py`. Release it through the normal pipeline.
   Verify on production: `curl -sI https://gurbanisoul.com/api/timing/clock | grep -i x-service`
   shows `knowledge`; `make verify-prod`; `make canary`.
4. **Hold the budget.** From the same place the baseline was taken:
   `python3 tools/perf_baseline.py --base https://gurbanisoul.com --from "<same vantage>" --compare docs/perf/baseline-2026-09.json`
   must PASS (p95 within +10 % per context).
5. **Repeat** for verify → insights → search → reader, one release each.
6. **Retire the single API** only after every context has run on its service for a full release cycle
   with the canary green.

## Roll back
Remove the context from `production.services`, regenerate, and release: the catch-all sends it back
to the single API, which keeps running until step 6.
