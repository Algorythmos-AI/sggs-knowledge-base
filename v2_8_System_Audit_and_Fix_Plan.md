# v2.8.0 — System Audit & Fix Plan

**Type:** Read-only diagnostic audit (HARD PAUSE before Feature 3).
**Scope:** Full stack — data/algorithm layer, DevOps/runtime architecture, UI/UX & client state.
**Method:** 3 SME read-only subagents (code via Read/Grep) + live-DB investigation against the running server via Chrome.
**Constraint honored:** Nothing was modified — no DB writes, no Astro rebuild, no backend code changes. Findings only.

---

## 0. Verdict

The build is **production-sound at the architecture level**: the server is pure-stdlib, the analytics tables are additive and top-K (no embedding/O(n²) bloat), search core is untouched, and all six Astro routes serve 200. The audit surfaced **one genuine data-accuracy bug** (Majh Ki Vaar drops 4 pauris) and a cluster of **hardening/polish** items. No critical security or do-no-harm regressions.

The earlier "±1 anomaly" worry is now **resolved by live data**: Maru-M5 (22) and Sarang (36) are **correct** for this edition (internally consistent). Only **Majh** is genuinely wrong.

---

## 1. CRITICAL — fix before shipping v2.8.0 publicly

### C1. Majh Ki Vaar under-counts pauris (23 vs canonical 27) — **data accuracy**
**Evidence (live API, `/api/analytics/vaar?id=2`):** pauri numbers present = `1,2,3,5,6,7,8,12,13…26` + one unparsed. **Missing pauri #4, #9, #10, #11.** They are not absent from scripture — their `ਪਉੜੀ` units are being merged into adjacent saloks.
**Root cause (`build_vaars.py`):** `line_kind()` (≈L80) only classifies a line as `pauri-label` when `pada_total==0 AND is_header`. The 4 Majh pauris whose `ਪਉੜੀ` header carries a nonzero `pada_total` (or `is_header=0`) are demoted to `verse` and absorbed into the open unit. No fallback matches a `ਪਉੜੀ`-prefixed line outside that gate.
**Why it matters:** This is the one place the tool misstates scripture structure. Every other famous count validated exact (Asa 24, Gauri-M4 33, Sorath 29, Bilaval 13, Satta 8, Basant 3, Kanra 15).
**Fix direction (do NOT implement yet):** add a pauri-label fallback (match `ਪਉੜੀ`-prefixed lines regardless of `pada_total`/`is_header`), then add a **per-Vaar self-check** comparing the set of detected pauri numbers against the contiguous `1..maxPno` run and logging any gap at build time. This single guard would have caught Majh automatically.

### C2. `frontend/dist/` not ignored by the ROOT `.gitignore` — **repo hygiene (recurrence risk)**
**Evidence (Agent 2):** the just-fixed `node_modules` leak was the same class of problem. `frontend/dist/` is ignored only by the **nested** `frontend/.gitignore`; the root file has no `dist/` (nor `.venv/`) entry. If gitignores are ever consolidated or the nested file removed, the entire build output becomes trackable again — the exact failure mode we just cleaned up.
**Fix direction:** add `frontend/dist/`, `.venv/`, `venv/` (and optionally `*.sqlite-wal`/`-shm`) to the root `.gitignore`. (The `node_modules/` and `.astro/` entries added this session are correct.)

---

## 2. MODERATE — hardening, schedule into the v2.8.x pass

### M1. FTS5 operator injection → 500 — ❌ **VERIFIED NON-ISSUE (2026-06-15), no change made**
**Original concern (Agent 2):** `_fts_clean` (≈L114) only strips `"` and `*`, so a crafted query (`q=AND`, `q=NEAR(a b)`, `q=col:`, leading `-`/`^`) was theorized to reach `text MATCH ?` and raise `sqlite3.OperationalError` → 500.
**Resolution — refuted empirically.** Tracing `fts_query` (L120-124) shows every token is wrapped in double quotes (`"AND"`, `"NEAR"`, `"col:"`) before `MATCH`, which makes all FTS5 operators **literal terms**, not operators. The only char that can escape a quoted phrase is `"`, which `_fts_clean` strips. Live battery of 16 adversarial inputs (`AND`, `OR`, `NOT`, `NEAR(a b)`, `col:`, `text:guru`, `^foo`, `-foo`, `(`, `a)`, `*`, `"`, `a AND b`, `{text}:x`, …) against both `/api/search` and `/api/word`: **all returned HTTP 200 with the valid `{mode,results,related_themes}` contract** (e.g. `AND`→2 literal matches, `NEAR(a b)`→50). Agent 2's read missed the quote-wrapping. **No code change — the search core is already correctly defended.**

### M2. Interior Bhagat-salok attribution is unguarded (latent, **not currently realized**)
**Evidence:** Agent 1 noted the trailing-salok trim (`units[:last_p+1]`) only defends the *tail*; an interior salok by a non-Guru could still be attributed into an M1/M2 Vaar. **Live check result: NOT happening today** — the only non-Guru salok authors in the data are **Bhai Mardana in Bihagra** (legitimate — Mardana's saloks really are there) and Satta/Balwand in their own Vaar. So this is a **latent robustness gap**, not an active contamination.
**Fix direction (optional hardening):** when computing `salok_authors`/`cross_author`, keep the data as-is (it's correct) but consider a build-time warning if an interior salok's lineage is neither the Vaar's Guru-line nor a known associated author. Low urgency.

### M3. `sync-to-webapp.mjs` cpSync fallback — ❌ **VERIFIED NON-ISSUE (2026-06-15), no change made**
**Original concern (Agent 2):** the `cpSync` fallback (L39) doesn't delete stale files, so old hashed `_astro/*.js` chunks could linger in `webapp/static/`.
**Resolution — refuted by full read.** Step 1 (L28-30) renames `STATIC → BACKUP` *before* the sync, so by L36/L39 `webapp/static/` does not exist; `mkdirSync` (L38) creates it empty and `cpSync` fills it solely from `dist/`. Both the `rsync --delete` path and the `cpSync` fallback therefore write into a **freshly-emptied** directory — no stale chunks can survive in either path. Agent 2 read L39 without the preceding rename. The single-slot backup + two-step rollback rename are minor (same-filesystem renames are effectively atomic); not worth changing working deploy tooling. **No change.**

### M4. Visualizations are not screen-reader / keyboard accessible (`analytics.ts`, `analytics.astro`)
**Evidence (Agent 3):** the D3 `<svg>`s (themeNetwork L32, resonanceChord L219, ribbonStream L289) and the Chart.js `<canvas>` (analytics.astro L30) have **no `role`/`aria-label`/`aria-hidden`** — a screen reader hits unnamed graphics. Network nodes/chord arcs/stream bands are **click/hover-only**, not keyboard-operable.
**Good news:** the new **Vaar Anatomy strip is exemplary** — real `<button>` units with `title`, visible text, and `:focus-visible` rings; `#vaarSel` has `aria-label`. So this item is about the *older* analytics viz, not the Vaar feature.
**Fix direction:** add `aria-label` (or `aria-hidden="true"` + a visually-hidden text summary) to each SVG/canvas; optionally make nodes keyboard-focusable.

### M5. localStorage Study Trail — cross-tab race & silent quota failure (`store.ts`)
**Evidence (Agent 3):** every mutation is a whole-array read-modify-write (L25-34); the `storage` listener (L40) re-renders but does **not** reconcile before the next write, so concurrent tabs can lose pins. `enrichThemes` (L43-58) reads, awaits network, then writes the **stale** array → clobbers pins added during the fetch. Writes are wrapped in `try{}catch{}` (good — no crash) but there's **no pin cap**, so past quota the write silently fails while `togglePin` still returns `true` and the button shows "pinned" → **UI/storage divergence**.
**Good news:** `JSON.parse` on hydration **is** wrapped (L16) — corrupted storage resets gracefully, not a crash.
**Fix direction:** re-read-and-merge on write (or `BroadcastChannel`); cap pin count (e.g. 500) and surface quota failure instead of silently swallowing it.

---

## 3. POLISH — nice-to-have, no urgency

- **P1. `maxPno = nP − 1` display quirk:** for most Vaars the *last* pauri's `pauri_no` isn't parsed into the display field (count is correct, the rung just shows no number). Cosmetic; fixable alongside C1's marker parsing.
- **P2. 400 responses leak raw Python exception strings** (`serve.py` ≈L1144) — minor info hygiene.
- **P3. Root `.gitignore` lacks `*.bak`, `*.sqlite-wal`/`-shm`** — defensive only.
- **P4. Dead assignment** `soft` computed but unused in `themeNetwork()` (`analytics.ts` L26).
- **P5. `theme_network` stores both edge directions** (~2× rows on a tiny table) — deliberate, acceptable.

---

## 4. Explicitly CLEAN (verified, no action)

- **Server purity:** `serve.py` + its only local import `verify.py` are **100% Python stdlib** — no torch/numpy/sklearn/pandas in the runtime path. Semantic features served from precomputed SQLite only.
- **DB footprint:** no raw embedding vectors or O(n²) matrices persisted. `line_neighbors`, `shabad_neighbors` are top-K; `theme_network` is support-thresholded. No BLOB columns.
- **Additive safety:** every Phase-3 builder (`build_vaars`, `ml_analytics_builder`, `build_semantic_vectors(_lite)`, `build_resonance`) DROP/CREATE/INSERTs **only its own tables**; `ml_analytics_builder` runs `verify_additive()` asserting base-table + Mool Mantar byte-identity before commit. (Note: `enrich_v2.py`/`enrich_orchestrator.py` do mutate `lines` — by design, they are the upstream enrichment passes, not additive builders.)
- **Routing:** all six pages (`/reader /trail /lineage /browse /themes /analytics`) return **200** — the suspected `trailingSlash` mismatch is a non-issue.
- **Vaar endpoints:** read-only, parameterized, graceful `OperationalError` fallback; `?id=` now hardened against non-numeric input.
- **Vaar viz accessibility & theming:** real buttons, `aria-label`s, and all `--gold`/`--line-strong`/theme variables defined across light/dark/`prefers-color-scheme` blocks.
- **No XSS:** all DB strings escaped via `esc()` before `innerHTML`.

---

## 5. Suggested execution order (when approved)

1. **C1** — Majh pauri-label fallback + per-Vaar `1..maxPno` gap self-check (rebuild + re-validate all 22 on a DB copy first; do-no-harm).
2. **C2 / P3** — root `.gitignore` additions (`frontend/dist/`, `.venv/`).
3. **M1** — FTS5 sanitization hardening (query-side, full search regression gate).
4. **M3** — sync-script `cpSync` parity.
5. **M4 / M5** — accessibility labels + Study Trail write reconciliation/cap.
6. **P1–P4** — polish sweep.

Each fix validated in isolation against the do-no-harm gate (search untouched, additive-only, no base-table writes) before the next.

---

**Audit complete. Shall we execute these fixes one by one?**
