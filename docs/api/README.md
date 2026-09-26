---
title: "The JSON API"
description: "The read-only JSON API over the verbatim corpus: what it promises, its 26 routes in five bounded contexts, the two surfaces (/api and /api/v1), caching, and a console to try any route live."
sidebar:
  order: 0
verified:
  commit: 7a343c62
  date: "2026-09-25"
---
# The JSON API

A read-only JSON API over the verbatim corpus, served by a Python standard-library server
(`webapp/serve.py`) from a database opened read-only and immutable. Every scripture line comes back
exactly as printed with its [[Ang]]; English is a separate, labelled layer; nothing is ever written.

| Page | What you learn |
|---|---|
| [API routes](routes.md) | every route, its bounded context, parameters and cache policy — **generated from the code** |
| [API reference](reference/) | the full reference with response schemas, generated from `contract/openapi.json` |
| [Contract and OpenAPI](contract-and-openapi.md) | how the spec and the golden vectors are produced from real responses and enforced |
| [Versioning and caching](versioning-and-caching.md) | `/api` vs `/api/v1`, errors, request ids, caching and ETags, the `X-Service` header |

## Try any route

<!-- sggs:api-try route="/api/ang/{n}" -->
On the rendered wiki this is a console: pick a route, fill in its parameters (the form comes from
the OpenAPI spec), send the request to the live API and read the response with its headers, or copy
it as a `curl` command. On GitHub, the routes are listed on [API routes](routes.md).

## What every response promises

- **Verbatim text.** `gurmukhi` is the line as printed, dandas and markers included; cite it as
  *Sri Guru Granth Sahib Ji · Ang N* (`ang` is on every line).
- **Labelled layers.** `translit` is a reading aid; `en` is Dr. Sant Singh Khalsa's translation
  via ShabadOS, attached to a line and never blended into the [[Gurmukhi]].
- **Read-only, bounded.** Every integer parameter is clamped (`_int()`); `limit` and `offset`
  have ceilings; a claim or a query has a maximum length. There is no write route.
- **The same under `/api/v1`.** Every path is also served under `/api/v1/…` with the same body and
  strict error semantics.
- **Security headers on every response**, a request id you can quote, and a header naming the
  service that answered — see [Versioning and caching](versioning-and-caching.md).

## Where a route lives

The routes are owned by five [bounded contexts](../architecture/bounded-contexts-and-gateway.md)
— `reader`, `search`, `verify`, `insights`, `knowledge` — each of which opens only the tables it
needs. On staging each context runs as its own function behind the gateway; production (v1.3.10)
serves them all from one function, `all`, and routes them the same way as staging from the release
after 1.3.10. A client never sees the difference except in `X-Service`.
