# Runbook: support inbox

The address in the App Store listing, on `/support` and in the EU trader declaration is public.
Use a dedicated, monitored alias rather than a personal mailbox, and keep all three in step.

## Targets
- Acknowledge within **2 working days**; scripture-text reports the same day if at all possible.
- Reply to App Store reviews that describe a defect; never argue, never ask for a rating change.

## Triage
| The message says | Do |
|---|---|
| **"A word / line is wrong"** | Thank them; ask for the Ang, the line, and a photo of their printed page. Open an issue with the `scripture-fidelity` template. **Never edit the text.** A person compares the report with the source edition and the printed Bir; most reports are an edition difference, the traditional-saroop rendering, or transliteration (which is a reading aid, not scripture). Only a confirmed, reviewed correction is ever logged — in sggs-data's editorial ledger — and reaches the app and site as a new dataset release. |
| "Scripture integrity check failed" | Ask for the device, iOS version and the screen in More → About → Integrity. Reinstalling fixes a corrupted download. More than one report for the same build → halt criteria in the app repository's `app-store-submission` runbook. |
| Crash / freeze | Ask for device, iOS version, app version (More → About) and what they were doing. If they are willing, the diagnostics the app keeps locally can be shared from About. Check Xcode Organizer for the same signature. |
| Reminders do not appear | Settings → Notifications → Gurbani Soul must allow alerts; Focus / Sleep can silence them by design. Builds up to 1.3.0 delivered reminders silently — turning the reminder off and on again raises the real permission prompt. |
| Widgets are empty | Open the app once, open a Hukam, wait a minute; then remove and re-add the widget. |
| "Why is there no English?" | The translation's licence does not yet cover App Store distribution; it will arrive as a separate, labelled layer if that changes. See `/support`. |
| A request about a feature or a bani | Log it as an issue; do not promise dates. |
| Anything about another person's data | The app collects nothing and has no accounts — say so, and point to `/privacy`. |

## Tone
Plain, brief, respectful. Refer to the scripture as **Sri Guru Granth Sahib Ji**. Never describe the
app's search as "AI", and never suggest the app generates or interprets Gurbani.
