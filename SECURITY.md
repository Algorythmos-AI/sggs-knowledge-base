# Security Policy

## Reporting a vulnerability
Email **support@gurbanisoul.com** with the details and a proof of concept. Please do
not open a public issue for security problems. We aim to acknowledge within a few
days. This repository is private; the app serves a read-only, offline corpus and
holds no user accounts or personal data.

## Supported versions
The latest `main` release (see `MANIFEST.json` / `/api/health`) is supported.
Older tags are historical.

## Handled classes (already mitigated — see CLAUDE.md "Security invariants")
- SQL: parameterized everywhere; FTS column allowlist + `_fts_clean` strips `"`/`*`.
- Path traversal: `_resolve_static` realpath-jails every static request.
- The API is opened read-only (`mode=ro&immutable=1&query_only`); the app never writes.
- Responses carry `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`,
  `Referrer-Policy: no-referrer`; 500s return a generic body (no schema leak).
