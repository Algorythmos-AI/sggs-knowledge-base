# Licensing & Attribution Notice

**This repository is intended to remain PRIVATE.**

## The scripture (Gurmukhi corpus)
Sri Guru Granth Sahib Ji is sacred scripture. The Gurmukhi text in `corpus/` and `db/` was extracted, with documented deterministic corrections only, from a freely-circulated Unicode Gurmukhi edition ("Siri Guru Granth Sahib in Gurmukhi, with Index", 1,483 pp) supplied by the repository owner. The source PDF itself is not included. The text is treated with reverence: verbatim, always cited by Ang, never paraphrased. Handle accordingly.

## English translation layer
`translations` table: **English translation by Dr. Sant Singh Khalsa.** Full layer (58,039 lines) sourced from the **ShabadOS open database** (github.com/shabados/database, release 4.8.7 — the 151MB `database.sqlite` is gitignored, re-download to rebuild); earlier partial layer via the **BaniDB/GurbaniNow** public APIs. Translation used with attribution for personal, local, non-commercial study. **Do not redistribute publicly or commercially.** If this repository is ever made public, remove `pipeline/translations/`, the `translations` table from `db/sggs.sqlite`, and this layer's UI display first.

### iOS app distribution (TestFlight / App Store)
TestFlight and App Store builds are *distribution*. The bundled iOS database (`personal` profile) embeds this translation layer, so `pipeline/check_release_license.sh` blocks such a build **until** a written distribution licence is recorded in `ios/Resources/TRANSLATION-LICENSE.md` (fields filled in and `LICENSED: true`). Without that, ship the Gurmukhi-only `public` profile (`pipeline/build_ios_db.py --profile public`). CI checks both directions.

## Code
The pipeline and web app code (everything in `pipeline/` and `webapp/` except data files) was built for the repository owner; treat as private unless separately licensed.

## Attribution line shown in the app
“English translation by Dr. Sant Singh Khalsa (sourced via BaniDB).”
