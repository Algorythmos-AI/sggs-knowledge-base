---
title: "Exercises"
description: "Six hands-on exercises, each runnable with make targets alone, with the output to expect and a self-check: trace a search, add a route, bump a pin, write an ADR, fix a poster, add a widget."
sidebar:
  order: 0
---
# Exercises

Each exercise is short, uses only `make` targets and the tools the repository already has, says
what output to expect, and ends with a self-check. None touches the scripture; several show you
the gate that would stop you if you tried. Do them from a fresh branch off `integration` and
throw the branch away afterwards unless a path tells you to open a pull request.

| # | Exercise | You learn | Time |
|---|---|---|---|
| 01 | [Trace a search](01-trace-a-search.md) | which tier answered, and why, for three real queries | 30 min |
| 02 | [Add a route and watch the gates](02-add-a-route.md) | the dispatcher, the OpenAPI declarations, the generated pages, and the tests that notice | 60 min |
| 03 | [Bump a pin in a scratch branch](03-bump-a-pin.md) | what a dataset bump changes, what the integrity gate proves, and why you revert instead of merging | 30 min |
| 04 | [Write an ADR](04-write-an-adr.md) | how a decision is recorded so it survives its author | 30 min |
| 05 | [Fix a poster](05-fix-a-poster.md) | the poster kit, the drift check, and the walkthrough | 30 min |
| 06 | [Add a widget](06-add-a-widget.md) | the widget schema, the fallback rule, the e2e test, and the budget | 60 min |

Before the first one: [run it locally](../onboarding/run-it-locally.md) once, so `make doctor`
is green and `db/sggs.sqlite` is installed.
