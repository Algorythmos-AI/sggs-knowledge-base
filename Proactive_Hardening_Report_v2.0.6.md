# Proactive Hardening Report — v2.0.6

**Date:** 2026-06-13 · **Scope:** query-side only — `db/sggs.sqlite` is **byte-identical** (sha256 `f0a64f78…`, verified before/after, never staged). No `ALTER TABLE`, no re-migration.

After the reactive `jamuna ka kul` fix (v2.0.5), this pass goes **proactive**: a 4-agent read-only QA fleet swept the corpus for latent phonetic, lexical, and structural loopholes *before* users hit them. Findings were ground-truthed, triaged into a no-break plan, and shipped against a "do no harm" gate (chaos ≥ 175/200, exact round-trip ≥ 99.3%, 0 canonical regressions — revert anything that slips).

---

## 1. The fleet

| Agent | Mandate | Method |
|---|---|---|
| A — Lexicon Aggressor | modern casual spellings of high-frequency words that fail to resolve | top-400 `word_freq` + closed-class probing, in-process `do_search` |
| B — Phonetic Stress-Tester | residual fold-gap clusters | `casual_quote_harness` 5k + `roundtrip --perturb` 6k, miss clustering |
| C — Boundary Auditor | hukam/passage fragment & over-merge | exhaustive `hukam_package` sweep over all 5,380 comps |
| D — Adversarial Seeker | real-seeker queries returning junk/empty | ~130 named-figure / famous-line / English / mantra queries |

**A discipline note up front:** the agents are strong but not infallible, and every proposed `casual → canonical` mapping was re-verified against the DB before use. This caught real errors: Agent A "found" broken `waaste`/`vaste` lexicon entries that **do not exist**; several proposed targets are **dead** (`jio`, `rehraas`, `japu`, `japajee` = 0 corpus lines). None of those were shipped. This is the same `kooli`-doesn't-exist lesson from v2.0.5 — ground-truth first, always.

---

## 2. What shipped (v2.0.6)

### A. Modern pronoun / particle / compound / named-figure lexicon layer (12 entries)
All canon-verified, all with **0 hijack risk** (the casual form has 0 corpus lines, so it can never shadow a real word), all additive OR-alternatives (the existing fold stays in every token's group).

| Casual form | Was | Now → | Canonical (lines) |
|---|---|---|---|
| `mein` / `me` | wrong (mohan / Persian lines) | ਮਹਿ / ਵਿਚਿ "in" | mah 1112 / vich 326 |
| `ye` | empty | ਇਹੁ / ਏਹ "this" | ih 803 / eh 289 |
| `main` | wrong (ਮੈਣ wax) | ਮੈ / ਹਉ "I" | mai 719 / hau 702 |
| `inka` | empty | ਤਿਨ "those/their" | tin 895 |
| `jivan` | wrong | ਜੀਵਨੁ "life" | jeevan 167 |
| `mua` | weak-dropped | ਮੂਆ "died" | mooaa 38 |
| `keertan` | empty | ਕੀਰਤਨ | keeratan 127 |
| `raidas` | **0 results** | Bhagat ਰਵਿਦਾਸ | ravidaas 63 |
| `waheguruji` | 0 results | ਵਾਹਿਗੁਰੂ | vaahiguroo |
| `sachkhand` | 0 results | ਸਚ ਖੰਡ (Ang 8) | sach + khand |
| `kirtan sohila` | — | ਸੋਹਿਲਾ (bani) | sohilaa 21 |

The pronoun/particle cluster (का/के/की from v2.0.5 + में/मैं/ये/इनका now) is a **closed function-word class** — these few words recur on tens of thousands of lines, so this is systematic coverage, not whack-a-mole.

### B. Boundary fix — DEFECT-1 (the one real Hukamnama gap)
The complete-unit window was `±9` comps. Exactly **one** Vaar in the corpus — Maajh, comps 399–409 at Ang 141 — has a **10-comp Salok run** before its concluding Pauri, so a Hukamnama seeded at the head of that run (`seed=399`) returned a lone 4-line salok instead of the full 93-line unit. Widened the candidate window to `±15`. Proven surgically safe by a full before/after diff across all 4,703 body comps: **exactly 2 comps change** (399 and 409), both fragment → complete-unit corrections; every other unit is byte-identical. No over-merge, no runaway.

---

## 3. What was found but deliberately NOT shipped (with reasons)

Honesty matters more than a longer changelog. These are real findings I chose to defer because the risk outweighed the benefit under "don't break anything."

1. **`jiu` → `jeeu` (Agent B, rated high, 1,435-line exposure).** `jeeu` (ਜੀਉ soul/honorific) and `jiu` (ਜਿਉ "as/like", 562 lines) are **different common words** that both fold to a weak `j`. Mapping one to the other is a false-friend that risks mis-ranking every "jiu (as)" query. Empirical test showed marginal/mixed benefit. **Skipped.**

2. **DEFECT-2 — Vaar salok cut from its Pauri by an interposing comp (~14 seeds, 0.26%).** Root cause is the known `comp_type` mislabel: the interposing comp is typed `ਵਾਰ` but is *actually a salok*. A query-side "skip `ਵਾਰ`-typed comps" heuristic is **unsafe** — 116 comps carry dominant type `ਵਾਰ` and **74 of them are >8 lines (up to 124)**; they are real compositions, not saloks, so skipping/merging across them would over-collect catastrophically. The failure mode here is a *complete, valid lone salok* (not junk). Correct fix = the `comp_type` DB-correction (already documented for a future v2.1 DB patch), not an overnight query-side hack. **Deferred.**

3. **Not-in-corpus intercepts for Dasam Granth / greetings (Agent D criticals).** Phrases like `mitar pyare nu`, `deh shiva bar mohe`, `waheguru ji ka khalsa…`, `sat sri akal` are **not in SGGS** but search returns a weak coincidental line. A hardcoded blocklist is brittle whack-a-mole and risks false positives. The right fix is a **confidence floor / "not found in this edition" signal** in `do_search` (the `/api/verify` engine already does exact-quote verification — this would extend that idea to search). This is a *feature*, not a one-line fix, and deserves its own design + validation. **Deferred — top recommended next item.**

4. **`god` (English false-friend → ਗੋਡ "lap", 1 line).** Can't be fixed by the lexicon cleanly because the single corpus line means the roman tier resolves before the lexicon is consulted; a proper fix needs an English-token tier reorder. Low value (one word). **Deferred.**

5. **Aspirate-drop harness artifacts (`bau`, `baau`, `koiaa`, `garhiai`).** These are casual_quote *perturbation* artifacts more than real seeker spellings, and `bau`→`bhau` rides a very common weak fold. Low real-world value. **Skipped.**

---

## 4. Validation (every metric, before → after)

| Check | Baseline (v2.0.5) | v2.0.6 |
|---|---|---|
| Canonical regression gate | — | **0 ranking regressions** |
| Chaos suite (200 adversarial) | 175/200 | **175/200** (parity) |
| Round-trip **exact** (6,000) | 99.3% / 100% pass@3 | **99.3% / 100% / 0 miss** |
| Round-trip **casual** (2,200) | 98.4% / 99.7% | **98.4% / 99.7%** |
| Casual-quote battery (2,000) | ~98.x% / 99.8% | **98.1% / 99.8%** |
| `/api/health` | 6/6 | **6/6** |
| Hukam over-merge sweep (5,380 comps) | — | **0 over-merges, 0 crashes**; seed 399 now complete (4→93 lines) |
| DB integrity | sha `f0a64f78…` | **identical**, never staged |

Newly-resolved real queries (spot-check): `raidas` → Ang 345 (was 0 results) · `sachkhand` → Ang 8 "sach khand vasai" (was 0) · `keertan` → Ang 190 "har keeratan" (was empty) · `man mein prabhu` → Ang 388 (was mohan decoys) · `ye jeevan` / `jivan mukti` → correct jeevan lines.

---

## 5. Commit

Files touched: `webapp/serve.py` (12 lexicon entries + window 9→15), `MANIFEST.json`, `CHANGELOG.md`, `Proactive_Hardening_Report_v2.0.6.md`. **`db/sggs.sqlite` never staged.** Footer `APP_VERSION` → 2.0.6.

To publish from your Mac (git-lfs installed there):
```
cd ~/ppt-universe/SGGS-KnowledgeBase && git push
```

**Recommended next (in priority order):** (1) a confidence-floor / "not in this edition" signal so non-SGGS phrases stop returning coincidental lines — the single biggest remaining trust gap; (2) the `comp_type` DB correction (fixes DEFECT-2 and the Japji/Pauri mislabels together); (3) a character-similarity re-rank for the rare multi-collision fragment-quote tail.
