# Validation Report — SGGS Knowledge Base v1.5.0 (built 2026-06-10)

**v1.5.0 (overnight):** English layer (2,587 SSK lines via BaniDB, 10-agent fleet; QA 12/12 alignment, 5/5 fidelity, 99% exact alignment); /api/health self-test; search highlighting; sources registry. Final E2E: 33/36 first pass → 3 housekeeping items fixed (manifest, changelog) → green. Known gap: Anand Sahib + Sukhmani tail EN coverage partial (API truncation) — re-pass listed for a future session.

**v1.4.0:** BM25 ranking · related-theme hints · /api/verify + Verify-quote mode (7/7 adversarial) · MANIFEST/CHANGELOG · Answer-Protocol machine-verification rule.

---
# (v1.3.0 report follows)

**Verdict: SHIPPED — production-ready, audited, E2E-accepted 35/35.** 60,658 lines, all 1,430 Angs. **Source reconciliation: the corpus equals the PDF's scripture text character-for-character (1,643,385 chars)** — zero loss, zero duplication, zero reordering (`pipeline/reconcile.py`, rerunnable). Canonical structure verified; app red-teamed 25/25.

**v1.3.0 (final hardening round):**
- **Per-Bhatt Swaiyye attribution** — 603 lines (92%) across Angs 1389–1409 attributed to the individual Bhatts (Kalsahar 279, Nal 84, Mathura 69, Kirat 40, Gayand 38, Jalap 25, Bal 26, Sal 18, Bhikha 13, Haribans 7, Bhal 4) from in-text signature verification (`pipeline/bhatt_attribution.json`); unsigned boundary stanzas conservatively keep 'The Bhatts'.
- **Vaar pauri attribution** — pauris now carry the Vaar's author, not the preceding salok's (206 corrected across 13 Vaars; Asa di Vaar 24/24 M1; ordinal titles like ਮਹਲੇ ਪਹਿਲੇ now parsed; ਸੋਰਠਿ ਵਾਰ ਮਹਲੇ ੪ recognized). Explicit ਪਉੜੀ ਮਃ ੫ headers still win, as printed.
- **Packaging** — double-click `Start SGGS App.command`; version + build date stamped in DB meta and shown in the app footer; E2E acceptance report in `validation/e2e_acceptance.md` (35/35, max latency 47 ms).

## 0. Full audit round (5 parallel auditors + reconciliation harness, post-release)

| Workstream | Result | Fixes applied |
|---|---|---|
| Source reconciliation | 1-char delta found → **now exact** | ਜਪੁ-style titles keep their enclosing dandas (`॥ ਜਪੁ ॥`) |
| Structure | 1 false-positive "duplicate" (Ang 1256 — the print genuinely repeats ਵੈਦ ਨ ਭੋਲੇ as pauri-end + rahao-open; kept verbatim); page-break orphan numerals | 16 orphan marker units merged back; 7 tally rubrics (ਜੁਮਲਾ, ਦੁਤੁਕੇ…) now headers |
| Unicode/translit | 12 split-vowel artifacts (ਸਫਲਿਓ ੁ→ਸਫਲਿਓੁ); 5 Sahaskriti glyph-order words | Re-attachment rule + 2 logged editorial repairs (ਸ੍ਨੇਹ, ਨਾਸ੍ਤਿ/ਬਿਗ੍ਯ੍ਯਾਪ੍ਤਿ) |
| Metadata | Invocation rows inherited the *previous* section's raag; Ramkali ki Vaar mis-tagged M5; Bhatt Swaiyye mis-tagged M5; bhagat-name substring false matches | ੴ rows adopt the section they open; Satta & Balwand on 966-968; 'The Bhatts (ਭਟ)' on 1389-1409; word-boundary author matching |
| DB/API | clean (p95 58 ms; 40/40 continued_from; FTS aligned) | 2 empty-translit rahao rows eliminated by orphan merge; bad params → 400; HEAD; favicon; conn-reset + stderr logging |
| Frontend | 2 P0 patterns (data interpolated into onclick; silent async failures) | Event delegation with data attributes; error toasts + guards; ang-paging race counter; Escape/modal keyboard guard; aria/focus-visible/reduced-motion; color-mix fallbacks |

**Post-release fixes (same day, all re-verified by the golden suite — now 49 checks):**
1. *Spelling-tolerant Roman search* — `waheguru`/`satgur kirpa` style spellings now resolve via a consonant-skeleton normal form (`translit_norm`).
2. *True raag spans* — raag start/end computed from each raag's majority-contiguous body (ਗੂਜਰੀ = 489–526, not the Ang-10 So Purakh occurrence); 31 raags stored in canonical order with composition counts.
3. *Raag-opening pages restored* — the print sets the raag title and the grand ੴ invocation as separate display lines sharing one ॥; these are now split into proper header units (480 recovered), vaar-closing words (ਸੁਧੁ) no longer drag the next raag's opening onto the previous Ang, and ੴ count is verified at exactly **568** with zero mid-unit ੴ remaining. Reader renders the invocation large and centred, as printed.

## 1. Encoding corrections (the heart of the build — all proven on golden Angs first)

| Class | Rule | Scale |
|---|---|---|
| Sihari visual→logical | `ਿ` moved after its consonant cluster (incl. ੍-clusters) | ~18.5k/100-page sample; universal |
| Subjoined consonants | `ਰ੍`→`੍ਰ`, `ਯ੍`→`੍ਯ`, `ਸ੍`→`੍ਸ` swap | ਪਰ੍ਭ→ਪ੍ਰਭ etc. |
| Ik Onkar | `੧ਓ` → `ੴ` | every bani opening |
| Font glyphs (word-evidence proven) | `Â`→ਾਂ · `¸ ± º ¼ ¾`→੍ਹ · `°`→੍ਵ · `Ô`/U+F03D→ਂ · U+F02B→ੋ · U+F02D→ਾ | ਸਾਂਤਿ, ਤਿਨ੍ਹ, ਕੋੜ੍ਹੇ, ਸ੍ਵਾਮੀ, ਨੀਂਦ, ਗੋਬਿੰਦ… |
| PDF print timestamps | ASCII `HH:MM:SS` stripped (57 lines) | logged |
| Header footnote marks | U+F045–F051, ò ó ô õ ¢ stripped from ~35 headers | logged |

**Editorial corrections (3 words, logged in-pipeline):** ਦ੍ਰਿਸਟਿ (Ang 573), ਸ੍ਰਿਸਟਿ (Ang 586) — font emitted an impossible double-sihari sequence; ਮ੍ਯ੍ਯਿਾਨੇ (Ang 727, Kabir Tilang) — detached sihari + dotted-circle glyph. Restored to the canonical reading; everything else is byte-verbatim from the PDF (after the deterministic corrections above).

## 2. Golden tests (33/33 pass; rerun anytime: `python3 pipeline/golden_test.py <pdf>`)

Mool Mantar character-exact · Japji title/openings · Ang map (PDF p.54→Ang 1 … p.1483→Ang 1430) · rahao detection · header parsing · transliteration spot-checks · first-letters · Ang 1429 Mundavani · Ang 1430 closing line.

## 3. Range QA (4 parallel agents, full corpus)

All 1,430 Angs covered, none thin/overfull · zero residual border/Latin/PUA chars (after fixes) · sihari & halant sanity universal (after fixes) · all raag transitions within ±2 Angs of canon · authors (6 Gurus, 15+ Bhagats, Satta-Balwand, Sundar, Mardana) in expected spans · 2,676 rahao lines. Full agent reports preserved in `validation/` .

## 4. Canonical structure validation (12/12 PASS)

Angs 1–1430 ordered · Mool Mantar exact · Japji 38 pauris + closing salok · Anand 40 pauris (917–922) · Sukhmani 24 ashtapadis each preceded by salok · Asa di Vaar 24 pauris · Salok M9 = 57 · 31 raags in canonical order · Raagmala ends 'ਅਠਾਰਹ ਦਸ ਬੀਸ' · no rahao in Japji · Mahala→Guru mapping consistent · 98% marker monotonicity (rest = legitimate dual numbering).

## 5. External spot-check (14 famous passages, structure-level)

12 OK, 2 "minor" — both turned out to be **our corpus matching the real pagination** (Aarti ਗਗਨ ਮੈ ਥਾਲੁ on Ang 13; Farid's ਕਾਗਾ ਕਰੰਗ on Ang 1382). Negative controls (Ardas line; non-scriptural mantra phrasing) correctly absent — corpus contains SGGS text only.

## 6. App red-team (25/25 PASS)

SQL/FTS injection, malformed queries, boundary Angs, 500-char inputs, emoji, concurrency (8 threads), offset abuse — no corruption possible (DB opened read-only immutable), no stack-trace leakage, graceful errors. Max observed search latency **29 ms** (gate: <100 ms).

## 7. Known limits (honest edges)

- **Metadata vs scripture:** raag/author/section tags are derived (header parsing + inheritance) — verified at boundaries, but individual mid-Vaar salok attributions (ਮਃ tags) can occasionally lag a line; the Gurmukhi text itself is unaffected.
- **Sahaskriti/Swaiyye ligatures:** this edition writes Sanskritised words with ੍ਯ੍ਯ + ਿਾ (e.g. ਗ੍ਯ੍ਯਿਾਨ) — kept verbatim per fidelity rules; some fonts render the sequence with a dotted circle.
- **Transliteration** is a deterministic reading aid (word-final sihari/aunkar dropped per reading convention); it is not a pronunciation authority.
- **Bhatt Swaiyye authorship** is tagged at section level (ਸਵਈਏ), not per-Bhatt.
- This KB represents **this edition**; other printings differ in spacing (ਸਤਿ ਨਾਮੁ), bindi/tippi choices, and folio breaks.
