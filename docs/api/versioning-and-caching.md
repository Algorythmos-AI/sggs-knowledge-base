---
title: "Versioning and caching"
description: "The two API surfaces and their errors, request ids, which responses the browser and the CDN may cache and how ETags make revalidation cheap, the security headers, and X-Service."
sidebar:
  order: 3
verified:
  commit: df4bff43
  date: "2026-09-26"
---
# Versioning and caching

## Two surfaces, one body

Every route is served twice. `/api/*` is the **legacy** surface whose responses are pinned byte for
byte by the golden contract and the iOS app. `/api/v1/*` is the **strict** surface: the same
handlers and the same bodies, but an unknown endpoint is `404` (not `400`) and every error is a
structured envelope:

```json
{ "error": { "code": "not_found", "message": "no such endpoint: /api/v1/nope", "request_id": "…" } }
```

`code` is `not_found`, `invalid_request` (a bad parameter → 400) or `error`. New clients should use
`/api/v1`; the legacy surface stays for the app until it re-vendors.

<!-- sggs:code file="webapp/serve.py" symbol="_handle_v1" -->
Source: [`webapp/serve.py` · `H._handle_v1`](../../webapp/serve.py), read at build time.

## Request ids

Every response carries `X-Request-Id`, and the same id is written to the access log (with the
method, path, status and duration — **never the query string**, so what people search for is not
recorded anywhere). An incoming `X-Request-Id`, or Vercel's `x-vercel-id`, is reused when it is a
plain token of 8–128 safe characters; anything else is replaced and never logged as sent. Quote the
id when reporting a problem and one request can be followed from the edge to the service.

## What may be cached

Only responses that depend on nothing but the immutable database are cacheable — the tuple
`_CACHEABLE` in `serve.py`: `ang`, `shabad`, `lines`, `bani`, `banis`, `word`, `analytics`,
`themes`, `timing`, `forms`, `neighbors`, `related`, `line_concepts`. They are sent with

```http
Cache-Control: public, max-age=300, s-maxage=3600
ETag: "<sha256 of the body, 32 hex>"
```

so a browser keeps them for five minutes, the CDN in front of the API for an hour, and a repeat
request with `If-None-Match` is answered `304 Not Modified` without a body. Everything else —
`meta`, `health`, `random`, `search`, `verify` — is `Cache-Control: no-store`: a search is
answered afresh and a health check is never stale. The rule is the same on both surfaces.

<!-- sggs:code file="webapp/serve.py" symbol="_CACHEABLE" -->
Source: [`webapp/serve.py`](../../webapp/serve.py) — the cacheable set, read at build time.

A dataset change is a new deploy (the pin is baked into the image), and the release runbook purges
the CDN so no cached body outlives the database it came from.

## Headers on every response

| Header | Value | Why |
|---|---|---|
| `X-Content-Type-Options` | `nosniff` | the body is what the type says |
| `X-Frame-Options` | `DENY` | the API is never framed |
| `Referrer-Policy` | `no-referrer` | a request never carries where it came from |
| `Strict-Transport-Security` | `max-age=31536000` | honoured on the hosted API |
| `X-Request-Id` | the request id | one id from the edge to the log |
| `X-Service` | `all`, or the contexts this service runs | which service answered; the gateway's routing is verified by it |

## Limits a client will meet

- `limit` ≤ 200 and `offset` ≤ 1,000,000 on search; `ids` lists read at most 300 ids; a query is
  at most 300 characters; every integer is clamped rather than rejected, except where a value is
  required.
- The server is bounded: a fixed worker pool, a 15-second socket timeout, idle clients dropped.
- A composition id that is a permanent gap (see [the `comp_id` rule](../data/line-record.md)) is
  `404` on both surfaces.
