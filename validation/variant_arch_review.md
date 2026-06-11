# Variant Index Architecture Review
**Reviewer:** Principal Backend Engineer (adversarial)
**Date:** 2026-06-11
**DB:** /tmp/sggs.db — 60,658 lines, 24,673 distinct translit tokens

---

## 1. Token Alignment: zip(text.split(), translit.split())

**Verdict: BROKEN for ੴ; negligible otherwise; but still a structural correctness gap.**

Full-corpus scan (60,658 lines):

| Category | Count | Rate |
|---|---|---|
| ੴ (Ik Onkar) mismatches | 568 | 0.94% |
| Other mismatches | 2 | 0.003% |
| Clean alignment | 60,088 | 99.06% |

The ੴ glyph is one Unicode codepoint but its canonical translit is **two tokens** (`ik oankaar`). Zip alignment silently produces wrong (gurmukhi_token → translit_token) pairs for every line containing ੴ — 568 lines, or roughly the entire Mangalacharan/mool-mantar corpus that opens every raag. This is not just a 1% error rate; these are the _most searched_ lines.

The two non-ੴ mismatches (lines 30069, 38452) are caused by bare vowel diacritics rendered as standalone codepoints (`ੋ`, `ੁਂ`) that have no translit equivalent — the translit is blank/whitespace, causing an off-by-one shift that poisons every subsequent token pair on that line.

**Fix required:** Before zipping, apply a pre-alignment step: map `ੴ` → `ik oankaar` in the text token list (or split translit differently). Also detect and skip lines where a text token has no translit counterpart (bare vowel diacritics).

---

## 2. Collision Policy: variant maps to multiple gurmukhi words

**Verdict: Union-with-freq-ranking is right, but the design leaves it unspecified — this is a critical omission.**

Measured collision rate in the canonical translit space:

- **3,384 of 24,675 translit tokens (13.7%)** already map to more than one distinct gurmukhi word.
- Top offenders: `taan` (7 gurmukhi words), `daan` (7), `jaan` (7), `man` (6), `naam` (6), `sat` (6).
- The `sat`/`naam`/`oankaar` cluster is **artifact of the ੴ alignment bug** (see §1): the mool-mantar tokens bleed across word boundaries.

If a variant resolves to multiple canonical translit tokens, the design says nothing. The implied behavior is to return all — but then multi-token AND-queries become a cross-product of candidate sets, which can explode. For `man naam` with each token resolving to 6 candidates, you get 36 FTS queries or a 36-clause OR-within-AND expression.

**Recommendation:** Store the (variant → set of translit terms) mapping explicitly. At query time, resolve each query token to its top-1 or top-3 by `freq*score`, not all. Cap resolution fan-out at 3 per query token; document the cutoff. Union is correct for search _recall_ but must be bounded for _query performance_.

---

## 3. Multi-Token Queries: AND-combination mechanics

**Verified against real DB:**

```sql
-- Works: two translit terms, single-column AND
SELECT COUNT(*) FROM fts WHERE fts MATCH 'translit:man AND translit:naam';
-- Returns: 522

-- Wrong intent: cross-column AND produces different (inflated) result set
SELECT COUNT(*) FROM fts WHERE translit MATCH 'man' AND text MATCH 'some_gurmukhi';
-- Returns 1402 — not what AND-search intends
```

The safe, correct mechanic is: **resolve all query tokens to translit terms first, then issue a single-column AND query** on the `translit` column using FTS5 `fts MATCH 'translit:term1 AND translit:term2'`. Do NOT mix resolved-via-variants tokens in the `translit` column with unresolved tokens in `text` in the same MATCH — the row counts above show this produces semantically incorrect results (matching rows where `man` is in translit but the text match is from a different token on the same row).

**Concrete mechanics to specify:**

1. Tokenize query → `[q1, q2, ...]`.
2. For each `qi`: lookup variants table; if found, take top-k (≤3) resolved translit terms; otherwise use `qi` literally.
3. Expand multi-resolution tokens as OR groups: `(term_a OR term_b)`.
4. Compose final FTS expression: `fts MATCH 'translit:(term1a OR term1b) AND translit:(term2a)'`.
5. Execute once against FTS. Do not execute per-candidate-combination.

This is missing from the spec entirely and will be re-implemented incorrectly by whoever writes the query layer.

---

## 4. Veto Edge: variant == canonical translit of another word

**Verdict: Keep-with-lower-score is WRONG. Purge is correct.**

Measured with two high-frequency rules:

| Rule | Tokens with pattern | Variants colliding with existing canonical |
|---|---|---|
| `aa → a` | 13,261 | 1,612 (12.2%) |
| `ii/ee → i` | 6,236 | 828 (13.3%) |
| `v → w` | 3,359 | 0 (0.0%) |

12-13% collision rate on the most common vowel-fold rules means that at BFS depth 2 roughly **1 in 8 generated variants is already a real Gurbani word with its own meaning**. For example, `prasaad` (grace) folds to `prasad` which is also a canonical translit for a different inflection. Keeping these with lower score creates a _shadow lookup_ where a user searching for `prasaad` could get `prasad`-canonical results ranked below the real ones — but the real ones would _also_ appear through the roman-exact tier that runs before. Net effect: duplicate results at different ranks, user confusion.

The keep-with-lower-score policy also undermines the English-word veto: if `jan` (a real Gurbani word, freq=high) is generated as a variant of `jaan`, and `jan` is also on the common-English shortlist, the two veto rules conflict — which wins? The spec is silent.

**Recommendation:** Purge any generated variant that exactly matches any canonical translit token (case-insensitive). The roman-exact and translit-FTS tiers already handle canonical terms. Variants are strictly for _non-canonical spellings_; if a spelling is canonical for anyone, it does not belong in the variants table.

---

## 5. Tier Placement: before vs. after english-FTS

**Verdict: Variants tier MUST come before english-FTS. Placing it after is a semantic disaster.**

**Failure case for placing variants AFTER english-FTS:**

Query: `man` (Punjabi: ਮਨ = mind/heart).

- english-FTS for `man` returns lines like "Man's life is diminishing..." and "The blind man has forgotten the Name..." — these are English-translation hits for the English word "man", not for ਮਨ.
- If variants tier comes after, it never fires because english-FTS returns results first.
- 69 canonical Gurbani translit tokens (confirmed measurement) overlap common English words. All would be permanently rerouted to english-FTS.

**Failure case for placing variants BEFORE seeker-lexicon (too early):**

Query: `vahiguru` — variants tier fires first and resolves to `wahiguru` (v→w rule), issuing a translit-FTS search. The seeker-lexicon, which maps `vahiguru` to a curated 4-term gurmukhi set (ਵਾਹਿਗੁਰੂ, ਵਾਹਗੁਰੂ, ਵਾਹੁ, ਵਾਹਿ), never runs. The curated semantic expansion is bypassed for an inferior phonetic-only match.

**Confirmed correct placement:** after seeker-lexicon, before english-FTS:

`gurmukhi-FTS → roman-exact → seeker-lexicon → variants → english-FTS → phonetic-fold → theme`

---

## 6. Operations: Rebuild, Idempotency, Golden Tests

### Rebuild Time Estimate

- 60,658 lines × avg 6.5 tokens = ~394,000 token pairs to process.
- 24,673 distinct translit tokens × ≤15 variants = up to 370,000 variant rows.
- BFS depth-2 with 15 rules: simulated pathological tokens hit **16 variants** (e.g., `dhiaanaaiia` with multiple applicable rules). The "≤15" cap is NOT guaranteed by BFS depth 2 alone. Explicit truncation is required.
- Pure Python: ~5–10 seconds. With batched SQLite inserts: ~20–30 seconds total.
- Idempotency: use `DROP TABLE IF EXISTS variants; CREATE TABLE variants(...);` before rebuild — not `INSERT OR REPLACE`, since no PK is defined in the schema spec. Alternatively, build into a staging table and swap.

### Required Golden Tests (≥6)

1. **Alignment smoke test:** Assert that line 1 (mool-mantar) produces exactly 15 (gurmukhi_token, translit_token) pairs, with `ੴ` correctly pre-mapped before zipping — verifies the ੴ alignment fix.

2. **Variant count cap:** Assert that no single canonical translit token produces > 15 variants in the built table (catches BFS explosion for long tokens).

3. **Purge rule — canonical collision:** Assert that `prasad` (generated by `aa→a` from `prasaad`) does NOT appear as a variant row, since `prasad` IS a canonical translit token with freq > 0.

4. **Purge rule — English veto + canonical conflict:** Assert that `jan` does NOT appear as a generated variant entry (it is both a common English name AND a canonical Gurbani translit — both veto rules apply; confirms rule ordering is unambiguous).

5. **Query resolution — multi-token AND:** Run `satgur prasad` through the tier chain; assert the composed FTS expression is `fts MATCH 'translit:(satigur OR ...) AND translit:(prasaad OR ...)'` — a single query, not two separate queries merged in Python.

6. **Tier bypass — English-word query:** Query `man`; assert that the variants/translit tier fires and returns results, and that english-FTS is NOT consulted (tier-level counter or log assertion: english-FTS call count = 0 for this query).

7. **ੴ lines not poisoned (regression):** Assert that zero misaligned (gurmukhi, translit) pairs involving `ੴ` exist in the build input after the pre-alignment fix is applied (568 must go to 0).

8. **Rebuild idempotency:** Run build script twice on same DB; assert `SELECT COUNT(*) FROM variants` is identical both runs and `SELECT variant FROM variants ORDER BY variant` produces identical checksums.

---

## Summary of Defects by Severity

| # | Issue | Severity |
|---|---|---|
| 1 | ੴ alignment bug: 568 lines (most-searched corpus entries) produce wrong gurmukhi↔translit pairs | **BLOCKER** |
| 2 | Collision policy for multi-gurmukhi variants unspecified; unbounded resolution fan-out at query time | **BLOCKER** |
| 3 | Multi-token AND mechanics not specified; cross-column MATCH produces inflated/wrong results | **BLOCKER** |
| 4 | Keep-with-lower-score on canonical collisions: duplicates results + veto-rule conflict for `jan`-like tokens | HIGH |
| 5 | BFS depth-2 does not guarantee ≤15 variants; 16 observed on real pathological translit token | MEDIUM |
| 6 | English-word veto applies to generated variants but not query input tokens — `man`/`sun`/`gun` gap at tier boundary | MEDIUM |
| 7 | 14,410 of 29,244 gurmukhi words (49%) are hapax legomena; `freq*score` ranking is unreliable for half the vocabulary | LOW |
