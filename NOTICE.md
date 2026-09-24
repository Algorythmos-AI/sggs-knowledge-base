# Licensing & Attribution Notice

**This repository is intended to remain PRIVATE.**

## The scripture (Gurmukhi corpus)
Sri Guru Granth Sahib Ji is sacred scripture. The Gurmukhi text in `corpus/` and `db/` was extracted, with documented deterministic corrections only, from a freely-circulated Unicode Gurmukhi edition ("Siri Guru Granth Sahib in Gurmukhi, with Index", 1,483 pp) supplied by the repository owner. The source PDF itself is not included. The text is treated with reverence: verbatim, always cited by Ang, never paraphrased. Handle accordingly.

## English translation layer
`translations` table: **English translation by Dr. Sant Singh Khalsa.** Full layer (58,039 lines) sourced from the **ShabadOS open database** (github.com/shabados/database, release 4.8.7 — the 151MB `database.sqlite` is gitignored, re-download to rebuild); earlier partial layer via the **BaniDB/GurbaniNow** public APIs. Translation used with attribution for personal, local, non-commercial study. **Do not redistribute publicly or commercially.** If this repository is ever made public, remove `pipeline/translations/`, the `translations` table from `db/sggs.sqlite`, and this layer's UI display first.

**Status (2026-09-24):** the translation source files are no longer tracked in this repository. They live in the private `Algorythmos-AI/sggs-source` repository (release `translations-en-v1`) and are restored for a rebuild with `scripts/data/fetch_translations.sh`, which verifies every file against `pipeline/translations.SHA256SUMS`. Earlier commits in this repository's history still contain them, and `db/sggs.sqlite` still carries the `translations` table; both are addressed by keeping this repository private and by the planned repository split.

### iOS app distribution (TestFlight / App Store)
TestFlight and App Store builds are *distribution*. The bundled iOS database (`personal` profile) embeds this translation layer, so `pipeline/check_release_license.sh` blocks such a build **until** a written distribution licence is recorded in `ios/Resources/TRANSLATION-LICENSE.md` (fields filled in and `LICENSED: true`). Without that, ship the Gurmukhi-only `public` profile (`pipeline/build_ios_db.py --profile public`). CI checks both directions.

## Code
The pipeline and web app code (everything in `pipeline/` and `webapp/` except data files) was built for the repository owner; treat as private unless separately licensed.

## Attribution line shown in the app
“English translation by Dr. Sant Singh Khalsa (sourced via BaniDB).”

## Nitnem bani layer (v1.2.0)

`banis` / `bani_lines` / `extra_lines` tables (pipeline/banis/, migration 002):

- **Bani membership** (which lines make up Japji Sahib, Rehras Sahib, Sukhmani Sahib, …
  and in what order) comes from the **ShabadOS open database** (github.com/shabados/database,
  release 4.8.7, `banis` + `bani_lines`). Every Sri Guru Granth Sahib Ji line is resolved to
  this project's own verbatim `lines.id` and rendered from **our** reconciled corpus; the
  ShabadOS text is used only as a match key, never displayed.
- **Non-SGGS text** — Sri Dasam Granth banis (Jaap Sahib, Tav-Prasad Savaiye, Benti Chaupai,
  Shabad Hazare Patshahi 10, the Dasam portions of Rehras Sahib) and Ardaas — is converted
  from the same ShabadOS dataset into `extra_lines`, **unfolded** (nukta, addak and udaat kept)
  and labelled by source. It is a separate layer: never mixed into `lines`, never indexed by
  FTS, never cited as an Ang, and it carries **no English translation**. It is **not** covered
  by the character-for-character reconcile proof; it ships in a public build only after the
  scholar review recorded in `ios/Resources/NITNEM-REVIEW.md` (`REVIEWED: true`).
- **Licence.** The ShabadOS repository publishes its code under the MIT licence and states
  that the contents of its `data` folder are free of known copyright restrictions (public
  domain). Record the exact licence text of the release used before any public wording
  claims "public domain"; provenance is recorded in `banis.source_label` and here.
  The Ardaas wording follows the SGPC Sikh Rehat Maryada.
- Required in-app attribution: "Bani ordering and Sri Dasam Granth / Ardaas text via the
  ShabadOS open database. Sri Guru Granth Sahib Ji text is this project's own verified corpus."

## Bundled in the iOS app (public build)

- **Sant Lipi** (Gurmukhi typeface) — © Shabad OS, SIL Open Font License 1.1; shipped as
  `ios/App/Resources/OFL.txt`.
- **Source Serif 4** (headings) — © Adobe, SIL Open Font License 1.1; shipped as
  `ios/App/Resources/OFL-SourceSerif4.txt`.
- **SQLite** — public domain (vendored amalgamation; provenance in
  `ios/Packages/GurbaniSearchKit/Sources/CSQLite/PROVENANCE.md`).
- **Bani ordering and Sri Dasam Granth / Ardaas text** — via the ShabadOS open database
  (release 4.8.7). Scholar review recorded in `ios/Resources/NITNEM-REVIEW.md`.

## Website imagery (gurbanisoul.com landing)

**Artwork.** The landing hero (`frontend/src/assets/landing/harmandir-sahib-sunset.jpg`) is an
original artistic rendering of Sri Harmandir Sahib at sunset, made for Gurbani Soul by
**Algorythmos** (no stock photography; no saroop in frame).

Photographs of Sri Harmandir Sahib on the Gurbani Soul landing page
(`frontend/src/assets/landing/`) are used under the
[Unsplash License](https://unsplash.com/license) — commercial use and modification permitted, no
permission required; attribution appreciated. We credit anyway, in the landing footer and here:

- **Salil** — https://unsplash.com/@salilkoli (Sri Harmandir Sahib at night)
- **UnKknown Traveller** — https://unsplash.com/@kushlav (by day)
- **Aryan Nikhil** — https://unsplash.com/@aryannikhil (reflected in the sarovar)
- **Ravindra Sharma** — https://unsplash.com/@ravindrasharma (golden at night)
- **Reubx** — https://unsplash.com/@reubx (across the sarovar)

Selection is limited to respectful devotional imagery (no saroop being handled, no identifiable
faces). Add a credit here and in the footer whenever a photo is added — see
`docs/website/README.md` → "Image policy".
