---
title: "Glossary"
description: "Definitions of the scripture, Gurmukhi and engineering terms used across the wiki — from Ang, Rahao and Vaar to comp_id, the dataset pin and golden vectors — each linkable and shown as a hover-card."
sidebar:
  order: 1
---
# Glossary

Wherever a page writes `[[Term]]`, the site shows the definition below in a hover-card and links
here; the build fails on a term that is not in this table. Scripture terms are explained for
engineers and students new to the tradition; where the scholar review (gate G3) is still pending
the page that uses the term says so. Cite the scripture itself, never this table.

## The scripture

| Term | Meaning |
|---|---|
| **Sri Guru Granth Sahib Ji** | The scripture and eternal Guru of the Sikhs: 1,430 Angs of hymns by six Gurus, fifteen Bhagats, eleven Bhatts and three others, compiled in one edition whose text this project serves verbatim. Always named in full, always cited by Ang. |
| **Granth** | "Book"; short for the scripture in prose, never in a citation. |
| **Ang** | A page of Sri Guru Granth Sahib Ji (1–1430). The unit of every citation: "Sri Guru Granth Sahib Ji · Ang N". |
| **Bir** | A physical volume/edition of the Granth; the source PDF is one Bir, and the corpus reproduces its text character for character. |
| **Edition** | A printed lineage of the Bir. Editions differ in spacing, bindi/tippi and ligature conventions; the project records this edition and notes differences instead of "correcting" them. |
| **Gurbani** | The Gurus' word — the text of the scripture. "Gurbani Soul" names the app; Gurbani names the text. |
| **Bani** | A composition or a named body of hymns (Japji Sahib, Rehras Sahib…). In the app, a bani is a registry of pointers into the verbatim corpus. |
| **Shabad** | A hymn/composition; in the database a `comp_id` groups its lines, heading run included. |
| **Rahao** | The refrain/pause line of a shabad, marked ਰਹਾਉ (`is_rahao=1`); the line the rest of the shabad turns around. |
| **Salok / Pauri** | A couplet-style verse / a stanza; the two alternating unit kinds of a Vaar. |
| **Vaar** | A balladic composition of pauris with interleaved saloks; 22 in the Granth. Its pauris take the Vaar's author even where the saloks carry other Gurus' ਮਃ headers. |
| **Ashtapadi** | An eight-stanza composition (Sukhmani Sahib is twenty-four of them). |
| **Chhant** | A lyrical, longer-lined composition form found in several raags. |
| **Swaiyya / Swaiyye** | The praise-verses of the Bhatts (Angs 1389–1409), one set for each of the first five Gurus. |
| **Sahaskriti** | The Sanskritised saloks (Angs 1353–1360) whose spelling uses clusters such as the subjoined ya; the source font's handling of them is why several editorial rules exist. |
| **Mool Mantar** | The opening statement of the Granth (Ang 1), from ੴ to ਗੁਰ ਪ੍ਰਸਾਦਿ; the Mool Mantar folds into Japji's `comp_id` 2. |
| **Japji** | Japji Sahib, the first bani (Angs 1–8, 385 lines); its lines have `author = null` because the print carries no ਮਹਲਾ line. |
| **So Dar / So Purakh / Sohila** | The three short sections after Japji (Angs 8–13) that, with it, open the Granth before the raags begin at Ang 14. |
| **Raag** | The musical mode a section is set in; 31 raags order Angs 14–1353. A raag's span is the longest run of Angs where it is the majority. |
| **Ghar** | The musical "house"/beat of a composition (ਘਰੁ), read from the heading. |
| **Mahalla** | ਮਹਲਾ / ਮਃ N in a heading: "the Nth Guru" as author (M1 Guru Nanak Dev Ji … M9 Guru Tegh Bahadur Ji). |
| **Guru** | One of the ten Sikh Gurus; six wrote hymns in the Granth (M1–M5 and M9). In the app's text, "Guru" is also a search honorific that the waterfall drops when retrying. |
| **Bhagat** | A saint-poet whose hymns are in the Granth — Kabir Ji, Namdev Ji, Ravidas Ji, Sheikh Farid Ji and others; fifteen in all. |
| **Bhatt** | One of the eleven bards whose Swaiyye praise the Gurus (Angs 1389–1409); attributed per Bhatt from signature evidence. |
| **Mundavani** | The closing seal of the Granth (Ang 1429), followed by a final salok and Raagmala. |
| **Raagmala** | The index of raags that closes the Granth (Angs 1429–1430). |
| **Hukam / Hukamnama** | A composition taken as the day's reading; the API's `/api/random` returns one complete unit for it. In the hymns, ਹੁਕਮੁ is also the divine Will. |
| **Nitnem** | The daily prayers; in the app a set of banis ordered by time band, with a Nitnem day that rolls at 03:00. |
| **Gutka** | A small prayer book; the app's Nitnem screen plays that role. |
| **Rehras** | The evening prayer; the app carries the SGPC form by default and the Taksal form as a variant. |
| **Sri Dasam Granth** | The scripture associated with Guru Gobind Singh Ji; three Nitnem banis come from it and live in the app's separate, labelled `extra_lines` layer, never in `lines`. |
| **Ardaas** | The Sikh prayer of supplication; in the app it is non-SGGS text in the labelled layer. |
| **Granthi** | The reader and custodian of the scripture; the reviewer role in this project — reviews flagged text, never edits it. |
| **Sangat** | The congregation; in the hymns ਸੰਗਤਿ is the company of the holy. The project's readers. |
| **Amrit Vela** | The early morning hours (in the app, 03:00–09:00), the first Nitnem time band. |
| **Pahar** | A three-hour watch of the day; the app's raag clock places raag-timing claims on the pahar cycle. |
| **Naam** | The Name — the divine presence remembered in the hymns; the most frequent theme in the concept index. |
| **Haumai** | Ego, self-centredness; a theme in the concept index and one of the vices the hymns name. |
| **Waheguru** | The name of God most used by Sikhs; in Roman search the classic case for the fold (waheguru, vaahiguroo → vhgr). |

## Gurmukhi and Unicode

| Term | Meaning |
|---|---|
| **Gurmukhi** | The script of the Granth (Unicode block U+0A00–U+0A7F). Every stored line is Gurmukhi; Roman letters are only ever a reading aid. |
| **Matra** | A vowel sign attached to a consonant (`ਾ ਿ ੀ ੁ ੂ ੇ ੈ ੋ ੌ`). The skeleton column strips them. |
| **Sihari** | The short-i sign ਿ, written *before* its consonant in print but stored *after* it in logical Unicode — the reordering the pipeline performs. |
| **Halant** | The virama ੍ that joins a consonant to the next as a subjoined letter (pairin). |
| **Addha-yayya** | The subjoined ya ੍ਯ; the source font doubles it in Sahaskriti words, and the saroop display collapses the pair without touching the stored text. |
| **Tippi / Bindi** | The two nasal signs ੰ and ਂ; editions differ in which they print, so the project keeps this edition's choice. |
| **Nukta** | The dot ਼ under a consonant for borrowed sounds; kept verbatim wherever the Bir prints it. |
| **Danda** | The line divider: the double danda ॥ ends a line or unit and carries the numerals (॥੧॥); the single danda । is rare. The pipeline cuts units on ॥. |
| **ੴ** | Ik Onkar — the invocation opening compositions and the Granth (U+0A74); restored by the pipeline from the font's two-glyph form. |
| **Sant Lipi** | The open-licence Gurmukhi font (SIL OFL) the site and the app bundle so the Granth renders the same everywhere. |
| **Saroop** | The traditional printed rendering of the Granth; also the app's display toggle that collapses the doubled ya in rendered glyphs only — the stored text stays verbatim. |
| **NFC** | Unicode's canonical composition; the pipeline and the verifier normalise to it before comparing. |
| **Transliteration** | The Roman spelling of a Gurmukhi line (`translit`), a reading aid built by the pipeline — never scripture, never cited. |

## The data

| Term | Meaning |
|---|---|
| **Corpus** | `corpus/sggs.jsonl` in sggs-data: 60,658 verbatim line records, proven character for character against the PDF. |
| **Line record** | One display line of the Granth as a row of the `lines` table, with its placement, heading metadata, text forms and search forms. |
| **comp_id** | The id grouping all `lines` of one composition (heading run + body); vacated ids are permanent gaps. See the database schema (sggs-data). |
| **Heading run** | Consecutive heading lines (a title, the invocation, a label) that open a composition and share its `comp_id`. |
| **Skeleton** | A line with its vowel signs stripped, for the typo-tolerant tiers. |
| **First letters** | The first letter of each word (`fl_g`, `fl_r`), the form seekers use to find a line they half-remember. |
| **FTS5** | SQLite's full-text index; the `fts` table over six search columns, ranked by bm25. |
| **Reconcile** | `reconcile.py`: the proof that the corpus equals the PDF's text stream, character for character; the rebuild aborts on one difference. |
| **Golden suite** | `golden_test.py`: nine groups of canonical structural checks every rebuild must pass. |
| **Editorial ledger** | sggs-data's register of every transform the pipeline applies to the text: 4 reviewed editorial rules, 11 applications, enforced by `ledger_check.py`. |
| **Fingerprint** | The per-table content hash of the published database (`audit/dataset-fingerprint.json`), compared in CI. |
| **Dataset pin** | `dataset.lock.json`: the sggs-data commit and the database's sha256 and size this platform (and the app) serve. |
| **Data canary** | The scheduled check that production serves the pinned scripture byte for byte. |

## The engines and the platform

| Term | Meaning |
|---|---|
| **Waterfall** | The order `/api/search` tries its tiers: exact and cheap first, fuzzier only when nothing was found. |
| **Tier** | One stage of the waterfall, reported as the response's `mode`. |
| **roman_norm** | The phonetic fold that makes Roman search spelling-tolerant; byte-identical in three places (index, query, the Swift port). |
| **Seeker lexicon** | A curated table of words seekers actually type, mapped to a transliteration term or a theme. |
| **Variant index** | The precomputed romanisation-variant table the waterfall's seventh tier uses. |
| **Verification** | `/api/verify`: is this quotation really in the Granth? A verdict ladder from VERIFIED_EXACT to NOT_FOUND. |
| **Verdict** | The verification engine's answer: VERIFIED_EXACT, VERIFIED_PARTIAL, VERIFIED, PROBABLE, AMBIGUOUS or NOT_FOUND, with an optional Ang tag. |
| **Golden vectors** | `contract/*.ndjson` — recorded outputs that pin the Swift port to the Python source of truth and every deploy to the code. |
| **Golden contract** | The golden vectors plus `openapi.json`: the API's behaviour and shape, regenerated from real runs and enforced everywhere. |
| **Bounded context** | One of the five parts of the API — reader, search, verify, insights, knowledge — each declaring the tables it reads. |
| **Gateway** | The generated rewrite rules that send each `/api` prefix to the service that owns it (`gateway/routes.json` → `vercel.json`). |
| **X-Service** | The response header naming the service that answered: `all` for the single API, else the contexts it runs. |
| **Request id** | `X-Request-Id`: one id on every response and in the access log, so a request can be followed from the edge to the service. |
| **Cacheable route** | A route whose response depends only on the immutable database; served with a public cache policy and an ETag. |
| **One version number** | Web, API and the App Store binary always report the same X.Y.Z from the same platform commit. |
| **Vendor sync** | How the app takes a platform release: the contract copied at the tag and recorded in `vendor.lock.json` with a sha256 per file. |
| **Ledger (iOS)** | `ios/testflight-builds.json`: every upload with its version, build, commits, profile, channel and database hash. |
| **Launch integrity** | The app's fail-closed check that its bundled database hashes to the certified manifest before any scripture is shown. |
| **Poster** | One of the wiki's large step-through diagrams, generated from a declarative spec and pinned to the code it describes. |
| **Walkthrough** | The site's step-by-step reader for a poster: Next, Prev, Play, a caption and a link per step, a full-size lightbox. |
| **Verified stamp** | A page's `verified: {commit, date}`: the commit it was last read against; the docs gate requires it on process, engineering and architecture pages. |
| **Gate G3** | The scholar review still open before App Store submission: the Nitnem non-SGGS text and the Scripture 101 pages await it. |
