# Glossary

| Term | Meaning |
|---|---|
| **Ang** | A page of Sri Guru Granth Sahib Ji (1–1430). |
| **Bir** | A physical volume/edition of the Granth; the source PDF is one Bir. |
| **comp_id** | The id grouping all `lines` of one composition (heading run + body). See [database-schema](https://github.com/Algorythmos-AI/sggs-data/blob/main/docs/architecture/database-schema.md) (sggs-data). |
| **Rahao** | The refrain/pause line of a shabad (`is_rahao=1`). |
| **Shabad** | A hymn/composition. |
| **Salok / Pauri** | A couplet-style verse / a stanza; the two alternating unit kinds of a Vaar. |
| **Vaar** | A balladic composition; 22 in the Granth. Its pauris take the Vaar's author even where interleaved saloks carry other Gurus' `ਮਃ` headers. |
| **Ghar** | The musical "house"/beat of a composition (`ਘਰੁ`). |
| **Raag** | The musical mode a section is set in; the Granth is largely organized by raag. |
| **Saroop** | The traditional printed rendering of the Granth; also the app's display toggle. |
| **roman_norm** | The phonetic fold that makes Roman search spelling-tolerant (must be byte-identical in 3 places). |
| **Golden vectors** | `contract/*.ndjson` — recorded outputs that pin the Swift port to the Python source of truth. |
| **ੴ** | Ik Onkar — the invocation opening compositions and the Granth. |
