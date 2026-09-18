# App Store screenshots

Masters live in `ios/AppStore/screenshots/<device>/` (git-ignored; multi-MB PNGs). The
`contact-sheet/` thumbnails are committed so the set can be reviewed in the repo.

| Set | Size | Source | Shots |
|---|---|---|---|
| `iphone-6.9` (mandatory) | 1320 × 2868 | iPhone 17 Pro Max simulator | Reader Ang 1 · Search "naam" · Hukam sheet · Raag Clock · Explore · Themes · Home Screen widgets |
| `iphone-6.5` (recommended) | 1284 × 2778 | derived from 6.9 (resample + centre crop) | same seven |
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

- **Widgets shot** (`07-widgets`): both widgets (Hukam verse, medium; Raag now, medium) added to
  the Home Screen through the widget gallery. Captured on the iPhone 17 simulator (1206 × 2622)
  and resampled to 1320 × 2868 (+9%, aspect ratios match to 0.1%) because the widget gallery
  needs an interactive session on a device the tooling can drive. On a **signed** build the
  widget reads the App Group snapshot the app writes at launch; an unsigned simulator build
  works too, but only after the app has been launched once with the widget already placed.
  Other simulator apps (Wassup, the XCUITest runner) are visible on that Home Screen — retake
  on a clean device for the release candidate.

Not yet captured: iPad Reader in landscape.
Retake after any visual change before the release candidate (the listing doc asks for RC shots).
