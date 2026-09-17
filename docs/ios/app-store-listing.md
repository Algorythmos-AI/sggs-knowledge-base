# SGGS iOS — App Store listing (draft)

Everything App Store Connect asks for, drafted here so it is reviewed in a PR before it is typed
into the console. Character limits are Apple's. Update this file when the console changes, so the
repo stays the record.

## Identity

| Field | Value | Limit |
|---|---|---|
| Name | `Sri Guru Granth Sahib` | 30 |
| Fallbacks if taken | `SGGS — Guru Granth Sahib` · `Gurbani Reader — SGGS` | 30 |
| Subtitle | `Offline Gurbani reader & search` | 30 |
| Bundle ID | `org.sggs.app` (widget `org.sggs.app.widgets`) | |
| SKU | `sggs-ios` | |
| Primary category | Reference (matches `LSApplicationCategoryType`) | |
| Secondary category | Education | |
| Primary language | English (U.K.) — pick once, keep | |
| Price | Free, no in-app purchases | |
| Age rating | 4+ (questionnaire: no objectionable content, no unrestricted web, no gambling, no contests) | |
| Copyright | `© 2026 ALGORYTHMOS PTY LTD` (the legal entity on the Apple Developer Program account) | |

## Promotional text (170)

> The complete Sri Guru Granth Sahib Ji on your device: verbatim Gurmukhi, instant search by word, sound or first letters, daily Hukam, Raag Clock and widgets. No account. No network.

## Description (4,000)

> Sri Guru Granth Sahib Ji, all 1,430 Angs, entirely on your device.
>
> READ
> • The full Granth, verbatim, in a beautiful Gurmukhi typeface (Sant Lipi).
> • Turn pages, jump to any Ang, resume where you left off.
> • Every composition opens with its printed heading, and every verse is cited by Ang.
>
> SEARCH
> • Type Gurmukhi, or type how it sounds in Roman letters.
> • Search by first letters, the way Gurbani is traditionally recalled.
> • Explore by theme across the whole Granth.
>
> HUKAM
> • Draw a complete Hukam unit any time, and keep it on your Home Screen with the Hukam widget.
>
> RAAG CLOCK
> • See which raags belong to the current watch of the day, with an optional solar mode that uses sunrise and sunset for your location, computed on the device.
>
> EXPLORE
> • The contributors and their centuries, the 22 Vaars and their structure, and themes and their relationships across the text.
>
> PRIVATE BY DESIGN
> • No account. No network connection is ever made. No analytics, no tracking.
> • Your saved verses stay on your device (and in Spotlight, if you choose to save them).
> • Location, if you allow it, is rounded to about 1 km and never leaves the device.
>
> FAITHFUL BY CONSTRUCTION
> • The text is reproduced character for character from the source edition and is verified by the app every time it launches. Nothing is corrected, normalised or paraphrased.
>
> Works with Siri and Shortcuts: "Today's Hukam", "What raag is it now", "Search Gurbani", "Open Ang".

## Keywords (100, comma-separated, no spaces after commas)

`gurbani,sikh,granth,guru,hukam,hukamnama,gurmukhi,punjabi,raag,shabad,kirtan,japji,sggs,waheguru`

(Do not repeat words from the name or subtitle; Apple indexes those already.)

## URLs

| Field | Value | Status |
|---|---|---|
| Support URL | `https://sggs-knowledge-base.vercel.app/support` | built (`frontend/src/pages/support.astro`); live after the next release to `main` |
| Marketing URL | `https://sggs-knowledge-base.vercel.app` | live |
| Privacy Policy URL | `https://sggs-knowledge-base.vercel.app/privacy` | built (`frontend/src/pages/privacy.astro`); live after the next release to `main` |

Privacy policy content (one paragraph is enough, and must be true): the app collects no data,
makes no network requests, uses location only on-device for sunrise/sunset when enabled, stores
saved verses and settings locally, and has no third-party SDKs.

## App Privacy (questionnaire)

- Do you or your third-party partners collect data from this app? **No.**
- Result: "Data Not Collected". This matches `PrivacyInfo.xcprivacy` (no tracking, no collected
  data types, accessed-API reasons `CA92.1` UserDefaults and `C617.1` file timestamps only).
- Location is used but not collected: it never leaves the device and is not stored beyond the
  rounded value used for the clock. Say exactly this in the review notes.

## Export compliance

`ITSAppUsesNonExemptEncryption = false` is set in `Info.plist`, so the question is answered at
upload. The app uses no encryption beyond the OS (SHA-256 hashing for integrity is not encryption).

## Content rights

"Does your app contain, show, or access third-party content?" — **Yes**, and you have the rights:
- The Gurmukhi text of Sri Guru Granth Sahib Ji, reproduced verbatim from the source edition
  (public scripture; see `NOTICE.md`).
- Sant Lipi typeface © Shabad OS, SIL Open Font License 1.1 (`/fonts/OFL.txt` on the web,
  `ios/App/Resources/OFL.txt` in the app).
- SQLite (public domain), vendored.
- The English translation by Dr. Sant Singh Khalsa is **not** bundled in the public build. If a
  licence is granted later, add it here and in the credits.

## Screenshots

Required sets: iPhone 6.9" (mandatory), iPhone 6.5" (recommended), iPad 13" (mandatory since the
app supports iPad). Capture from the release-candidate build on real devices or the matching
simulator, light mode unless the frame is dark-mode themed, no "beta" or TestFlight UI visible.

Suggested order (first three are what most people see):
1. Reader on Ang 1 (Mool Mantar visible, page bar visible).
2. Search results for a Roman query, showing the Gurmukhi + transliteration rows.
3. Hukam sheet.
4. Raag Clock (dial + list).
5. Home Screen with both widgets.
6. Themes grid or Lineage timeline.
7. iPad: Reader in landscape.

Store the source PNGs under `ios/AppStore/screenshots/<device>/` (add the directory to
`.gitignore` if the set exceeds a few MB; keep a small contact sheet in the repo).

## App Review Information

- Sign-in required: **No** (there are no accounts).
- Contact: first name, last name, phone, email of the maintainer (`skalaliya@gmail.com` is the
  security contact in `SECURITY.md`; use the same).
- Attachment: none needed.

### Review notes

> This app is a fully offline reader and search tool for Sri Guru Granth Sahib Ji, the Sikh
> scripture. It bundles a 108 MB SQLite database of the text and makes no network requests at all;
> Airplane Mode is a valid way to test it.
>
> The Gurmukhi text is reproduced verbatim from the source edition and is verified by SHA-256 at
> launch (More → About → Integrity shows the checks). The typeface is Sant Lipi (SIL Open Font
> License 1.1). No third-party translation is bundled in this build.
>
> Location: optional, used only by the Raag Clock's solar mode to compute local sunrise and
> sunset on the device; the value is rounded to about 1 km, never stored beyond that and never
> transmitted. The app works fully with location denied (manual entry is offered).
>
> Widgets: two Home Screen widgets read a small snapshot the app writes to its App Group
> (`group.org.sggs`); they contain no personal data.
>
> URL scheme `sggs://` and App Intents ("Today's Hukam", "What raag is it now", "Search Gurbani",
> "Open Ang") open screens inside the app only.
>
> Suggested path: launch → Reader (turn a page) → Search tab, type `waheguru` → open a result →
> tap Hukam → Save → More → About.

## Version release

- Release option: **Manually release this version** (so the web release and the announcement
  align), with **phased release** on.
- "What's New" for 1.x: reuse the CHANGELOG section for the tag, trimmed to user-facing lines.
