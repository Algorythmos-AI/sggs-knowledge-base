# Nitnem / Gutka Sahib — spec & frozen contract

The Nitnem feature (PR #43, v1.2.0) plus the premium pass (v1.3.0). Architecture: ADR-0006.

## Source policy
- **SGGS lines** are pointers into this project's verbatim corpus (`lines.id`), rendered from
  our text and cited "Sri Guru Granth Sahib Ji · Ang N". Proven by the reconcile attestation.
- **Non-SGGS lines** (Sri Dasam Granth, Ardaas) live in `extra_lines`: converted verbatim,
  labelled by source, no English, never an Ang, never FTS-indexed, never bookmarkable. They
  ship to the App Store only after `ios/Resources/NITNEM-REVIEW.md` records `REVIEWED: true`
  and `NitnemReview.extraTextReviewed` is flipped in the same commit; until then the app labels
  them "under scholarly review".
- **Numbering** (pauri / ashtapadi / salok / verse) is derived only from `BaniLine.markers`
  (bare Gurmukhi digits) or a Dasam line's trailing `॥N॥`, through `BaniOutline`. A strict
  validity gate returns `[]` rather than ever showing a guessed number. Numbers appear only in
  the Contents sheet, the position bar caption, and a quiet margin label — never in the verse.

## The Nitnem day
A Nitnem day rolls at **03:00** (`NitnemClock.dayKey(now − 3h)`): Kirtan Sohila read at 22:00 is
still complete at 00:30, and the night band never splits across a calendar midnight. `NitnemClock`
is the single source of "now" (honours `SGGS_CLOCK_NOW`) for the home, reader, widgets and reminders.

## Time bands (wall clock)
03:00–09:00 Amrit Vela · 09:00–17:00 Morning banis · 17:00–21:00 Evening · else Night. Bands only
ORDER the home; nothing is hidden.

## Persistence
- `nitnem-progress.json` (App Group `group.org.sggs`), **schema v1, never migrated**: per-bani
  `lastSeq`, `lastReadAt`, `completedDays`, and (v1.3.0, backward-compatible) `anchor` + `nLines`
  so a saved position survives a registry rebuild. A file written by a newer schema loads
  read-only and is never overwritten.
- The reading journey is computed on the fly from `completedDays` (no new file). My-Nitnem
  custom sets will go in a separate file in a later release.

## Frozen XCUITest identifiers & strings (do not change without updating the suite)
Tab / nav: `Nitnem`, each bani's `titleEn` (e.g. "Japji Sahib", "Jaap Sahib"), band title
"Amrit Vela". Rows/actions: `bani_<key>`, `Hukam`, `nitnemContinue`, `nitnemDone`, `nitnemNext`,
`baniBackToNitnem`, `baniOptions` (a Menu holding "Start again", "Contents", "Reading settings"),
`baniMarkComplete`, `baniPageBar`, `baniPosition` ("Part g of n" / "Line s of n"), `baniStanza`
("Pauri N of M"), `bandComplete`, `nitnemJourney`, `rehrasVariantPicker`. Reading settings: `gurmukhiSizeSlider`,
`readerLeadingPicker`, `readerTonePicker`, `translitToggle`, `englishToggle`. The Jaap reader must
contain the text "Sri Dasam Granth"; the Rehras row label must contain "Taksal" when that variant
is chosen. Env hooks: `SGGS_CLOCK_NOW`, `SGGS_UITEST`. Wiped prefs: `sggs_rehras_variant`,
`sggs_reader_tone`, `sggs_reader_leading`, `sggs_gurmukhi_size`, `sggs_focus_mode`, `sggs_translit`.

## Deep links & intents
`sggs://nitnem`, `sggs://bani/<key>`, "Read a bani" App Intent. Raag Clock is an Explore card. The Nitnem widget (kind `NitnemNow`) reads the App-Group snapshot + progress file, never the DB.

## Out of scope until v1.4.0
Hands-free auto-scroll, gentle reminders, Home-Screen quick actions, Spotlight bani entries,
"Continue my Nitnem" intent, My-Nitnem custom sets, Live Activity, online daily Hukamnama.
(The reading journey and the Nitnem widgets shipped in v1.3.0.)
