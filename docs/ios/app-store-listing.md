# Gurbani Soul — App Store listing (draft)

Everything App Store Connect asks for, drafted here so it is reviewed in a PR before it is typed
into the console. Character limits are Apple's. Update this file when the console changes, so the
repo stays the record.

## Brand architecture

**Gurbani Soul** is the customer-facing product brand (the app people download); **Algorythmos
Pty Ltd** is the company — legal owner, developer-account holder, IP and infrastructure owner —
credited as an *endorsed brand* ("Built by Algorythmos"). This decouples the product from the
consultancy so it can grow (or be sold/partnered) on its own identity. Note the two properties:
the iOS/Android **app** is *Gurbani Soul*; the scholarly **website/Knowledge Base** in this repo
stays *Sri Guru Granth Sahib Ji — Knowledge Base*. Inside the app, scripture is always cited by
its full name, *Sri Guru Granth Sahib Ji · Ang N* — "Gurbani Soul" names the app, never the text.

## Identity

| Field | Value | Limit |
|---|---|---|
| Name | `Gurbani Soul` | 30 |
| Fallbacks if taken | `Gurbani Soul: Verified` · `Gurbani Soul — Sikh` | 30 |
| On-device label (`CFBundleDisplayName`) | `Gurbani Soul` (12 chars — fits under the icon) | |
| Subtitle | `Gurbani Search, Nitnem & Hukam` (30) — keyword-dense; alt: `Nitnem, Hukamnama & Gurbani` (27) | 30 |
| Publisher / seller | `Algorythmos Pty Ltd` (App Store shows this as the developer name) | |
| Bundle ID | `org.sggs.app` (widget `org.sggs.app.widgets`) — internal, unchanged; users never see it | |
| SKU | `sggs-ios` — internal, unchanged | |
| Primary category | Reference (matches `LSApplicationCategoryType`) | |
| Secondary category | Education | |
| Primary language | English (U.K.) — pick once, keep | |
| Price | Free, no in-app purchases | |
| Age rating | 4+ (questionnaire: no objectionable content, no unrestricted web, no gambling, no contests) | |
| Copyright | `© 2026 ALGORYTHMOS PTY LTD` (the legal entity on the Apple Developer Program account) | |

> **Availability (verify before commit):** no App Store / Play app named "Gurbani Soul" and no
> "Gurbani Soul" company/trademark were found in a Sep-2026 search; `gurbanisoul.com/.app/.ai`
> did not resolve (apparently unregistered). Confirm store-name uniqueness in App Store Connect /
> Play Console and domain/TM status at a registrar and the official registers before purchase.

## Keywords (100, comma-separated, no spaces after commas)

`sikh,gurmukhi,punjabi,shabad,hukamnama,waheguru,sggs,granth,japji,kirtan,sikhism,bani,ang,guru`

(Do **not** repeat words already in the Name/Subtitle — Apple indexes those. So `gurbani`,
`nitnem`, `hukam`, `search` are deliberately omitted here.)

## Promotional text (170) — trust first (editable any time; NOT indexed for search)

> Every verse verbatim from Sri Guru Granth Sahib Ji, cited by Ang — never AI-invented. Search by word, sound or first letters. Daily Hukamnama, Nitnem and audio. Fully offline.

## Description (4,000)

> Gurbani Soul is the complete Sri Guru Granth Sahib Ji on your device — all 1,430 Angs, reproduced verbatim and cited by Ang. Nothing is paraphrased, normalised, or AI-generated: what you read is the scripture, exactly, verified every time the app launches. AI helps you search and navigate — it never writes Gurbani.
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
>
> Gurbani Soul is built by Algorythmos, an Australian AI and data-science company building trustworthy knowledge systems.

## Brand credit (About screen / footer / website)

- **Footer / credit line:** `Built by Algorythmos` (preferred over "Powered by" — warmer and more
  accountable for a scripture product where trust is the point).
- **About screen copy:** "Gurbani Soul is developed and maintained by Algorythmos, an Australian
  AI and data-science company building trustworthy knowledge systems. Every verse is reproduced
  verbatim from Sri Guru Granth Sahib Ji and cited by its Ang — nothing is paraphrased,
  normalised, or AI-generated."

## URLs

Target product domain is **`gurbanisoul.com`** (marketing), with `docs.gurbanisoul.com`
(sources / translation methodology / AI-safety — genuinely helps App Store review) and
`api.gurbanisoul.com` (backend). Until that domain is live, the existing Knowledge Base URLs
serve as the support/privacy targets; swap them once `gurbanisoul.com` is up.

| Field | Value | Status |
|---|---|---|
| Support URL | `https://gurbanisoul.com/support` (interim: `https://sggs-knowledge-base.vercel.app/support`) | interim built (`frontend/src/pages/support.astro`); repoint when the product domain is live |
| Marketing URL | `https://gurbanisoul.com` (interim: `https://sggs-knowledge-base.vercel.app`) | pending domain purchase |
| Privacy Policy URL | `https://gurbanisoul.com/privacy` (interim: `https://sggs-knowledge-base.vercel.app/privacy`) | interim built (`frontend/src/pages/privacy.astro`); repoint when live |

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
- Source Serif 4 typeface © Adobe, SIL Open Font License 1.1 (headings only;
  `ios/App/Resources/OFL-SourceSerif4.txt`).
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
> launch (More → About → Integrity shows the checks). The Gurmukhi typeface is Sant Lipi and the
> heading typeface is Source Serif 4 (both SIL Open Font License 1.1). No third-party translation is bundled in this build.
>
> Optional Nitnem reminders are local notifications only (scheduled on-device, no push, no server);
> they do not change the fully-offline promise. Notification permission is requested only when the
> user turns a reminder on.
>
> The optional reading Live Activity (default off) is driven entirely on-device with ActivityKit —
> no push and no server. It shows a bani title and a progress percentage only, never scripture text.
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
