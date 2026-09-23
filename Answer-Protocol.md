# Answer Protocol — how Gurbani questions are answered from this knowledge base

These rules bind any session — human or assistant — answering from `SGGS-KnowledgeBase`. They implement Sam's locked decisions (2026-06-10).

1. **Scripture is quoted only verbatim.** Every quoted line is retrieved from the corpus/DB — never typed from memory — and carries its **Ang** (and Raag/author where known). No re-spelling, no "modernising", no paraphrase presented as Gurbani.
2. **Bilingual presentation.** Quotes appear as: Gurmukhi line → transliteration (italic) → Ang reference. English explanation follows separately.
3. **Interpretation is always labelled.** Meaning/teaching answers add a section explicitly marked *Explanation (interpretation, not scripture)* — grounded only in the retrieved verses, conservative, never presented as the Granth's authoritative meaning or as doctrine.
4. **No fabrication.** If the corpus doesn't contain something, say so. Never invent a line, an Ang number, or an attribution. If retrieval is ambiguous (variant spellings, multiple candidates), show the candidates.
5. **Search order for queries:** exact Gurmukhi → transliteration → first-letters → skeleton (matra-stripped) → theme/concordance. Use `webapp/serve.py` API or `db/sggs.sqlite` directly.
6. **Provenance:** answers cite this edition (the user's PDF). Where editions are known to differ (spacing of ਸਤਿ ਨਾਮੁ, bindi/tippi variants, Sahaskriti ੍ਯ੍ਯ ligature convention), note it rather than "correcting" it.
7. **Reverence:** treat all content as sacred text; nothing flippant; refusals of disrespectful requests are polite and firm.
8. **Machine verification (Layer 3).** Before presenting any Gurbani quotation, verify it: `GET /api/verify?q=<line>&ang=<claimed ang>` against the running app (or call `webapp/verify.py: verify()` directly on `db/sggs.sqlite`). Only VERIFIED_EXACT / VERIFIED quotes may be presented as scripture; PROBABLE requires showing the canonical line instead of the claim; NOT_FOUND must be disclosed as unverifiable. The Ang shown must be the verifier's Ang, never a remembered one.
