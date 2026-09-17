# landing/ — gurbanisoul.com marketing site

A **self-contained static site** for the Gurbani Soul product domain. No build step, no
dependencies, no backend, no scripture data — just HTML/CSS. It is intentionally **separate from
the Knowledge Base** (`frontend/`, `sggs-knowledge-base.vercel.app`) so the consumer brand and the
scholarly KB stay decoupled.

## Pages
- `index.html` — marketing home (trust story, features, "Built by Algorythmos").
- `support/index.html` → served at `/support` — **canonical** Support page (App Store Support URL).
- `privacy/index.html` → served at `/privacy` — **canonical** Privacy Policy (App Store Privacy URL).
- `styles.css`, `favicon.svg`, `vercel.json` (clean URLs + security headers).

The Support/Privacy pages here are the **single source of truth** for the app's policy. The App
Store listing points only at `https://gurbanisoul.com/support` and `/privacy`. Keep these in step
with the app's actual behaviour; do not let a second, divergent copy go live elsewhere.

## Deploy (its own Vercel project — do NOT touch the KB project)
1. New Vercel project from this repo, **Root Directory = `landing/`**, Framework preset = **Other**
   (static; no build command, output = the directory itself).
2. Add the domain in Vercel: `gurbanisoul.com` (+ `www` → redirect to apex).
3. In **Cloudflare** DNS (account "Company-Domains"), add — set **DNS-only (grey cloud)**:
   - `A  @  → 76.76.21.21`
   - `CNAME  www  → cname.vercel-dns.com`
   Confirm the exact target Vercel shows. If you later enable the Cloudflare proxy, set SSL mode to
   **Full (strict)** to avoid redirect loops.
4. Ensure this project is **not behind Vercel Deployment Protection** — `/support` and `/privacy`
   must be publicly reachable for App Store review.

Record the domain→project binding in `docs/process/runbooks/deploy.md` (ADR-0005: dashboard-only
bindings must be written down).

## Not part of the KB pipeline
This directory is outside `frontend/`, so the KB's CI-gated Vercel deploy, the version-consistency
gate, and the scripture proofs do not apply to it. It carries no `db/`, no `/api`, no corpus.
