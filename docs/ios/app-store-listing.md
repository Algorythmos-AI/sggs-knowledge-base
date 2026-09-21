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
| Age rating | 4+ — see **Age rating questionnaire** below (the 2025 questionnaire is mandatory) | |
| Copyright | `© 2026 ALGORYTHMOS PTY LTD` (the legal entity on the Apple Developer Program account) | |

> **Availability (verify before commit):** no App Store / Play app named "Gurbani Soul" and no
> "Gurbani Soul" company/trademark were found in a Sep-2026 search; `gurbanisoul.com/.app/.ai`
> did not resolve (apparently unregistered). Confirm store-name uniqueness in App Store Connect /
> Play Console and domain/TM status at a registrar and the official registers before purchase.

## Keywords (100, comma-separated, no spaces after commas)

`sikh,gurmukhi,punjabi,shabad,hukamnama,waheguru,sggs,granth,japji,rehras,sohila,sikhism,bani,guru`

(Do **not** repeat words already in the Name/Subtitle — Apple indexes those. So `gurbani`,
`nitnem`, `hukam`, `search` are deliberately omitted here. Every keyword must name something the
app actually contains: `kirtan` was removed because the app has no audio — `rehras` and `sohila`
are banis it does contain. `webapp/tests/test_repo_gates.py` lints this section.)

## Promotional text (170) — trust first (editable any time; NOT indexed for search)

> Every verse verbatim from Sri Guru Granth Sahib Ji, cited by Ang — never AI-generated. Search by word, sound or first letters. Hukam, Nitnem, reminders. Fully offline.

## Description (4,000)

> Gurbani Soul is the complete Sri Guru Granth Sahib Ji on your device — all 1,430 Angs, reproduced verbatim and cited by Ang. Nothing is paraphrased, normalised, or AI-generated: what you read is the scripture, exactly, checked against a SHA-256 checksum when installed or updated.
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
> NITNEM
> • The daily banis by time of day, with your place kept in each one and a quiet record of the days you read.
> • Build your own Nitnem set, and choose the Rehras Sahib reading you follow.
> • Optional reminders at times you choose — scheduled on your device, never from a server.
> • An optional Live Activity shows your reading progress on the Lock Screen. It never shows a verse.
> • Nitnem also includes banis from Sri Dasam Granth and Ardaas, shown as a separate, clearly labelled layer — never presented as part of Sri Guru Granth Sahib Ji.
>
> HUKAM
> • Draw a complete Hukam unit any time.
>
> WIDGETS
> • Hukam, the current raag watch, and today's Nitnem on your Home Screen.
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
> • The text is reproduced character for character from the source edition. Its SHA-256 checksum is verified in full when the app is installed or updated, and re-checked whenever the bundled file changes; every launch confirms the file is unchanged and the structure is intact. Nothing is corrected, normalised or paraphrased.
>
> Works with Siri and Shortcuts: "Today's Hukam", "What raag is it now", "Read a bani", "Search Gurbani" — plus an "Open Ang" action in the Shortcuts app.
>
> Gurbani Soul is built by Algorythmos, an Australian company building trustworthy knowledge systems.

## Brand credit (About screen / footer / website)

- **Footer / credit line:** `Built by Algorythmos` (preferred over "Powered by" — warmer and more
  accountable for a scripture product where trust is the point).
- **About screen copy:** "Gurbani Soul is developed and maintained by Algorythmos, an Australian
  company building trustworthy knowledge systems. Every verse is reproduced
  verbatim from Sri Guru Granth Sahib Ji and cited by its Ang — nothing is paraphrased,
  normalised, or AI-generated."

## URLs

Target product domain is **`gurbanisoul.com`** (marketing), with `docs.gurbanisoul.com`
(sources / translation methodology / AI-safety — genuinely helps App Store review) and
`api.gurbanisoul.com` (backend). Until that domain is live, the existing Knowledge Base URLs
serve as the support/privacy targets; swap them once `gurbanisoul.com` is up.

**Enter only URLs that resolve today.** A Support or Privacy URL that 404s is a direct rejection
(2.1 / 5.1.1). `gurbanisoul.com` is registered but serves nothing yet, so the submission values are
the live Knowledge Base pages; the uptime workflow and the `@smoke` specs watch them.

| Field | Submit this | Later, once it serves these pages |
|---|---|---|
| Support URL | `https://sggs-knowledge-base.vercel.app/support` | `https://gurbanisoul.com/support` |
| Marketing URL | `https://sggs-knowledge-base.vercel.app` | `https://gurbanisoul.com` |
| Privacy Policy URL | `https://sggs-knowledge-base.vercel.app/privacy` | `https://gurbanisoul.com/privacy` |

The privacy page must stay true to the binary: no data collected, no network requests, location
on-device only, saved verses / settings / Nitnem progress stored locally, reminders as local
notifications (no push), an on-device Live Activity, no third-party SDKs.

## App Privacy (questionnaire)

- Do you or your third-party partners collect data from this app? **No.**
- Result: "Data Not Collected". This matches `PrivacyInfo.xcprivacy` (no tracking, no collected
  data types, accessed-API reasons `CA92.1` + `1C8F.1` (UserDefaults, including the App Group suite shared with the widgets) and `C617.1` (file timestamps) only).
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
- Nitnem: bani ordering and the Sri Dasam Granth / Ardaas text via the **ShabadOS open database**
  (release 4.8.7), shown as a separate labelled layer. `NOTICE.md` requires this in-app attribution,
  verbatim: "Bani ordering and Sri Dasam Granth / Ardaas text via the ShabadOS open database. Sri
  Guru Granth Sahib Ji text is this project's own verified corpus." **Owner gate H3:** record the
  exact licence text of that release in `NOTICE.md` before submission, and the publisher/edition of
  the source PDF (the scripture text is public; the PDF's index and typesetting are not used).
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
5. Nitnem (today's banis and a bani open in the reader).
6. Home Screen with the three widgets — a clean Home Screen, no other apps visible.
7. Themes grid or Lineage timeline.
8. iPad: Reader in landscape.

Store the source PNGs under `ios/AppStore/screenshots/<device>/` (add the directory to
`.gitignore` if the set exceeds a few MB; keep a small contact sheet in the repo).

## App Review Information

- Sign-in required: **No** (there are no accounts).
- Contact: first name, last name, **phone (required by App Store Connect)** and email of the
  maintainer (`skalaliya@gmail.com` is the security contact in `SECURITY.md`; use the same, or the
  monitored support alias once it exists).
- Attachment: none needed.

### Review notes

> This app is a fully offline reader and search tool for Sri Guru Granth Sahib Ji, the Sikh
> scripture. It bundles a roughly 100 MB SQLite database of the text and makes no network requests at all;
> no account or sign-in exists, so no demo credentials are needed.
> Airplane Mode is a valid way to test it.
>
> The Gurmukhi text is reproduced verbatim from the source edition. Its SHA-256 is verified in full on
> first launch after an install or update; later launches confirm the file is unchanged (size + modification
> date) and re-run the structural checks. Any failure is fail-closed — the app refuses to show scripture.
> More → About & credits → Integrity shows the checks. The Gurmukhi typeface is Sant Lipi and the
> heading typeface is Source Serif 4 (both SIL Open Font License 1.1). No third-party translation is bundled in this build.
>
> Nitnem (Nitnem tab) lists the daily banis. Banis from Sri Dasam Granth and Ardaas are included as
> a separate layer, labelled as such in the app and sourced from the ShabadOS open database; they
> are never presented as part of Sri Guru Granth Sahib Ji.
>
> Optional Nitnem reminders are local notifications only (scheduled on-device, no push, no server);
> they do not change the fully-offline promise. The standard notification permission prompt appears
> only when the user switches a reminder on (More → Reminders, under the Nitnem section); nothing is requested at launch.
>
> The optional reading Live Activity (default off) is driven entirely on-device with ActivityKit —
> no push and no server. It shows a bani title and a progress percentage only, never scripture text.
> To see it: More → turn on "Live Activity while reading", open any bani in Nitnem, stay about
> 20 seconds, then lock the device.
>
> Location: optional, used only by the Raag Clock's solar mode to compute local sunrise and
> sunset on the device; the value is rounded to about 1 km, never stored beyond that and never
> transmitted. The app works fully with location denied (manual entry is offered). To see it:
> Explore → Raag Clock. Solar is the default; with no stored location it shows the fixed clock and offers
> a "Use my location" button — the permission prompt appears only when that button is tapped.
>
> Widgets: three Home Screen widgets (Hukam verse, Raag now, Nitnem) read a small snapshot the app
> writes to its App Group (`group.org.sggs`). It stays on the device and is never transmitted; the only
> personal values in it are today's Nitnem progress and, if the reader enabled solar mode, their location
> rounded to about 1 km. Open the app once before adding them.
>
> URL scheme `sggs://` and App Intents ("Today's Hukam", "What raag is it now", "Read a bani",
> "Search Gurbani" as Siri phrases; "Open Ang" as a Shortcuts action) open screens inside the app only.
>
> Suggested path: launch → Reader (swipe to turn a page) → tap **Hukam** in the bar at the bottom of the
> Reader → Done → **Search** tab, type `waheguru` → tap a result to open the composition → **long-press**
> any verse → **Save** → **Nitnem** tab → open Japji Sahib → **More → About & credits** → Integrity.

## Age rating questionnaire

Apple's updated questionnaire (tiers 4+ / 9+ / 13+ / 16+ / 18+) is mandatory. Expected result **4+**.
Answer **None / No** to every content descriptor and capability: violence, sexual content, profanity,
horror, medical/treatment information, alcohol/tobacco/drugs, gambling and contests, user-generated
content, messaging/chat, advertising, unrestricted web access, in-app purchases, parental controls,
age assurance. Re-read the live form on submission day — answer what it asks, not this summary.

## EU Digital Services Act — trader status

Worldwide availability includes the EU, so trader status must be declared and **verified** or the app
is not distributed there. Algorythmos Pty Ltd is a trader. The verified **address, phone number and
email are displayed publicly** on EU product pages — decide which business phone and address to
publish before filling the form (App Store Connect → Business → Compliance).

## Accessibility Nutrition Labels

Optional. Declare a feature only after the hardware pass in `ios/App/Tests/UI/A11Y_CHECKLIST.md`
proves it on the release candidate: VoiceOver · Larger Text · Dark Interface · Differentiate Without
Color Alone · Sufficient Contrast (backed by `ThemeContrastTests` + `scripts/brand/contrast_report.py`)
· Reduced Motion (`MotionGate`). Do **not** declare Voice Control, Captions or Audio Descriptions.

## Availability, pricing and agreements

- **Territories:** all (owner decision 2026-09-20). Because that includes India, store metadata
  carries no "AI" wording except "never AI-generated" (see CLAUDE.md, brand section).
- **Price:** Free, no in-app purchases → only the free-apps agreement is needed; no banking or tax
  forms. Confirm nothing is pending under App Store Connect → Business.

## Version release

- Release option: **Manually release this version** (so the web release and the announcement
  align), with **7-day phased release** on. A phased release can be paused if a problem appears;
  there is no binary rollback on iOS — the fix is a new build (`docs/process/runbooks/`).
- "What's New" for 1.x: reuse the CHANGELOG section for the tag, trimmed to user-facing lines.
