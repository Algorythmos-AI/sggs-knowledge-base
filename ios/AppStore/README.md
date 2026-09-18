# App Store screenshots

Masters live in `ios/AppStore/screenshots/<device>/` (git-ignored; multi-MB PNGs). The
`contact-sheet/` thumbnails are committed so the set can be reviewed in the repo.

| Set | Size | Source | Shots |
|---|---|---|---|
| `iphone-6.9` (mandatory) | 1320 × 2868 | iPhone 17 Pro Max simulator | Reader Ang 1 · Search "naam" · Hukam sheet · Raag Clock · Explore · Themes |
| `iphone-6.5` (recommended) | 1284 × 2778 | derived from 6.9 (resample + centre crop) | same six |
| `ipad-13` (mandatory) | 2064 × 2752 | iPad Pro 13" simulator | Reader · Search · Hukam · Clock · Themes |

How they were made (2026-09-18, `integration` after PRs #33/#34):

- **Public profile only.** The shots come from the Gurmukhi-only `public` DB profile (the
  only profile eligible for the store), never the personal build that bundles the English layer.
  The public DB + its manifest were swapped into a throwaway copy of the built `.app`; the app's
  own integrity check passed on it.
- Light mode, clean status bar (`simctl status_bar override --time 9:41`), fresh install so the
  default Soul Gold accent shows.
- Raag Clock pinned to 9:41 with the test-only `SGGS_CLOCK_NOW=581` launch env (otherwise the
  shot shows whatever pahar it is when captured).
- Deep links used to land screens: `sggs://ang/1`, `sggs://search?q=naam`.

Not yet captured: Home Screen with both widgets; iPad Reader in landscape.
Retake after any visual change before the release candidate (the listing doc asks for RC shots).
