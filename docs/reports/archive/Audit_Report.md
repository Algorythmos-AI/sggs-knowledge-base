# SGGS Knowledge Base — Overnight Hardening Audit & Fix Report

**Release:** v2.0.4 · **Date:** 2026-06-13 · **Scope:** code only — `db/sggs.sqlite` is byte-identical (sha256 `f0a64f78…`, verified before and after).

This was a deep, professional-grade robustness pass: a fleet of six read-only Subject-Matter-Expert audit agents swept the app for loopholes across every dimension, findings were triaged into a no-break plan, and fixes shipped in four batches — each validated against a frozen regression gate, the chaos suite, the full-corpus round-trip harness, and a live HTTP smoke test, **reverting anything that regressed.**

---

## 1. How the audit was run

Six SME agents ran **read-only** (no file/DB/server mutation) in parallel, each owning one dimension:

| # | Dimension | Method |
|---|-----------|--------|
| 1 | Backend robustness & security | full static read of `serve.py`/`verify.py`; in-process hostile inputs |
| 2 | Search precision & recall | adversarial queries + the round-trip harness (exact + casual) |
| 3 | Data & metadata integrity | corpus reconciliation, comp_type/author/translation spot-checks |
| 4 | Frontend / UX / a11y / XSS | line-by-line read of `index.html`, WCAG checks |
| 5 | API contract & endpoints | every endpoint × valid/invalid/edge inputs, in-process |
| 6 | Performance & scalability | per-tier latency, `EXPLAIN QUERY PLAN`, worst-case inputs |

A fast **in-process regression gate** was built first to freeze a canonical query set (the lines fought for across v1.9.x–v2.0.x: `hamra dhara har`→366, `tum karoh daya mere sai`→673, `waheguru`→1402, etc.) plus the audit-target queries and the API edge cases. Baseline captured, then every batch was diffed against it — **any canonical ranking change had to be a provable improvement or it was reverted.**

---

## 2. What shipped (4 batches, 4 commits)

### Batch 1 — Backend hardening *(no ranking change)*
| Finding | Severity | Fix |
|---|---|---|
| `/api/search?limit=-1` → `LIMIT -1` = full-corpus dump (5,662+ rows) | HIGH | clamp `max(0, min(limit, 200))`, `max(0, offset)` |
| `/api/word?w="` → uncaught FTS `OperationalError` → HTTP 500 | HIGH | strip `"`/`*` from the term |
| `/api/` or `/api/ang` (no id) → `IndexError` (fragile 400) | MED | explicit `missing endpoint` / `requires an id` guards |
| `/api/word` returned `[]` on a fresh server (HAVE_FTS=None) | MED (P1 in API audit) | initialise `HAVE_FTS` for every endpoint |
| `*` silently turned exact FTS terms into prefix matches | MED | `fts_query` strips `*` |
| `{col}` interpolated into FTS SQL by name | HIGH (latent) | `_FTS_COLS` allowlist in `search_fts`/`search_like` |
| TOCTOU race building `_TERM2CONCEPT` under threads | MED | double-checked lock |
| `hukam_package` `fetchone()` could be `None` | MED | empty-corpus guard |
| `blob_search` full-table scan on long inputs | MED (DoS) | skip blob for absurd 15+ token pastes |

### Batch 2 — Search quality *(0 chaos regressions)*
| Finding | Severity | Fix | Result |
|---|---|---|---|
| `baba farid` → a vrata line (`baba` is a honorific that drops to 1 token, so honorific-drop never fired) | **CRITICAL** | `baba farid`→`phareed` bigram in the seeker lexicon | now → Ang 1377 *salok sekh phareed ke* |
| `waheguru ji` / `jio prabh` polluted by raag/author **header** lines (`bihaagarhaa` folds to the same `vhgr` as `vaahiguroo`) | MED | fold tier (`translit_norm`) now excludes `is_header=1` | headers gone |
| `satnam waheguru satnam waheguru` → junk blob (repeated tokens inflate the all-but-one threshold) | HIGH | dedupe identical OR-groups; allow the 2-group fallback only when repetition occurred | now → Ang 1402 *vaahiguroo…* |
| `maaya`/`kya` 1-char weak fold dropped the distinctive token | LOW | `maaya`→`maaiaa`, `kya`→`kiaa` | now → the common ਮਾਇਆ form |

### Batch 3 — API consistency + perf *(additive)*
- English translations attached for **every** search mode (roman/gurmukhi/theme/first/variant previously had none).
- `related_themes` always present (uniform UI contract).
- `/api/verify` returns `comp_id` + `section` → the UI can open the full shabad from a verified line.
- `/api/meta` cached → drops the ~50 ms concept-count join from every page load.

### Batch 4 — Frontend a11y / robustness / XSS
- **A11y:** shabad dialog focus-move + Tab focus-trap + `aria-labelledby` + close-button name; mode chips are a real keyboard radiogroup (arrows/Enter/Space); result + verify cards keyboard-activable; `aria-live` results; labelled Ang input; `aria-current` nav; skip link; `lang="en"` on English text & translations.
- **Robustness:** `go()` request-stamp race guard (no stale results overwriting a newer search); loading states for ang/shabad/random; "Another" spam guard; boundary nav labels (no `‹ Ang ` stub) + disabled at edges.
- **XSS hardening:** `esc()` now also escapes `>` and `"`; `esc(d.mode)`; related-theme links use a data-attribute + delegated handler (no server string in an inline `onclick`).
- **Mobile:** dynamic `--nav-h` so the sticky reader toolbar clears the wrapping nav at ~380px; 44px touch targets.
- **UX:** Japji title shows "Guru Nanak Dev Ji (M1)" instead of a blank byline.

---

## 3. Validation evidence

| Check | Baseline | After v2.0.4 |
|---|---|---|
| Regression gate (canonical set) | — | **0 ranking regressions** (only improvements: headers removed from `jio prabh`/`waheguru ji`) |
| Chaos suite (200 adversarial) | 175/200 | **175/200** (parity; 2 transient dips found & reverted mid-loop) |
| Round-trip **exact** (8,000 sample) | 99.3% / 99.96% | **99.3% pass@1 / 100% pass@3 / 0 misses** |
| Round-trip **casual** (perturbed) | ~97.8–98.2% | **98.4% pass@1 / 99.7% pass@3** |
| Live HTTP smoke | — | page + every endpoint **200**; `word?w="` 500 → fixed; verify returns comp_id/section |
| JS syntax | — | `node --check` clean; tags balanced |
| DB integrity | sha `f0a64f78…` | **identical** (never staged) |

**Two regressions were caught and reverted during the loop** (the discipline working as intended): a too-aggressive 7-token blob skip (cut legitimate voice/grammar queries → raised the threshold to 15) and a double-long-vowel twin (`jai`→`jaaee`) that shifted one canonical answer (`gur parashaad… man aai`) → dropped entirely.

---

## 4. Deliberately deferred (documented, not shipped)

These are real findings that I chose **not** to ship because the risk/scope outweighed the value under the "don't break anything" constraint. They are safe to leave; each has a clear path.

1. **`comp_type` source mislabels** (Japji pauris tagged ਵਾਰ/ਰੁਤੀ; ~600 shabads tagged ਪਉੜੀ). Already suppressed in the title display (v2.0.3). A DB-layer correction needs a re-migration + LFS re-commit — best done in a dedicated v2.1 DB patch, not an overnight code pass.
2. **Japji NULL author (385 lines)** and **~330 refrain lines without an English translation.** The title byline already shows "Guru Nanak Dev Ji (M1)" for Japji (Batch 4). Filling these in the DB is additive but again a re-migration; the display works around it now.
3. **All-but-one OR-fallback perf cap** (~40 ms on rare 7–10 token misses). Skipped: the fallback's correctness (the v1.9.5 fix) outweighs the latency on a local single-user app. The `/api/meta` cache + blob bound already removed the larger costs.
4. **Light-mode saffron contrast** (small text ~3.1:1 vs WCAG AA 4.5:1). The app is dark-mode-primary (passes there). If you want it: in `index.html` `:root`, set `--saffron:#b86210` and `--gold:#7a6216` (light mode only; the dark `@media` block already overrides both, so dark is unaffected). Left to your call to preserve the visual identity.

---

## 5. Commits this release

```
726e2f1  v2.0.4 batch4: frontend a11y, robustness, XSS hardening
096e577  v2.0.4 batch3: API consistency + meta cache (additive, 0 ranking change)
38b126a  v2.0.4 batch2: search quality (validated, 0 chaos regressions)
d90d9af  v2.0.4 batch1: backend hardening (no ranking change)
```
Files touched: `webapp/serve.py`, `webapp/verify.py`, `webapp/static/index.html`, `MANIFEST.json`, `CHANGELOG.md`, `Audit_Report.md`. **`db/sggs.sqlite` was never staged.**

To publish from your Mac (where git-lfs is installed):
```
cd ~/ppt-universe/SGGS-KnowledgeBase
git push
```
