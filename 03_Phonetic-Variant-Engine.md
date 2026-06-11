# 03 — Phonetic Variant Engine (v1.7.0)

Sam's two-agent design (Worker = lexical permutation, Supervisor = adversarial English-veto QA), reviewed by two SME agents and upgraded to production form. Full artifacts: `validation/variant_rules_spec.md` (linguist, 15 rules) and `validation/variant_arch_review.md` (architecture review, GO-WITH-CHANGES ×6 — all applied).

## 1. The one big upgrade: rules-as-code, LLM-as-engineer

The Worker's linguistic rules (glides, aspirates, vowel folds, nasalization, gemination, vowel drops) are *mechanical* — so generation for all 29,241 words is **deterministic code** (`pipeline/build_variants.py`, 0.7s, reproducible, auditable, rebuilt on every corpus build). LLM agents are used where judgment lives:

| Sam's agent | Repositioned as | Already executed |
|---|---|---|
| Worker (per-token generation) | **Rule designer**: produced the weighted 15-rule table with empirical gates (e.g. `ai→e` length-gated because mai→me/hai→he are English collisions; `j→y` rejected — would poison ਜਨ/ਜੋਤਿ/ਜੋ) | ✔ linguist agent |
| Supervisor (per-batch veto QA) | **Adversarial design reviewer** + battery QA: 6 blocking changes (ੴ token alignment; ≤3 fan-out cap; single-FTS-expression AND mechanics; purge-not-downweight canonical collisions; hard ≤15 truncation; tier-placement invariant) | ✔ review agent + 73-query battery |

Their original prompt texts are preserved below (§4) for when LLM generation IS the right tool: enriching `common_typo` variants for the top ~500 highest-frequency words — typos are not rule-derivable.

## 2. Architecture (as built)

- **Build** (`build_variants.py`): per (gurmukhi word → canonical translit) pair — alignment by zipping line tokens with the ੴ two-token fix (2 misaligned lines skipped corpus-wide) — BFS **depth 3** over the 15 weighted rules (wahiguru = v→w + aa→a + oo→u), dedupe, score = weight product, truncate to ≤15.
- **Veto** (the Supervisor's "English Dictionary Veto", made deterministic): a variant is purged if it appears **in lowercase** in our own 58k-line English layer (≥2×). Key insight: SSK reverentially capitalizes Gurbani loanwords (Kirtan, Amrit, Naam) — so lowercase-occurrence separates *real English* (mercy, rust, fun) from *romanized Gurbani that must stay searchable*. Also purged: canonical-translit collisions (6,232 — exact tier owns those), <2 chars, non-alnum. Result: **59,227 variants kept, 372 English-vetoed**.
- **Query tier** (`serve.py:variant_search`): tier order is a hard invariant — exact roman → seeker-lexicon → **variants** → English-FTS → phonetic-fold → theme. Each token resolves to ≤3 translits by `freq·score`; executed as ONE FTS expression `translit:("a" OR "b") AND translit:("c")`; BM25-ranked.
- **Provenance**: `meta.variants` count; rebuilt by the standard pipeline; golden battery covers gyan/wahiguru/kirtan/amrit/hukum/kartaa/nirbhau/darsan/prabhu + all prior classes (22/22).

## 3. Guardrails kept from Sam's spec
Max 15 variants ✔ (build-time truncation) · lowercase alnum only ✔ · len ≥ 2 ✔ · no semantic output ✔ · **no LLM-generated SQL anywhere** ✔ (agents emit JSON/markdown; only reviewed code touches the DB).

## 4. Original agent prompts (upgraded, for the future top-500 typo-enrichment pass)
**Worker — Lexical Permutation Engine**: as Sam specified, with two amendments: (1) scope = `common_typo` class only (rule-derivable classes are code); (2) output schema gains `"confidence": 0-1` per variant and the run is keyed by `rules_version` so enrichments are reproducible.
**Supervisor — Adversarial QA Gatekeeper**: as specified (English veto, cleanliness, length), with two amendments: (1) the English veto is checked against the deterministic lowercase-vocab list FIRST (LLM only adjudicates the remainder); (2) verdicts append to an audit JSONL (`validation/variant_qa_log.jsonl`), never write to the DB.
