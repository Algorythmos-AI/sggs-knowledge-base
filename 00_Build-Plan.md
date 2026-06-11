# Sri Guru Granth Sahib — Gurbani Knowledge Base
## Build Plan (for your review, before any building begins)

*Source file: `Siri Guru Granth Sahib in Gurmukhi, with Index.pdf` (you placed it in the folder).*
*Status: planning only. I have inspected the PDF to ground this plan, but I will not build the knowledge base until you approve. This is sacred scripture (Gurbani) and the plan is written with that reverence at its centre.*

---

## 0. The brief (locked from your answers)

| Decision | Your choice | Consequence for the build |
|---|---|---|
| **Use / query types** | **All-rounder** — search & lookup, meaning & explanation, thematic/topical, structure & reference | The KB must support every angle: find a line, list an author's compositions, explain a shabad, answer "what does Gurbani say about X", and do Ang/Raag/concordance lookups. |
| **Fidelity to scripture** | **Verbatim Gurmukhi + Ang reference only** | The scripture is stored and quoted **only verbatim**, never paraphrased or "corrected." Every quote carries its **Ang** (page). *(One tension to confirm — see §9.)* |
| **Answer language** | **Both, side by side** | Answers are bilingual: Gurmukhi (the Gurbani) + English, together. |
| **Build scope** | **Full robust build** | All 1430 Angs, line-by-line, with full metadata, the visual→logical correction, transliteration, and a thematic concordance. |

---

## 1. What we are actually dealing with (verified by inspection)

I examined the PDF directly so this plan is grounded in fact, not assumption:

- **1,483 PDF pages, ~16 MB, not encrypted, not scanned.** It is real selectable text — **no OCR needed** (a major win; Gurmukhi OCR is error-prone and we avoid it entirely).
- The Gurbani is genuine **Unicode Gurmukhi** (fonts *GuruGranthUni* and *AnmolUniBani*, with ToUnicode maps). The Mool Mantar extracts as real Unicode (`ੴ ਸਤਿਨਾਮੁ ਕਰਤਾ ਪੁਰਖੁ …`).
- **The Ang (page) number is printed in every page border** — `❀❀❀ 707 ❀❀❀` — so we get a reliable **PDF-page → Ang** mapping (1483 PDF pages = **1430 Angs of Gurbani** + ~53 pages of index/*tatkara*, intro and borders; e.g. PDF page 760 = Ang 707).
- **All the structural markers are present and extractable:** Raag headers (`ਰਾਗੁ …`), author headers (`ਮਹਲਾ ੧–੫, ੯`; Bhagats; Bhatts), composition types (`ਸਲੋਕੁ`, `ਪਉੜੀ`, `ਸ਼ਬਦ`, `ਅਸਟਪਦੀ`, `ਛੰਤੁ`, `ਵਾਰ`), the refrain marker **`ਰਹਾਉ`**, line-end `॥`, and numbered verse-ends `॥੧॥ ॥੨॥ …`, plus Gurmukhi numerals `੦–੯`.

**Two systematic defects that must be fixed everywhere** (these are the heart of the engineering):
1. **Visual-order vowels.** The text extracts in *visual* order, not *logical* order: the **sihari** vowel `ਿ` (U+0A3F) comes out **before** its consonant instead of after it. We saw `ਸਿਤਨਾਮੁ` where the true word is `ਸਤਿਨਾਮੁ`, and `ਮਿਨ`/`ਸਿਭ`/`ਿਸਮਰਤ` where the true words are `ਮਨਿ`/`ਸਭਿ`/`ਸਿਮਰਤ`. **Unless corrected, every search will fail.** This reordering is the single most important correctness step.
2. **Decorative borders.** The `❀` flower glyphs frame every page and must be stripped without losing the Ang number they surround.

---

## 2. Best practices for a Gurbani knowledge base (the principles we will hold to)

**Reverence & fidelity (non-negotiable).**
- The scripture is stored and quoted **only verbatim**. We never alter, "modernise," re-spell, or paraphrase Gurbani. Every quotation carries its **Ang**.
- **Interpretation is always visibly separated from scripture** and labelled as interpretation — never presented as the Granth's authoritative meaning.
- **No fabrication.** If the corpus does not contain something, the answer says so. Every answer is grounded in retrieved verbatim lines with Ang citations.

**Unicode correctness.**
- Normalise to **NFC**; keep the Gurmukhi block (U+0A00–U+0A7F) intact: `ੴ` (U+0A74), addak `ੱ`, tippi `ੰ`, bindi `ਂ`, the nukta letters (`ਸ਼ ਖ਼ ਗ਼ ਜ਼ ਫ਼ ਲ਼`), subjoined/*pairin* consonants (via halant U+0A4D — pairin `ਹ ਰ ਵ ਯ`), and numerals `੦–੯`.
- **Visual→logical reordering** (the linchpin): wherever sihari `ਿ` precedes a consonant, move it to immediately **after** that consonant (and after any subjoined consonant). The algorithm is proven first against known lines before it touches the corpus.

**Structured metadata (what makes it an all-rounder).** Every line carries: **Ang**, **Raag**, **author** (Mahalā / Bhagat / Bhatt), **composition type** (shabad / ashtpadī / chhant / vār+pauṛī / salok), **Ghar**, line-number-within-composition, the **Rahao** flag, and a stable line-ID. Context **inherits** correctly — a `ਮਹਲਾ ੧` header applies to following shabads until a new author header appears (same for Raag and Ghar).

**Transliteration** — a consistent, documented Roman scheme generated mechanically from the *corrected* Gurmukhi, marked clearly as a **reading aid, not scripture**. (Scheme to confirm — §9.)

**Concordance & thematic index** — a true word concordance (word → all line references with counts) plus a concept index (e.g. *Naam* `ਨਾਮੁ`, *Hukam* `ਹੁਕਮੁ`, *Haumai* `ਹਉਮੈ`, *Simran*, *Sevā*, *Satgur*, *Kāl/Akāl*) → line references. This is what answers "what does Gurbani say about X."

**Three-way search** — by Gurmukhi (exact + normalised, tolerant of matra/spelling variants), by transliteration, and by English concept.

**Canonical validation** — cross-check against the known invariants of the SGGS: exactly **1430 Angs**; the Mool Mantar; **Japji's 38 pauris**; Ang 1 opening and Ang 1430 closing lines; the Raag sequence (Sirī Rāg first → … → Jaijāwantī, then Saloks/Swaiyye/Mundāvanī/Rāgmālā); and spot-checks of ≥30 random Angs against an authoritative public reference (structure-level, to catch extraction errors).

**Provenance & limits** — the KB is built from *this* edition; we note that, flag any low-confidence lines, and never present interpretation as doctrine.

---

## 3. The knowledge base we will build (architecture)

A folder `SGGS-KnowledgeBase/` containing:

- **`corpus/`** — the line-by-line corpus, in two forms: machine-readable **JSONL** and human-readable **Markdown** (one file per Raag). Each line record:
  ```
  { line_id, ang, pdf_page, raag, author, composition_type, composition_id,
    ghar, line_no, is_rahao, is_header,
    gurmukhi,            ← verbatim, logical-order, NFC (the scripture)
    transliteration,     ← mechanical reading aid
    verse_markers }      ← ॥1॥ etc.
  ```
- **`index/`** — metadata indexes: by Ang, by Raag, by author, by composition; the Raag table; the author table; counts and totals.
- **`concordance/`** — the word concordance (word → lines) and the concept/thematic index (concept → lines).
- **`MASTER-INDEX.md`** — the navigation hub and "how to ask."
- **`query.py`** — a small, reproducible search tool (structured filters + Gurmukhi/translit/English search) so look-ups are fast and exact.
- **`Answer-Protocol.md`** — the fixed rules I follow to answer faithfully (always verbatim + Ang + transliteration, bilingual, interpretation clearly labelled).
- **`Validation-Report.md`** — the canonical cross-checks and error rates.

**How querying will work in practice:** when you ask *anything*, I search the structured corpus (by Gurmukhi / transliteration / concept / metadata), return the **verbatim Gurbani + transliteration + Ang(s)**, and — for meaning or thematic questions — add a clearly-labelled bilingual explanation grounded in those exact verses. Every answer is anchored in the corpus and cited by Ang. Nothing is invented.

---

## 4. How we process 1,430 Angs — the multi-agent pipeline

Phased, and parallelised by Ang ranges exactly as you asked, with correctness proven *before* we scale.

**Phase A — Build & prove the extraction harness (1 careful setup pass).**
Develop the pipeline on a handful of *golden* Angs chosen to stress every case: Ang 1 (Japji), a Vār with pauṛīs, a Bhagat Bāṇī page, a Chhant, and Ang 1430 (the close). Nail: Ang detection from borders, border-stripping, **visual→logical sihari reordering**, line/verse segmentation, header vs verse detection, context inheritance, and transliteration. Validate the goldens character-by-character against known text. **Output:** a verified `process_ang.py` + transliteration module + validation harness. *Nothing scales until this is proven correct.*

**Phase B — Parallel extraction & structuring (multi-agent).**
Split the 1430 Angs into **~14 ranges (~100 Angs each)**. One sub-agent per range: extracts its Angs, runs the proven pipeline, segments shabads/verses, tags metadata, generates transliteration, and self-QAs (line counts, no residual `❀`, valid Unicode, sihari sanity, headers resolved). Each outputs its corpus chunk + a QA note.

**Phase C — Merge & global structuring (1 pass).**
Concatenate ranges into the master corpus; assign global IDs; reconcile shabads that straddle a range boundary; build the Ang/Raag/author/composition indexes.

**Phase D — Concordance & thematic index (multi-agent).**
Agents build the word concordance and the concept index (each owns a set of concepts / Gurmukhi letters), producing concept→line and word→line maps.

**Phase E — Validation & "viva" QA (dedicated agents).**
One agent runs the canonical cross-checks (all 1430 Angs present & ordered; Mool Mantar exact; Japji 38 pauṛīs; Ang 1 & 1430 lines; Raag order; ≥30 random-Ang spot-checks vs an authoritative reference). A second, adversarial agent fires hard queries and confirms every answer is faithful, bilingual, and Ang-cited. We fix until the gates in §6 pass.

**Phase F — Query layer & docs.**
Build `query.py`, `MASTER-INDEX.md`, and `Answer-Protocol.md`; run a battery of real example queries across all four query types end-to-end to prove the all-rounder capability.

---

## 5. Multi-agent roster

- **1 ×** pipeline-engineer agent (Phase A harness).
- **~14 ×** extraction agents (Phase B, one per ~100-Ang range).
- **1 ×** merge/structuring agent (Phase C).
- **~4 ×** concordance/thematic agents (Phase D).
- **2 ×** QA agents (Phase E) — canonical-validation + adversarial query red-team.
- **Lead (me):** orchestrate, verify every gate, integrate, and answer your queries from the finished KB.

---

## 6. Quality gates (a phase does not ship until…)

- Sihari reordering verified **100%** on the golden Angs (Mool Mantar, Japji, Ang 1430).
- **Zero** residual `❀`/border artifacts in the corpus.
- **All 1430 Angs present and in order**; PDF-page→Ang map validated end to end.
- Shabad/line counts sane; Raag and author boundaries correct; Rahao lines tagged.
- ≥30 random Angs spot-checked against an authoritative reference with a low, measured error rate.
- Every example-query answer carries a **verbatim quote + Ang**; nothing uncited.

---

## 7. Risks & mitigations

- **Visual-order reordering errors (the #1 risk)** → golden-test-driven; conservative, validated rule; low-confidence lines flagged for review.
- **Edition / spelling variance** (this PDF vs other editions) → we treat *this* PDF as the source of truth, note the edition, and validate *structure*, not word-for-word identity with other editions.
- **Index/*tatkara* & intro pages** (decorative, multi-column) → parsed opportunistically; the border Ang numbers remain the authoritative Ang map regardless.
- **Interpretation fidelity** → per your "verbatim only" choice, scripture stays verbatim; any explanation is clearly labelled interpretation, grounded in the cited verses, never presented as authoritative doctrine.
- **Reproducibility across sessions** → the corpus and all build scripts are saved in your folder so the KB persists and can be regenerated or extended. *(Note: sandbox temp files do not persist; final outputs in your folder do.)*
- **Reverence** → sacred-text handling throughout; nothing flippant, nothing fabricated.

---

## 8. Deliverables

`SGGS-KnowledgeBase/` → `00_Build-Plan.md` (this), `corpus/` (JSONL + readable Markdown by Raag), `index/`, `concordance/`, `MASTER-INDEX.md`, `query.py`, `Answer-Protocol.md`, `Validation-Report.md`, and a short **"How to ask"** guide with worked examples for each query type.

---

## 9. Four decisions for your review (before I build)

1. **The verbatim-vs-explanation tension.** You chose *"verbatim + Ang reference only"* for fidelity, but also want *meaning & explanation* queries. **My proposed reconciliation:** the scripture is always quoted verbatim with its Ang; when you ask for meaning, I add a **clearly-labelled, conservative explanation grounded in those exact verses** (never presented as the scripture). Confirm this — or tell me to stay strictly verbatim (pure retrieval, no explanation).
2. **Transliteration — include it?** I recommend **yes**: it is mechanical (not interpretation), aids reading and search, and serves your "both languages" choice. (It was technically a level above "verbatim only," so I'm flagging it.) If you'd rather omit it, say so.
3. **Transliteration scheme** (if yes): a **reader-friendly Roman** (SGPC / SikhiToTheMax style — *default*) or **ISO 15919** (academic, with diacritics)?
4. **Validation reference:** may I cross-check sampled Angs against an authoritative public SGGS reference (structure/line-level only, to catch extraction errors)? *(Default: yes.)*

**On your go-ahead, I start with Phase A — proving the extraction + reordering pipeline on the golden Angs — and show you the verified result before unleashing the parallel agents.**
