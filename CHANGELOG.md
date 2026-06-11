# Changelog — SGGS Knowledge Base

## v1.7.0 — 2026-06-11 — Phonetic Variant Engine
- **Precomputed romanization-variant index** (Sam's Worker/Supervisor design, productionized): 59,227 variants for 29,241 words from a 15-rule weighted engine (BFS depth 3), built deterministically in 0.7s. LLM agents repositioned to rule-design + adversarial review (2 SME agents; 6 blocking changes applied).
- **Lowercase-vocabulary English veto**: real-English collisions purged (372) while reverentially-capitalized Gurbani loans (Kirtan, Amrit, Naam) stay searchable; canonical-translit collisions purged (6,232).
- New `variant-match` query tier (exact → lexicon → variants → English → fold → theme); single-FTS-expression AND with ≤3 fan-out per token. wahiguru/kirtan/hukum/kartaa/nirbhau/darsan/prabhu all resolve; 22/22 battery, 0 regressions.
- Design doc: `03_Phonetic-Variant-Engine.md`; specs in `validation/`.

## v1.6.1 — 2026-06-11 — seeker-grade search (SME-validated)
- **Any natural word now resolves professionally.** SME battery of 73 seeker queries found 18 failures (yashoda→nothing, mercy→ਮੋਰਚਾ "rust", krishna→ਕਿਰਸਾਣੁ "farmer"…); all 18 fixed, zero regressions (26-check suite).
- **Phonetic-fold v2** on the Roman tier, both index and query: y/j (yashoda≡jasodaa), sh/s, aspirate digraphs (kh gh ch jh th dh bh ph rh), z/j, glide-y (gyan≡giaan), w/v.
- **English-translation search tier** (`fts_en` over all 58,039 SSK lines) + explicit "English" mode — meaning-search like *compassion mercy* now works.
- **Curated seeker lexicon** (36 entries): common English/Hindi words route to corpus terms or themes (mercy→ਦਇਆ/ਕਿਰਪਾ, death→ਕਾਲ, ego→theme:haumai, farid→ਫਰੀਦ, sita→ਸੀਤਾ, dhru→ਧ੍ਰੂ…). Tier order: exact → lexicon → English → fold → theme (fold is last resort, killing its false positives).

## v1.6.0 — 2026-06-11 — FULL English layer
- **Complete English translation layer: 58,039 lines (95.7% of the corpus — effectively every translatable line, headers included)** from the ShabadOS open database (release 4.8.7, `database.sqlite`, gitignored), Dr. Sant Singh Khalsa's translation. Replaces the partial v1.5.0 API ingest; Anand Sahib and Sukhmani gaps fully closed (918: 36/36, 920: 35/35, 296: 49/51).
- New `pipeline/shabados_ingest.py`: AnmolLipi-ASCII → Unicode converter (vowel composition, vishraam stripping, nukta folding, sihari reordering) validated at **97.26% character-exact** against our corpus — doubling as a second-source cross-verification of our extraction. Alignment: 96.9% exact/skeleton, 1,318 fuzzy, only 102 unmatched (their two-tuks-per-line liturgy variants).
- Fidelity gate: 200 random stored translations byte-equal to source — 0 mismatches.

## v1.5.0 — 2026-06-10 (overnight build)
- **English translation layer (first external source)**: 2,587 lines of Dr. Sant Singh Khalsa's English, ingested via BaniDB/GurbaniNow APIs (personal use, attributed) by a 10-agent fleet. Coverage: Japji Sahib + So Dar/So Purakh/Sohila (Angs 1-13) complete; Sukhmani Sahib (262-296) ~90%; Anand Sahib (917-922) partial (API truncation; re-pass listed). Stored in a separate `translations` table with per-line match-quality — never mixed with scripture; shown labeled "EN ·" in Reader, shabad panel, and search cards. Alignment QA: 12/12 correct, fidelity vs source 5/5 character-exact, 99% exact-match alignment (30 edition-variant lines documented).
- **/api/health** — one-call self-test (line counts, Angs, FTS, Mool Mantar, ੴ count, verify engine, translation count).
- **Search-term highlighting** in result cards; loading states; footer attribution for the EN source.
- `sources` table begins the multi-source registry (source, attribution, license, ingest date).

## v1.4.0 — 2026-06-10
- **Layer-3 runtime verification**: `/api/verify?q=…&ang=…` + "Verify quote" search mode. Cascade exact→normalized→skeleton→roman-norm→fuzzy; verdicts VERIFIED_EXACT / VERIFIED / PROBABLE / AMBIGUOUS / NOT_FOUND with Ang cross-check and confidence. 7/7 adversarial tests, <14 ms.
- **BM25 relevance ranking** on all search modes (FTS5 weighted columns; fallback to id-order on ancient SQLite).
- **Related-theme hints**: Gurmukhi searches surface matching themes from the 53-concept index (measured +73%…+1,003% recall vs single-term).
- Governance: `MANIFEST.json` (sha-256 of corpus and DB), this changelog; Answer-Protocol now requires machine verification of quotes.
- `02_Sovereign-Architecture-Assessment.md`: truth assessment of the 5-layer sovereign architecture + rights-checked corpus-expansion menu.

## v1.3.0 — 2026-06-10
- Per-Bhatt Swaiyye attribution (603 lines, signature-verified). Vaar pauris carry the Vaar's author (206 fixed; ordinal ਮਹਲੇ ਪਹਿਲੇ titles parsed). Double-click launcher; version stamp.

## v1.2.x — 2026-06-10
- Full audit round: char-for-char source reconciliation (1,643,385 chars exact); ॥ ਜਪੁ ॥ enclosing dandas; orphan marker merge; split-vowel re-attachment; Sahaskriti repairs; invocation metadata adoption; Satta & Balwand + Bhatts authorship; server hardening (400/HEAD/favicon/conn-reset); frontend hardening (delegation, toasts, race guard, a11y).

## v1.1.x — 2026-06-10
- Raag-opening pages restored (480 ੴ invocations split into proper headers; ੴ count = 568 exact). True raag spans (majority-contiguous; ਗੂਜਰੀ 489–526). Reader redesign (shabad grouping, sticky toolbar, translit toggle, font size, keyboard, dark mode). Spelling-tolerant Roman search (waheguru → ਵਾਹਿਗੁਰੂ).

## v1.0.0 — 2026-06-10
- Initial build: 1,430 Angs extracted with proven visual→logical corrections; SQLite FTS5 KB; 53-theme concept index; zero-dependency local web app; golden suite + canonical validation + adversarial red-team.
