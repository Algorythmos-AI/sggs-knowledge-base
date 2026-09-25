---
title: "Contract and OpenAPI"
description: "contract/openapi.json is generated from real responses and checked on every pull request; the golden vectors beside it pin what every route returns. How both are made, enforced and changed."
sidebar:
  order: 2
verified:
  commit: 7a343c62
  date: "2026-09-25"
---
# Contract and OpenAPI

The API's shape is not written by hand. `tools/gen_openapi.py` declares each route once (tag,
summary, parameters, limits, sample requests) and then **infers the response schemas from real
responses** of the in-process API on the pinned database, so the spec cannot describe a field the
server does not return. The result, `contract/openapi.json`, drives the [API reference](reference/)
on this site and the [routes page](routes.md).

## Two tables that must agree

The dispatcher (`webapp/serve.py:ROUTES`) says which handler and which bounded context serve a
route; the generator (`tools/gen_openapi.py:ROUTES`) says what a route takes and means. A unit
test fails if a route is on one side and not the other, and `tools/gen_route_table.py --check`
fails the docs build if the [routes page](routes.md) was not regenerated after either changed.

<!-- sggs:code file="tools/gen_openapi.py" lines="40-60" -->
Source: [`tools/gen_openapi.py`](../../tools/gen_openapi.py) — the head of the declarations table, read at build time.

## How the spec is checked

```bash
python3 tools/gen_openapi.py            # regenerate contract/openapi.json (needs db/sggs.sqlite)
python3 tools/gen_openapi.py --check    # what CI runs: regenerate in memory, exit 1 on any difference
```

`web-ci · python` runs the check on every pull request, and asserts the spec covers every
dispatcher route. Response schemas are inferred with types merged across the sample requests, so a
field that is sometimes `null` is typed as nullable rather than guessed.

## The golden vectors beside it

`contract/` also holds the golden vectors — recorded outputs of the real functions — and
`_meta.json` with their counts and the `db_sha256` they were built against. They pin *values*,
where the OpenAPI spec pins *shape*:

| File | What it fixes |
|---|---|
| `openapi.json` | every route's parameters and response schema |
| `golden_search.ndjson`, `golden_verify.ndjson` | what search and verification return for recorded inputs |
| `golden_reader.ndjson`, `golden_timing.ndjson`, `golden_banis.ndjson`, `golden_analytics.ndjson` | the reader, knowledge, Nitnem and insight projections |
| `golden_roman_norm.ndjson`, `golden_difflib.ndjson` | the two pure functions the iOS port must reproduce byte for byte |

`make contract` regenerates the vectors and fails on drift; `tools/contract_http.py` replays them
over HTTP against a running API, which every deploy does before promoting. Details on
[Harnesses and golden vectors](../search/harnesses-and-golden-vectors.md).

## The API contract version

`API_CONTRACT_VERSION` in `tools/gen_openapi.py` is the spec's own version, bumped only for an API
change; a breaking change gets a new major and a new path prefix. The **product** version
(`APP_VERSION`, shown by `/api/meta` and `/api/health`) is a separate number shared by web, API and
app — see [One version number](../adr/0004-unified-semver.md).

## Changing the API honestly

1. Add or change the handler in the bounded context module and its entry in `serve.py:ROUTES`.
2. Declare it in `tools/gen_openapi.py:ROUTES` with parameters, limits and at least one sample
   request; regenerate the spec.
3. Regenerate the golden vectors (`make contract`) and review the diff line by line.
4. Regenerate the [routes page](routes.md) (`python3 tools/gen_route_table.py`) and, if the route
   belongs to a context that runs as its own function on staging, the gateway
   (`tools/gen_gateway.py`).
5. Ship through the normal pipeline; the deploy replays the contract through the gateway before
   promoting. The app re-vendors the contract at the next release tag.
