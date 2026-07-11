# Raag Timing Knowledge Layer + Bani Forms Metadata (v2.12.0)

A **metadata/scholarship layer** about the 31 raags and the composition forms of
Sri Guru Granth Sahib Ji. It never touches scripture: all data lives in NEW
SQLite tables that reference existing ones read-only, and every write step
proves the pre-existing tables byte-identical against a committed baseline.

---

## The scholarly note: claims, not facts

Raag timing is **living tradition, not settled fact**. Gurmat Sangeet lineages,
community charts, and the Hindustani samay convention genuinely disagree about
when several raags belong. This layer therefore models timing as
**attributed claims**:

- every row in `raag_timing_claims` cites a row in `timing_sources` (schema-enforced `NOT NULL`);
- divergent placements coexist as separate rows — `claim_type='variant'`, `confidence='disputed'`;
- **nothing is adjudicated or merged.** The UI shows disagreements side-by-side
  with citations (`/divergence`), and ghosted variant markers on the clock. A
  reader should leave knowing *who says what*, not a false consensus.
- provenance is honest: sources that could not be tied to a verifiable
  publication are labeled "(compiled)" with notes saying exactly where they
  came from. **No invented citations.**

Confidence semantics: `consistent` (sources agree), `majority` (the dominant
convention where variants exist), `disputed` (recorded disagreement).

**Pahar convention:** pahars are stored 1–8 continuous from 6 AM
(pahar 1 = 06:00–09:00 … pahar 8 = 03:00–06:00 amrit vela) and rendered as
"Nth pahar of day/night". **Pahar 7 (00:00–03:00) deliberately has no raags** —
the deep night is left in silence; the UI displays that absence as content.
Traditionally pahars were **solar** (4 equal watches of daylight, 4 of night);
the app offers both a fixed-clock and a solar mode (local NOAA sunrise
calculation, no external API, location never leaves the device).

## Guardrails and how they are mechanically enforced

| Guardrail | Enforcement |
|---|---|
| Zero DDL/DML on scripture-bearing tables | `apply_migration.py` whitelists every SQL statement (CREATE TABLE/INDEX on the 7 new tables only; DROP of those only in rollback) and aborts otherwise |
| Integrity proven, not assumed | `audit/scripture-baseline.json` (committed at Step 0, before any migration code) records row count + data SHA-256 + schema SHA-256 of **all 46 pre-existing tables** plus DB/corpus file hashes; every writer verifies it **before and after**; `guard_scripture.py` is the standing gate |
| Transactional migrations | statements run individually inside `BEGIN IMMEDIATE`; any error → `ROLLBACK` + report; rollback script drops only the new tables and is *proven* by a post-rollback baseline pass |
| Forms never guessed | `derive_bani_forms.py` records a form/genre **only when the composition's own heading states it** (NFC-normalized match on the verbatim header line); unknowns stay NULL and are reported |
| No scripture-presentation changes | the reader chip is metadata in the context bar, never inline with Gurbani; all API text passes the existing `esc()` invariant |

## Schema (all NEW tables; migration `001_timing_layer`)

- **`timing_sources`** `(id, name UNIQUE, tradition CHECK gurmat_sangeet|hindustani, url, notes)`
- **`raag_timing_claims`** `(id, raag_name → raags(name), claim_type CHECK primary|variant|seasonal|ceremonial, pahar CHECK 1–8, time_start, time_end, season, occasion, source_id → timing_sources NOT NULL, confidence CHECK consistent|majority|disputed, notes)`
  with unique expression index `(raag_name, claim_type, source_id, COALESCE(pahar,0), COALESCE(occasion,''))` — SQLite treats NULLs as distinct in plain UNIQUE, so the COALESCE form is what makes `INSERT OR IGNORE` seeding idempotent.
- **`shabd_raag_map`** `(comp_id PK, raag_name → raags(name), first_ang, first_line_id)` — the derived, materialized shabd→raag junction (5,380 compositions; the `lines` table links raag by name string, and there is no `shabds` table — compositions are groups of lines sharing `comp_id`).
- **`shabd_musical_markers`** `(comp_id PK, ghar CHECK 1–17, partaal, has_rahao, has_rahao_dooja, dhunni, jati, source_label)`
- **`shabd_structural_form`** `(comp_id PK, form CHECK pada|ashtpadi|solahe|chhant|vaar|pauri|salok, pada_count, source_label)`
- **`shabd_poetic_genre`** `(comp_id PK, genre CHECK barah_maha|patti|bavan_akhri|thitti|ruti|din_raini|pahare|alahunian|ghorian|karhale|vanjara|kuchaji|suchaji|gunvanti|sadd|anjulian|birhare|gatha|funhe|chaubole|savaiye|dakhne|mundavani, source_label)`
- **`timing_migrations`** — migration bookkeeping.

**Why the raag key is Gurmukhi `raags.name`:** the existing `raags` table has a
TEXT (Gurmukhi) primary key and no integer id, and `lines.raag` carries the
same name string. Referencing `raags(name)` needs no ALTER of any existing
table. Seed data written with anglicized names resolves through `raags.roman`
plus an explicit alias table; anything unresolved hard-fails with zero writes.

**Design notes from the verified text:**
- `comp_type` is substring-derived and demonstrably unreliable (documented in
  CLAUDE.md; e.g. ordinary Sireeraag M3 shabads carry `comp_type='ਅਨੰਦੁ'` from
  verse text, and the Ang-74 Pahare composition is mislabeled `ਗੁਣਵੰਤੀ`).
  Derivation therefore trusts only **title-like headings** (containing
  ਮਹਲਾ/ਮਹਲੇ/ਮਃ/ਰਾਗੁ/ਬਾਣੀ/ਕੀ ਵਾਰ, starting with a raag name, or consisting
  purely of heading vocabulary like `ਪਉੜੀ ॥`); `comp_type` survives only as a
  hint inside `source_label`.
- **No `lavan` genre**: the word ਲਾਵ never appears in a heading — only in the
  verse text of the Soohee chhant (Ang 773–774). Headings-only means Lavan
  exists solely as the ceremonial claim (Soohee → Anand Karaj).
- ਦਖਣੀ (a style/jati marker, e.g. ਵਡਹੰਸੁ ਦਖਣੀ) is **not** the genre `dakhne` —
  the dakhne saloks are ਡਖਣੇ/ਡਖਣਾ (Maru ki Vaar M5).
- A bare `ਮਃ ੫ ॥` heading states the author, not the form, so interleaved vaar
  saloks without the ਸਲੋਕ word stay form-NULL — context is never guessed.
- Dhunni detection matches the vaar's heading **or** a short dedicated dhunni
  line among the composition's first lines (Ramkali ki Vaar M3 carries
  ਜੋਧੈ ਵੀਰੈ ਪੂਰਬਾਣੀ ਕੀ ਧੁਨੀ on line 2). Exactly the **9 traditional dhunni
  vaars** are captured. The Raag-Mala line ਸੋਰਠਿ ਗੋਂਡ ਮਲਾਰੀ ਧੁਨੀ (Ang 1430) is
  correctly *not* a dhunni.

Current derived coverage (all from headings): 5,380/5,380 compositions mapped;
747 with ghar; 17 partaal; 2,527 with rahao; 25 with rahao dooja; 9 dhunni
vaars; 10 jati marks; 1,294 heading-stated structural forms; 57 poetic-genre
compositions.

## API (serve.py, additive; degrades to `{"available": false}`)

- `GET /api/timing/clock` — full claim set grouped by type, joined to sources and `raags(roman, first_ang)`; cached.
- `GET /api/timing/raag?name=<roman|gurmukhi>` — one raag's claims (reader chip).
- `GET /api/timing/divergence` — raags where **different sources** disagree (a same-source multi-pahar extension like Bilaval 1st→2nd is not divergence).
- `GET /api/forms?comp_id=N` — the three form dimensions + raag map for one composition.
- `/api/meta` gains `timing_available`.

## UI

- **`/raag-clock`** — SVG 24-hour dial: 8 pahar arcs (day warm / night indigo,
  themed via CSS vars), current pahar glowing + live hand, variants ghosted +
  dashed + †, pahar 7 dark with its explanatory note, outer seasonal ring
  (Basant/Malhar). Keyboard-focusable markers with a cited tooltip card; a
  full claims table twin for screen readers. Plus the "What raag is it now?"
  widget: fixed/solar modes, next-pahar countdown, tappable raag chips into
  the reader.
- **`/divergence`** — the sign-off table: side-by-side conflicting claims with
  tradition + confidence badges and citations; stacks to cards on mobile.
- **Reader chip** — small dashed metadata chip beside the raag context chip
  ("🕐 4th pahar of day (3–6 PM) · variant: 1st pahar of night†"), linking to
  the clock; toggleable via the toolbar "timing" switch (`show_timing`,
  default ON, same mechanism as the transliteration toggle). Never inline
  with Gurbani; a fetch failure just means no chip.
- Full analytics-chart accessibility remains a separately scoped task (per CLAUDE.md).

## Runbook

```bash
# one-command apply to db/sggs.sqlite (server must be stopped):
bash pipeline/timing/apply_all.sh          # migrate → seed → derive → guard → stamp MANIFEST

# individual steps (each verifies the baseline before AND after):
python3 pipeline/timing/apply_migration.py [--db PATH]
python3 pipeline/timing/seed_timing.py     [--db PATH] [--dry-run]
python3 pipeline/timing/derive_bani_forms.py [--db PATH] [--refresh]
python3 pipeline/timing/guard_scripture.py   # the standing integrity gate
python3 pipeline/timing/test_timing_layer.py # schema/claims/forms gate (throwaway copy)
node frontend/scripts/test-pahar.mjs         # pahar math gate (47 cases)

# rollback (drops ONLY the 7 new tables, then re-proves the baseline):
python3 pipeline/timing/apply_migration.py --rollback

# after a full pipeline rebuild: stage 7b re-applies the layer to the temp DB
# automatically (with --skip-baseline, sanctioned there because reconcile.py +
# golden_test.py already gate the fresh build). Then re-baseline consciously:
python3 pipeline/timing/step0_baseline.py --force   # and commit audit/scripture-baseline.json

# restart the server afterwards — serve.py holds the DB immutable.
```

**MANIFEST policy** (user-approved): `db_sha256` is a whole-file freshness
stamp and legitimately changes when additive tables land; it is re-stamped by
`stamp_manifest.py` only after the guard passes. The committed per-table
baseline (`audit/scripture-baseline.json`, `MANIFEST.scripture_baseline`) is
the scripture invariant of record.

**Backups:** Step 0 wrote a checksum-verified copy to
`db/backups/sggs-pre-timing-<stamp>.sqlite` (gitignored). Never operate
without it.
