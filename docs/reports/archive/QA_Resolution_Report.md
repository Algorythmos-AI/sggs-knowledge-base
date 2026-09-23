# QA Resolution Report — Chaos Testing & Autonomous Fix Loop (v1.9.1, 2026-06-11)

10 SME attack agents · 200 adversarial queries from real corpus lines · deterministic top-3 scoring harness (`pipeline/chaos_harness.py`) · three fix rounds · full regression after every round.

## Initial metrics (before fixes)

**73/200 pass (36%)**

| Behavior | Before | After | Behavior | Before | After |
|---|---|---|---|---|---|
| emoji_artifacts | 20/20 | **20/20** | honorific_hallucinator | 6/20 | **20/20** |
| memory_fragmenter | 20/20 | **20/20** | semantic_substitutor | 7/20 | **16/20** |
| sms_shorthand | 14/20 | **20/20** | acoustic_dyslexic | 2/20 | **10/20** |
| bilingual_blender | 0/20 | **18/20** | keyboard_smasher (partial) | 0/10 | **9/10** |
| grammar_morpher | 3/20 | **17/20** | keyboard_smasher (spaceless) | 0/10 | **6/10** |
| | | | voice_to_text | 1/20 | **3/20** |

## Final metrics

**159/200 pass (80%)** — +86 queries recovered. Core regression suite: **13/13, zero regressions** (couplet, bhakti-query, andhule, all seeker classes, Gurmukhi/first-letter/verify/health).

## Root-cause analysis → patches applied

1. **Mixed-script queries died at routing** (blender 0/20): a single Gurmukhi token routed the whole query to the Gurmukhi tier. → `serve.py: mixed_search()` — per-token AND groups: Gurmukhi→`text:` column, Latin→variants/lexicon/fold; plus a latin-only retry that drops Gurmukhi tokens.
2. **Honorific injections poisoned the AND** (6/20): ji/sahib/guru/dev are real corpus words, so they matched wrong lines or nothing. → early honorific-drop retry (15-term list) re-running the full chain; fires before the early-returning tiers (placement mattered: end-of-chain version was bypassed by passage/blob returns).
3. **English morphology** (3/20): boling/jogis. → suffix-strip retry (`-ing/-ed/-es/-er/-s`) in the token waterfall, base re-checked against variants and canon_tokens.
4. **Acoustic voicing swaps** (2/20): t↔d, p↔b beyond the existing k/g, b/v. → fold extended `t→d, p→v` on BOTH index and query side; `translit_norm`, `norm_blob`, FTS and `fts_shabad` re-migrated.
5. **Spaceless keyboard smashes had no token boundaries** (0/20): → new `norm_blob` column (despaced fold per line) + `blob_search()` desperate tier: 3 sliding-window LIKE prefilters → difflib re-rank.
6. **Synonym substitutions** (7/20): → lexicon entries (rabb/rab→ਹਰਿ/ਰਾਮ, dard→ਦੁਖ, dil→ਮਨ, khushi→ਸੁਖ, satsang→ਸਾਧਸੰਗ, ocean→ਸਾਗਰ, name→ਨਾਮ).
7. **Regression found by the loop itself**: the mushier voicing fold let the per-line fold tier and BM25 outrank the true passage match (couplet fell to rank 20 of 25 candidates). → tier order fixed (passage before fold-full) + passage re-ranking: in-order fold-sequence regex (a real quote keeps word order) then **prefix-density scoring** (query `ha ha` prefix-matches the shabad's ਹਾਂ refrain ×14) then BM25.

## Honest known limits (by design, documented not hidden)

- **voice_to_text 3/20**: English-homophone dictation (`such a armor such a party shoe`) reverses through a *different language's* phonology; reliable recovery needs an English-pronunciation→Indic phonetic model, not string rules. Out of scope for the zero-dependency engine.
- **acoustic_dyslexic 10/20**: the remaining failures are r↔l and n↔m swaps — folding those would merge genuinely distinct Gurmukhi roots (ਨਾਮ/ਮਾਨ) and poison precision corpus-wide. Deliberately rejected.
- **smasher-spaceless 6/10**: blobs that corrupt >40% of the skeleton fall below the 0.55 similarity gate; loosening it floods false positives.

## Reproduce

```bash
cd ~/ppt-universe/SGGS-KnowledgeBase
python3 pipeline/chaos_harness.py "path/to/attacks_*.jsonl" /tmp/chaos_results.jsonl   # score any attack set
curl -s 'http://localhost:7777/api/search?q=jeevat+jo+mara+ha+duttar+so+tara+ha&limit=4' | python3 -m json.tool
```
Attack sets + per-query results: `validation/chaos/`.
