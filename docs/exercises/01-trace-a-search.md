---
title: "Exercise 01: trace a search"
description: "Run three real queries through the search waterfall — one the exact tier answers, one the lexicon answers, one that falls to the fold — and read the reported mode against the code."
sidebar:
  order: 1
---
# Exercise 01: trace a search

**Goal.** Predict which tier answers a query, run it, and confirm from the `mode` the API reports.
**Needs.** A local server (`python3 webapp/serve.py`) or the production API through the wiki's
[simulator](../architecture/search-waterfall.md#try-it). 30 minutes.

## 1. Predict

Read [modes and tiers](../search/modes-and-tiers.md). For each query below, write down the tier
you expect and the `mode` string it would report:

| Query | Your prediction |
|---|---|
| `sat nam` | |
| `waheguru` | |
| `zzqxv plok` | |

## 2. Run

```bash
curl -s 'http://127.0.0.1:7777/api/search?q=sat%20nam&limit=3' | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["mode"], len(d["results"]))'
curl -s 'http://127.0.0.1:7777/api/search?q=waheguru&limit=3' | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["mode"], len(d["results"]))'
curl -s 'http://127.0.0.1:7777/api/search?q=zzqxv%20plok&limit=3' | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["mode"], len(d["results"]))'
```

Expected output (the second line's term in brackets may differ by dataset):

```text
variant-match 3
seeker-lexicon (vaahiguroo) 3
roman-spelling-tolerant 0
```

## 3. Read the code

Open `webapp/sggs/search.py` and find `do_search`. For each query, find the line that set the
`mode` you saw. Then answer:

- Why did `sat nam` skip the transliteration tier? (Hint: what does the `translit` column hold for
  the line whose transliteration is `sat naam`?)
- Why is the last query's mode a *fold* tier with zero results, rather than `NOT_FOUND`?

## Self-check

<!-- sggs:quiz -->
```quiz
Q: A query with no results reports a mode. Which one?
- The last tier the waterfall reached ✓ — the mode names the tier that answered, or the last one tried; nothing is guessed
- NOT_FOUND — that is a verification verdict, not a search mode
- An empty string — the response always carries a mode
Q: You change a bm25 weight to make one query rank better. What must you run before opening a pull request?
- The harnesses and make contract ✓ — a weight shifts ranking corpus-wide, and the golden vectors will show it
- Only the unit tests — they do not measure recall across the corpus
- Nothing; weights are configuration — they are behaviour, pinned by the contract
```
