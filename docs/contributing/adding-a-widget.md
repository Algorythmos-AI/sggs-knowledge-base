---
title: "Adding a widget"
description: "The contract for anything interactive on the wiki: a schema entry, a small custom element built with DOM APIs, a fallback sentence, a mocked e2e test, the budget, and how scripture may appear."
sidebar:
  order: 4
---
# Adding a widget

A widget is a vanilla custom element (`<sggs-…>`) inserted from Markdown by a comment,
`<!-- sggs:name attr="value" -->`, so the page stays clean on GitHub. Exercise 06 walks the
process; this page is the contract.

## The contract

| | |
|---|---|
| **Schema** | an entry in `docs-site/plugins/widgets.schema.json`: purpose and attributes; unknown names or attributes fail the build |
| **Element** | `docs-site/src/widgets/<name>.ts`, registered in `src/widgets/index.ts`; text is built with `el()`/`textContent`, never `innerHTML` of API data |
| **Fallback** | a sentence within three lines after the comment; it is what GitHub readers and readers without the API see |
| **API** | same-origin `/api/…` through `api()` in `src/widgets/api.ts`, which times out and returns `null`; the widget then shows its fallback text |
| **Scripture** | only from the API response, verbatim, with `lang="pa"` and the Ang — never a string in the source, never the saroop painter |
| **Test** | an e2e test with `mockApi()` fixtures (verbatim API captures) — the suite never reaches production |
| **Accessibility** | keyboard-operable, `role`/`aria-live` where state changes, axe clean on its page |
| **Budget** | the page's JavaScript stays under 60 KB gzipped (`npm run check:budget`); a build-time widget (like the code excerpt or the repo map) costs nothing |

## Build-time widgets

Some "widgets" need no JavaScript: a remark plugin replaces the element with HTML at build time
(the code excerpt, the repository map, the ADR timeline, the release list). Prefer this when the
content is static; the schema entry still declares it, and `remark-widgets` still checks the
attributes.

## Lighting a poster step

A widget that explains a process can light the step on a poster on the same page:
`lightStep('05-search-waterfall', 'step-07')` in `src/widgets/shared.ts` calls the walkthrough's
`goTo`. The search simulator and the verify playground do this.
