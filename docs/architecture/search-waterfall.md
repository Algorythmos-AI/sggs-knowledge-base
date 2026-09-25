---
title: "Search Waterfall"
description: "The order in which /api/search tries its tiers, from exact full-text matches to the skeleton fallback, and how results are ranked."
sidebar:
  order: 2
---
# Search Waterfall

`/api/search?q=&mode=` runs a deliberate **waterfall**: cheap exact matches first,
progressively fuzzier tiers after, BM25-ranked with weighted columns. Do not
reorder tiers or change weights without re-running the harnesses — small changes
shift ranking corpus-wide.

```mermaid
flowchart TB
    accTitle: The search waterfall
    accDescr: The order in which /api/search tries its tiers, from exact full-text matches to the skeleton fallback.
    q[query] --> mixed{Gurmukhi + Latin?}
    mixed -->|yes| m[mixed_search]
    mixed -->|no| gm{Gurmukhi?}
    gm -->|yes| fts[FTS exact → skeleton LIKE]
    gm -->|no| roman[concept → theme → first-letters → translit FTS]
    m --> lex[lexicon_search]
    fts --> lex
    roman --> lex
    lex --> var[variant_search]
    var --> en[search_en English FTS]
    en --> hon[honorific-drop retry]
    hon --> pass[passage_search cross-line quotes]
    pass --> fold[roman-spelling-tolerant translit_norm]
    fold --> blob[skeleton blob / spaceless]
    blob --> theme[single-token theme]
    theme --> out[BM25-ranked results + related themes]
```

## The Roman fold — the highest-risk invariant
`roman_norm` folds spelling variants (`waheguru`, `vaahiguroo` → `vhgr`). It exists
in **three** places that must stay byte-identical:
- `webapp/romannorm.py` (query time; re-exported by `serve.py`, imported by `verify.py`),
- `pipeline/sggs_pipeline.py:roman_norm` in `Algorythmos-AI/sggs-data` (built the `lines.translit_norm` column),
- `ios/Packages/GurbaniSearchKit/Sources/GurbaniSearchKit/RomanNorm.swift` in `Algorythmos-AI/gurbani-soul-ios` (the port; held to the other two by the vendored `contract/golden_roman_norm.ndjson`).

If the query-time fold ever diverges from the indexed fold, search silently breaks.
`contract/golden_roman_norm.ndjson` (24,719 vectors) pins all three.

## Verifying a search change
```bash
python3 tools/roundtrip_harness.py
python3 tools/casual_quote_harness.py
python3 tools/chaos_harness.py "qa/chaos/attacks_*.jsonl" qa/results/chaos.jsonl   # needs a running server
make contract                          # golden vectors must not drift unexpectedly
```
