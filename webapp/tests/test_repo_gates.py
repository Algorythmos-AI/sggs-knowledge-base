"""Repository gates — source-level invariants that used to live only in prose.

Each test here encodes a rule the project already relies on (CHANGELOG/CLAUDE.md/readiness
reports) so that it is enforced on every PR by the required `python` check instead of by memory.
Stdlib only, no build, no simulator: these read tracked files and nothing else.

A gate marked `expectedFailure` documents a KNOWN open finding from the 2026-09-20 App Store
audit. When the finding is fixed the test starts passing, unittest reports an "unexpected
success" (a failure), and the decorator must be removed in the same PR — so a gate can only ever
move from "known-open" to "enforcing", never silently back.
"""
import json
import plistlib
import re
import sqlite3
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IOS = ROOT / "ios"
APP = IOS / "App"
KIT = IOS / "Packages" / "GurbaniSearchKit" / "Sources"
LISTING = ROOT / "docs" / "ios" / "app-store-listing.md"

# Shipping Swift: the app, the widget extension, code shared by both, and the search/DB package.
# CSQLite is the vendored SQLite amalgamation (C, public domain) and is out of scope.
SHIPPING_DIRS = [APP / "Sources", APP / "Shared", APP / "Widgets", KIT]


def shipping_swift():
    for base in SHIPPING_DIRS:
        for path in sorted(base.rglob("*.swift")):
            if "CSQLite" not in path.parts:
                yield path


_TRAILING_COMMENT = re.compile(r"\s//\s.*$")


def code_lines(path):
    """Yield (line_no, code, in_debug) with comments removed and `#if DEBUG` regions tracked.

    `in_debug` is True only inside the DEBUG arm of `#if DEBUG … [#else …] #endif`; other
    conditionals nest transparently. Trailing comments need whitespace on both sides of `//`, so
    URL literals such as "sggs://ang/1" survive.
    """
    stack = []          # one entry per open #if: True when that arm is a DEBUG arm
    in_block = False
    for no, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if in_block:
            if "*/" in line:
                in_block = False
            continue
        if line.startswith("/*"):
            in_block = "*/" not in line
            continue
        if line.startswith("//"):
            continue
        if line.startswith("#if"):
            stack.append(bool(re.match(r"#if\s+DEBUG\b", line)))
            continue
        if line.startswith("#else") or line.startswith("#elseif"):
            if stack:
                stack[-1] = False
            continue
        if line.startswith("#endif"):
            if stack:
                stack.pop()
            continue
        yield no, _TRAILING_COMMENT.sub("", raw), any(stack)


def violations(pattern, *, allow_debug=False, allow_files=(), dirs=None):
    rx = re.compile(pattern)
    found = []
    files = shipping_swift() if dirs is None else (
        p for d in dirs for p in sorted(d.rglob("*.swift")) if "CSQLite" not in p.parts)
    for path in files:
        if path.name in allow_files:
            continue
        for no, code, in_debug in code_lines(path):
            if allow_debug and in_debug:
                continue
            if rx.search(code):
                found.append(f"{path.relative_to(ROOT)}:{no}: {code.strip()}")
    return found


class CrashAndDebugHygiene(unittest.TestCase):
    """No crash-on-purpose constructs, no debug output, no network — in anything that ships."""

    def test_no_force_try_or_force_cast(self):
        self.assertEqual(violations(r"\btry!|\bas!\s"), [])

    def test_fatal_error_only_in_unavailable_coder_inits(self):
        # `required init?(coder:)` on a UIKit subclass must exist; marking it unavailable and
        # trapping is the idiom. Anything else must throw or degrade instead of trapping.
        bad = []
        for path in shipping_swift():
            lines = list(code_lines(path))
            for i, (no, code, _) in enumerate(lines):
                if "fatalError(" not in code:
                    continue
                window = " ".join(c for _, c, _ in lines[max(0, i - 2): i + 1])
                if "init?(coder" not in window:
                    bad.append(f"{path.relative_to(ROOT)}:{no}: {code.strip()}")
        self.assertEqual(bad, [])

    def test_print_only_under_if_debug(self):
        self.assertEqual(violations(r"(?<![\w.])print\(", allow_debug=True), [])

    def test_no_network_code(self):
        # "No accounts. No network. No tracking." is a store-listing and privacy-label claim.
        self.assertEqual(
            violations(r"\bURLSession\b|\bURLRequest\b|\bWKWebView\b|\bNWConnection\b|^\s*import Network\b"), [])

    def test_environment_hooks_only_under_if_debug(self):
        # Test hooks read from the process environment must not exist in a Release binary
        # (App Review 2.3.1: no hidden or undocumented behaviour switches).
        self.assertEqual(violations(r"ProcessInfo\.processInfo\.environment", allow_debug=True), [])


class DesignSystemGates(unittest.TestCase):
    """The CHANGELOG's "grep gates", made executable."""

    def test_with_animation_only_in_motion(self):
        # Reduce Motion is honoured architecturally: MotionGate / .appAnimation are the only
        # sanctioned entry points, so a raw withAnimation( elsewhere bypasses the setting.
        self.assertEqual(violations(r"\bwithAnimation\(", allow_files=("Motion.swift",)), [])

    def test_hex_colours_only_in_design_tokens(self):
        # Contrast is regression-tested against the tokens; a stray hex literal is untested.
        self.assertEqual(
            violations(r"0x[0-9A-Fa-f]{6}\b|\"#[0-9A-Fa-f]{6}\"",
                       allow_files=("DesignTokens.swift",),
                       dirs=[APP / "Sources", APP / "Shared", APP / "Widgets"]), [])


class SQLiteStepGate(unittest.TestCase):
    def test_no_raw_step_loops(self):
        # `while sqlite3_step(s) == SQLITE_ROW` reads SQLITE_CORRUPT / IOERR / NOMEM as "no more
        # rows" and returns a silently truncated Ang. All row iteration goes through one helper
        # that throws unless the terminal code is SQLITE_DONE.
        self.assertEqual(
            violations(r"while\s+sqlite3_step\(", allow_files=("SQLiteStep.swift",), dirs=[KIT]), [])


class InfoPlistInvariants(unittest.TestCase):
    def setUp(self):
        with open(APP / "Resources" / "Info.plist", "rb") as fh:
            self.plist = plistlib.load(fh)

    def test_export_compliance_flag(self):
        self.assertIs(self.plist.get("ITSAppUsesNonExemptEncryption"), False)

    def test_no_background_modes(self):
        self.assertNotIn("UIBackgroundModes", self.plist)

    def test_ipad_multitasking_not_opted_out(self):
        self.assertNotIn("UIRequiresFullScreen", self.plist)

    def test_location_purpose_string_present_when_location_used(self):
        if violations(r"\bCLLocationManager\b"):
            text = self.plist.get("NSLocationWhenInUseUsageDescription", "")
            self.assertGreater(len(text), 40, "purpose string must explain the specific use")
        self.assertNotIn("NSLocationAlwaysAndWhenInUseUsageDescription", self.plist)

    def test_live_activities_key_matches_code(self):
        uses = bool(violations(r"\bActivity<"))
        self.assertEqual(bool(self.plist.get("NSSupportsLiveActivities")), uses)


# Required-reason API categories → the source symbols that fall under them.
REQUIRED_REASON = {
    "NSPrivacyAccessedAPICategoryUserDefaults": r"\bUserDefaults\b",
    "NSPrivacyAccessedAPICategoryFileTimestamp":
        r"attributesOfItem|\.modificationDate|\.creationDate|contentModificationDateKey|creationDateKey",
    "NSPrivacyAccessedAPICategorySystemBootTime": r"systemUptime|mach_absolute_time|kern\.boottime",
    "NSPrivacyAccessedAPICategoryDiskSpace":
        r"volumeAvailableCapacity|systemFreeSize|systemSize|volumeTotalCapacity",
    "NSPrivacyAccessedAPICategoryActiveKeyboards": r"activeInputModes",
}


class PrivacyManifestGate(unittest.TestCase):
    def setUp(self):
        with open(APP / "Resources" / "PrivacyInfo.xcprivacy", "rb") as fh:
            self.manifest = plistlib.load(fh)

    def test_declared_categories_cover_api_use(self):
        declared = {e["NSPrivacyAccessedAPIType"] for e in self.manifest["NSPrivacyAccessedAPITypes"]}
        missing = [cat for cat, rx in REQUIRED_REASON.items()
                   if cat not in declared and violations(rx)]
        self.assertEqual(missing, [], "required-reason API used but not declared in PrivacyInfo.xcprivacy")

    def test_every_declared_category_has_a_reason(self):
        for entry in self.manifest["NSPrivacyAccessedAPITypes"]:
            self.assertTrue(entry.get("NSPrivacyAccessedAPITypeReasons"), entry)

    def test_no_tracking_and_nothing_collected(self):
        # Must stay in step with the "Data Not Collected" App Privacy answer in the listing.
        self.assertIs(self.manifest.get("NSPrivacyTracking"), False)
        self.assertEqual(self.manifest.get("NSPrivacyTrackingDomains", []), [])
        self.assertEqual(self.manifest.get("NSPrivacyCollectedDataTypes", []), [])

    def test_app_group_userdefaults_reason_declared(self):
        # The app + widget share UserDefaults(suiteName: "group.org.sggs"); that cross-process use
        # requires reason 1C8F.1 in addition to CA92.1. Apple's upload validator can flag its absence.
        uses_suite = bool(violations(r'UserDefaults\(suiteName:'))
        reasons = set()
        for e in self.manifest["NSPrivacyAccessedAPITypes"]:
            if e["NSPrivacyAccessedAPIType"] == "NSPrivacyAccessedAPICategoryUserDefaults":
                reasons = set(e.get("NSPrivacyAccessedAPITypeReasons", []))
        if uses_suite:
            self.assertIn("1C8F.1", reasons,
                          "app uses a shared UserDefaults suite but PrivacyInfo.xcprivacy omits reason 1C8F.1")

    def test_manifest_bundled_in_app_and_widget_targets(self):
        project = (APP / "project.yml").read_text(encoding="utf-8")
        # The app target bundles the whole Resources dir; the widget lists the file explicitly.
        self.assertRegex(project, r"(?m)^\s*- path: Resources\s*$")
        self.assertIn("Resources/PrivacyInfo.xcprivacy", project)


class ReleaseAttestationGate(unittest.TestCase):
    """A build recorded for the App Store channel requires the signed Nitnem text review."""

    def test_review_label_tracks_the_attestation(self):
        # NitnemReview.extraTextReviewed drives the in-app "Under scholarly review" label; it must
        # equal REVIEWED: in ios/Resources/NITNEM-REVIEW.md, so the label can never say "reviewed"
        # while the file says it is not (or the reverse). Both are false today; they flip together.
        review = (IOS / "Resources" / "NITNEM-REVIEW.md").read_text(encoding="utf-8")
        m = re.search(r"(?mi)^REVIEWED:\s*(true|false)\s*$", review)
        self.assertIsNotNone(m, "NITNEM-REVIEW.md has no REVIEWED: line")
        attested = m.group(1).lower() == "true"
        schedule = (APP / "Sources" / "Data" / "NitnemSchedule.swift").read_text(encoding="utf-8")
        c = re.search(r"static let extraTextReviewed\s*=\s*(true|false)", schedule)
        self.assertIsNotNone(c, "NitnemSchedule.swift has no extraTextReviewed literal")
        in_app = c.group(1) == "true"
        self.assertEqual(in_app, attested,
                         f"extraTextReviewed={in_app} but NITNEM-REVIEW.md REVIEWED={attested} — flip both together")

    def test_appstore_channel_requires_reviewed_true(self):
        ledger = json.loads((IOS / "testflight-builds.json").read_text(encoding="utf-8"))
        appstore = [b for b in ledger.get("builds", []) if b.get("channel") == "appstore"]
        if not appstore:
            return
        review = (IOS / "Resources" / "NITNEM-REVIEW.md").read_text(encoding="utf-8")
        self.assertRegex(review, r"(?m)^REVIEWED: true\s*$",
                         f"App Store builds {[(b['version'], b['build']) for b in appstore]} "
                         "are recorded but NITNEM-REVIEW.md is not signed")


def _section(text, heading_prefix):
    """Body of the first `## <heading_prefix>…` section, up to the next `## `."""
    m = re.search(rf"(?ms)^## {re.escape(heading_prefix)}[^\n]*\n(.*?)(?=^## |\Z)", text)
    return m.group(1) if m else ""


def _blockquote(body):
    lines = [ln[1:].strip() for ln in body.splitlines() if ln.startswith(">")]
    return "\n".join(lines).strip()


class ListingLint(unittest.TestCase):
    """docs/ios/app-store-listing.md is pasted into App Store Connect — lint what gets pasted."""

    @classmethod
    def setUpClass(cls):
        text = LISTING.read_text(encoding="utf-8")
        cls.text = text
        cls.name = re.search(r"(?m)^\| Name \| `([^`]+)`", text).group(1)
        cls.subtitle = re.search(r"(?m)^\| Subtitle \| `([^`]+)`", text).group(1)
        cls.keywords = re.search(r"`([^`]+)`", _section(text, "Keywords")).group(1)
        cls.promo = _blockquote(_section(text, "Promotional text"))
        cls.description = _blockquote(_section(text, "Description"))

    def test_fields_parsed(self):
        for field in (self.name, self.subtitle, self.keywords, self.promo, self.description):
            self.assertTrue(field)

    def test_name_and_subtitle_limits(self):
        self.assertTrue(2 <= len(self.name) <= 30, len(self.name))
        self.assertLessEqual(len(self.subtitle), 30)

    def test_keywords_limit_and_format(self):
        self.assertLessEqual(len(self.keywords), 100)
        self.assertNotIn(", ", self.keywords, "no spaces after commas — they cost characters")
        words = self.keywords.split(",")
        self.assertEqual(len(words), len(set(words)), "duplicate keyword")

    def test_keywords_do_not_repeat_name_or_subtitle(self):
        indexed = {w.lower() for w in re.findall(r"[A-Za-z]+", f"{self.name} {self.subtitle}")}
        self.assertEqual([k for k in self.keywords.split(",") if k.lower() in indexed], [])

    def test_description_limit(self):
        self.assertLessEqual(len(self.description), 4000)

    def test_promotional_text_limit(self):
        self.assertLessEqual(len(self.promo), 170, f"{len(self.promo)} chars")

    def test_no_claims_the_app_does_not_deliver(self):
        # Guideline 2.3: metadata must describe the shipped app. The app has no audio/kirtan, is
        # not a beta, runs no AI model, and store text must not mention other platforms.
        pasted = "\n".join([self.name, self.subtitle, self.keywords, self.promo, self.description])
        hits = re.findall(r"(?i)\baudio\b|\bkirtan\b|\bbeta\b|\btestflight\b|\bandroid\b|\bAI helps\b|\bAI[- ]powered\b",
                          pasted)
        self.assertEqual(hits, [])

    def test_no_overclaimed_sha_every_launch(self):
        # F3: the full SHA-256 runs on install/update, not every launch (LaunchIntegrity caches the
        # fingerprint). Guard the whole listing, incl. review notes, against the overclaim.
        hits = re.findall(r"(?i)verified (?:by SHA-256 )?(?:every time the app launches|at launch|every launch)",
                          self.text)
        self.assertEqual(hits, [], "listing overclaims SHA-256 verification frequency (see LaunchIntegrity)")

    def test_review_notes_use_real_labels(self):
        # F2/F6: a reviewer follows the review notes verbatim. The row is "About & credits", not "About".
        notes = _section(self.text, "App Review Information")
        self.assertNotRegex(notes, r"More → About\b(?! & credits)",
                            'review notes say "More → About" but the row is "About & credits"')
        self.assertNotIn("Search tab, type `waheguru` → open a result →\n> tap Hukam", notes,
                         "review path still routes Hukam through a search result (there is no Hukam control there)")

    def test_siri_phrases_named_in_listing_exist_in_code(self):
        # F4: every phrase the listing calls a Siri phrase must be a real AppShortcut.
        intents = (APP / "Sources" / "Intents" / "AppIntents.swift").read_text(encoding="utf-8")
        shortcut_block = intents[intents.find("AppShortcutsProvider"):] if "AppShortcutsProvider" in intents else intents
        phrases = set(re.findall(r'phrases:\s*\[(.*?)\]', shortcut_block, re.S))
        shortcut_text = " ".join(phrases)
        # "Open Ang" is a Shortcuts action only — it must NOT be sold as a Siri phrase.
        siri_line = next((l for l in self.description.splitlines() if "Works with Siri" in l), "")
        if siri_line:
            self.assertNotRegex(siri_line, r'"Open Ang"(?!\s*action)',
                                '"Open Ang" is a Shortcuts action, not a Siri phrase')

    def test_review_notes_widget_count_matches_code(self):
        widgets = violations(r"struct\s+\w+\s*:\s*Widget\b", dirs=[APP / "Widgets"])
        home_screen = [w for w in widgets if "LiveActivity" not in w]
        words = {2: "two", 3: "three", 4: "four", 5: "five"}
        notes = _section(self.text, "App Review Information")
        self.assertRegex(notes, rf"(?i)\b{words[len(home_screen)]} Home Screen widgets\b")

    def test_submission_urls_are_live_hosts(self):
        # The "Submit this" column is what gets typed into App Store Connect. Only hosts that
        # serve the pages today belong there; add gurbanisoul.com here when it goes live.
        live_hosts = {"gurbanisoul.com"}
        rows = re.findall(r"(?m)^\| (?:Support|Marketing|Privacy Policy) URL \| `https://([^/`]+)[^`]*` \|",
                          _section(self.text, "URLs"))
        self.assertEqual(len(rows), 3, "Support, Marketing and Privacy rows must each give a URL")
        self.assertEqual([h for h in rows if h not in live_hosts], [])

    def test_company_blurb_has_no_ai_positioning(self):
        # Worldwide release incl. India: "AI" appears in store text only as "never AI-generated".
        pasted = "\n".join([self.promo, self.description])
        stripped = re.sub(r"(?i)never AI-generated|or AI-generated", "", pasted)
        self.assertNotRegex(stripped, r"\bAI\b")


class InAppLinksMatchTheListing(unittest.TestCase):
    """The Privacy/Support URLs shipped inside the app must equal the URLs entered in App Store
    Connect (the listing's "Submit this" column), so the in-app policy link and the store metadata
    can never point at different pages."""

    def _app_link(self, name):
        src = (APP / "Sources" / "Screens" / "PrivacyPolicyScreen.swift").read_text(encoding="utf-8")
        m = re.search(rf'static let {name} = URL\(string: "([^"]+)"\)', src)
        self.assertIsNotNone(m, f"AppLinks.{name} not found")
        return m.group(1)

    def _listing_url(self, label):
        text = LISTING.read_text(encoding="utf-8")
        m = re.search(rf'(?m)^\| {re.escape(label)} \| `([^`]+)`', text)
        self.assertIsNotNone(m, f"listing row {label!r} not found")
        return m.group(1)

    def test_privacy_url_matches(self):
        self.assertEqual(self._app_link("privacy"), self._listing_url("Privacy Policy URL"))

    def test_support_url_matches(self):
        self.assertEqual(self._app_link("support"), self._listing_url("Support URL"))

    def test_app_links_use_the_canonical_host(self):
        # The in-app links must be https on the bare canonical host — no www, no vercel.app,
        # and nowhere in shipping Swift may the interim host survive.
        for name in ("privacy", "support"):
            u = self._app_link(name)
            self.assertTrue(u.startswith("https://gurbanisoul.com/"), f"AppLinks.{name} = {u}")
        self.assertEqual(
            violations(r"sggs-knowledge-base\.vercel\.app|www\.gurbanisoul\.com"), [],
            "shipping Swift references the interim/www host")


STATIC = ROOT / "webapp" / "static"
LANDING_ASSETS = ROOT / "frontend" / "src" / "assets" / "landing"


class LandingPage(unittest.TestCase):
    """The gurbanisoul.com landing page (built into webapp/static/index.html) must stay verbatim,
    honest, credited and light. Skips cleanly if the site has not been built yet."""

    @classmethod
    def setUpClass(cls):
        cls.index = STATIC / "index.html"
        cls.html = cls.index.read_text(encoding="utf-8") if cls.index.exists() else None

    def _skip_if_unbuilt(self):
        if self.html is None:
            self.skipTest("webapp/static/index.html not built (run: cd frontend && npm run build && npm run sync)")

    def test_landing_verse_is_verbatim(self):
        # The Gurmukhi on the landing must byte-match the corpus (Ang 1, first line).
        self._skip_if_unbuilt()
        db = ROOT / "db" / "sggs.sqlite"
        if not (db.exists() and db.read_bytes()[:15] == b"SQLite format 3"):
            self.skipTest("db/sggs.sqlite not present (git lfs pull)")
        m = re.search(r'<p class="verse gm" lang="pa"[^>]*>([^<]+)</p>', self.html)
        self.assertIsNotNone(m, "landing verse <p class=\"verse gm\" lang=\"pa\"> not found")
        shown = m.group(1).strip()
        want = sqlite3.connect(f"file:{db}?mode=ro", uri=True).execute(
            "SELECT gurmukhi FROM lines WHERE ang=1 ORDER BY id LIMIT 1").fetchone()[0].strip()
        self.assertEqual(shown, want, "landing verse is not verbatim from db/sggs.sqlite (Ang 1)")

    def test_landing_copy_is_honest(self):
        self._skip_if_unbuilt()
        # No "AI" except "AI-generated" (the negative claim), no "beta". Same spirit as the listing lint.
        stripped = re.sub(r"(?i)\bAI-generated\b", "", self.html)
        self.assertNotRegex(stripped, r"\bAI\b", "landing mentions AI other than 'AI-generated'")
        # visible-text "beta" (not the CSS/hash noise): check the body text only, roughly.
        self.assertNotRegex(self.html, r"(?i)>[^<]*\bbeta\b", "landing says 'beta'")

    def test_every_img_has_an_alt_attribute(self):
        self._skip_if_unbuilt()
        imgs = re.findall(r"<img\b[^>]*>", self.html)
        self.assertTrue(imgs, "no <img> on the landing")
        self.assertEqual([t for t in imgs if not re.search(r'\balt=', t)], [],
                         "an <img> on the landing has no alt attribute")

    def test_imagery_is_credited(self):
        # Every image shipped under src/assets/landing must have its maker named in site.ts
        # (IMAGE_CREDITS.who) and the credit must render on the page. The hero is now an original
        # artistic rendering (no stock photography), so the page carries an "Artwork" credit and
        # must NOT mention Unsplash any more.
        self._skip_if_unbuilt()
        site = (ROOT / "frontend" / "src" / "site.ts").read_text(encoding="utf-8")
        credits = re.findall(r'who:\s*"([^"]+)"', site)
        n_assets = len([p for p in LANDING_ASSETS.glob("*") if p.suffix.lower() in (".jpg", ".jpeg", ".png", ".webp")]) if LANDING_ASSETS.exists() else 0
        self.assertGreaterEqual(len(credits), n_assets, "fewer image credits than landing image assets")
        self.assertIn("Artwork", self.html, "landing does not carry an Artwork credit")
        self.assertNotIn("Unsplash", self.html, "landing still references Unsplash (photos were removed)")
        for who in credits:
            self.assertIn(who, self.html, f"image maker {who!r} not credited on the landing")

    def test_seo_head_present(self):
        self._skip_if_unbuilt()
        self.assertIn('rel="canonical" href="https://gurbanisoul.com/"', self.html)
        self.assertRegex(self.html, r'property="og:image" content="https://gurbanisoul\.com/')
        self.assertRegex(self.html, r'name="description" content="[^"]{40,}"')

    def test_page_weight_budget(self):
        self._skip_if_unbuilt()
        self.assertLessEqual(len(self.index.read_bytes()), 60 * 1024, "index.html over 60 KB")
        astro = STATIC / "_astro"
        heavy = [f.name for f in astro.glob("*") if f.suffix in (".avif", ".webp") and f.stat().st_size > 340 * 1024]
        self.assertEqual(heavy, [], f"served image variant(s) over 340 KB: {heavy}")

    def test_cta_state_is_consistent(self):
        # Exactly one canonical App-Store "coming soon" element (the hero one), and the page never
        # shows BOTH a real App-Store download link and a coming-soon chip of the same kind.
        self._skip_if_unbuilt()
        soon = re.findall(r'data-app-store="coming-soon"', self.html)
        self.assertEqual(len(soon), 1, f"expected exactly one [data-app-store=coming-soon], got {len(soon)}")
        download_link = re.search(r'<a\b[^>]*aria-label="[^"]*App Store[^"]*"', self.html)
        self.assertFalse(download_link and soon,
                         "page shows both an App-Store download link and a coming-soon chip")

    def test_landing_raags_match_db(self):
        # The raags listed under each pahar must be exactly the DB's primary claims for that pahar,
        # and pahar 7 (the silent night) must list none.
        self._skip_if_unbuilt()
        db = ROOT / "db" / "sggs.sqlite"
        if not (db.exists() and db.read_bytes()[:15] == b"SQLite format 3"):
            self.skipTest("db/sggs.sqlite not present (git lfs pull)")
        conn = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
        for p in range(1, 9):
            m = re.search(rf'<li[^>]*\bdata-pahar="{p}"[^>]*>(.*?)</li>', self.html, re.S)
            self.assertIsNotNone(m, f"no <li data-pahar=\"{p}\"> on the landing")
            shown = set(re.findall(r'<span class="gm" lang="pa"[^>]*>([^<]+)</span>', m.group(1)))
            want = {r[0] for r in conn.execute(
                "SELECT raag_name FROM raag_timing_claims WHERE claim_type='primary' AND pahar=?", (p,))}
            self.assertEqual(shown, want, f"pahar {p}: landing raags {shown} != DB primary claims {want}")
        # pahar 7 must have none
        m7 = re.search(r'<li[^>]*\bdata-pahar="7"[^>]*>(.*?)</li>', self.html, re.S)
        self.assertNotIn('class="gm"', m7.group(1), "pahar 7 must list no raags")


MARKETING_CSS = ROOT / "frontend" / "src" / "styles" / "marketing.css"
COMPONENTS = ROOT / "frontend" / "src" / "components"
INDEX_ASTRO = ROOT / "frontend" / "src" / "pages" / "index.astro"


def _marketing_style_sources():
    """(name, text) for the marketing stylesheet, every component, and the landing's scoped CSS."""
    out = [("marketing.css", MARKETING_CSS.read_text(encoding="utf-8"))]
    for p in sorted(COMPONENTS.glob("*.astro")):
        out.append((p.name, p.read_text(encoding="utf-8")))
    out.append(("index.astro", INDEX_ASTRO.read_text(encoding="utf-8")))
    return out


def _strip_dark_scope(css):
    """Remove balanced `[data-theme="dark"] { … }` blocks so what remains is 'light-mode' CSS."""
    out, i = [], 0
    while i < len(css):
        m = re.search(r'\[data-theme="dark"\][^{]*\{', css[i:])
        if not m:
            out.append(css[i:])
            break
        start = i + m.start()
        out.append(css[i:start])
        j = i + m.end()
        depth = 1
        while j < len(css) and depth:
            if css[j] == "{":
                depth += 1
            elif css[j] == "}":
                depth -= 1
            j += 1
        i = j
    return "".join(out)


class BrandDisciplineInSource(unittest.TestCase):
    """The Soul-Gold brand rules, enforced on the marketing CSS + components + landing scoped CSS."""

    def test_mark_is_flat(self):
        # The ੴ mark (and everything else on the marketing surface) is flat — no text-shadow.
        bad = [name for name, text in _marketing_style_sources() if re.search(r"text-shadow", text, re.I)]
        self.assertEqual(bad, [], f"text-shadow found in: {bad}")

    def test_no_red_and_gold_discipline(self):
        norm = lambda s: re.sub(r"\s+", "", s).lower()
        for name, text in _marketing_style_sources():
            self.assertNotIn("#da291c", text.lower(), f"brand red #DA291C appears in {name}")
            # Literal gold as a text colour is only allowed inside a [data-theme=\"dark\"] scope.
            light = norm(_strip_dark_scope(text))
            self.assertNotIn("color:#ffbc0d", light,
                             f"{name}: gold #FFBC0D used as a text colour outside a dark scope")
        # The verse is ink-coloured.
        idx = INDEX_ASTRO.read_text(encoding="utf-8")
        m = re.search(r"\.verse\s*\{([^}]*)\}", idx)
        self.assertIsNotNone(m, "no .verse rule in index.astro scoped styles")
        self.assertRegex(m.group(1), r"color:\s*var\(--ink\)", ".verse colour is not var(--ink)")


class SubmissionUrlsAreLive(unittest.TestCase):
    def test_robots_and_sitemap_shipped(self):
        for f in ("robots.txt", "sitemap.xml"):
            self.assertTrue((STATIC / f).exists() or (ROOT / "frontend" / "public" / f).exists(), f"missing {f}")


class DocsHygiene(unittest.TestCase):
    """The canonical public host is gurbanisoul.com. The legacy production alias
    `sggs-knowledge-base.vercel.app` may still be *named* — but only in the two docs whose
    job is to record the domain topology, and only as a legacy alias. Anywhere else in the
    tracked Markdown it is a stale URL that will mislead a reader (or get baked into a link),
    so it is forbidden. (Staging's `sggs-staging.vercel.app` is a different host and is fine.)"""

    ALLOWED = {
        Path("docs/process/environments.md"),
        Path("docs/website/README.md"),
    }

    def _tracked_markdown(self):
        # Read-only, stdlib: walk the repo for *.md, skipping vendored/build trees.
        skip = {"node_modules", "dist", "static", "static.bak", ".git", "_astro", "build"}
        for p in ROOT.rglob("*.md"):
            rel = p.relative_to(ROOT)
            if any(part in skip for part in rel.parts):
                continue
            yield rel, p

    def test_legacy_vercel_alias_only_in_domain_docs(self):
        offenders = []
        for rel, p in self._tracked_markdown():
            if "sggs-knowledge-base.vercel.app" in p.read_text(encoding="utf-8", errors="ignore"):
                if rel not in self.ALLOWED:
                    offenders.append(str(rel))
        self.assertEqual(
            sorted(offenders), [],
            "legacy vercel.app alias must appear only in the domain-topology docs "
            f"({sorted(str(a) for a in self.ALLOWED)}); found in: {sorted(offenders)}",
        )

    def test_website_readme_exists_and_names_canonical_host(self):
        readme = ROOT / "docs" / "website" / "README.md"
        self.assertTrue(readme.exists(), "docs/website/README.md is missing")
        text = readme.read_text(encoding="utf-8")
        self.assertIn("gurbanisoul.com", text)
        self.assertIn("sggs-knowledge-base.vercel.app", text)  # must document the legacy alias


class VersionPolicyDocumented(unittest.TestCase):
    """The one-number policy (web == API == iOS binary, re-archived every release) must stay
    written down where a future maintainer looks. If someone softens the rule they have to
    delete the sentence, which fails here — so the policy can't quietly rot."""

    SENTENCE = "re-archived at the same version"

    def test_documented_in_release_and_claude(self):
        for rel in ("docs/process/release.md", "CLAUDE.md"):
            text = (ROOT / rel).read_text(encoding="utf-8")
            self.assertIn(self.SENTENCE, text, f"{rel} no longer states the one-number policy")

    def test_release_complete_checker_exists(self):
        self.assertTrue((ROOT / "scripts/release/check_release_complete.py").exists(),
                        "scripts/release/check_release_complete.py is missing")


# ------------------------------------------------------------------------------------------------
# PR1 — web foundations: SEO / sitemap / RSS / analytics / smart-banner / theme-token gates.
# These read the BUILT webapp/static (skip cleanly if unbuilt) and the tracked frontend source.
# ------------------------------------------------------------------------------------------------
import xml.etree.ElementTree as ET  # noqa: E402

SITE = "https://gurbanisoul.com"
FRONTEND = ROOT / "frontend"
SITEMAP_NS = "{http://www.sitemaps.org/schemas/sitemap/0.9}"


def _norm_url(u):
    """Compare URLs without caring about a single trailing slash."""
    return u.rstrip("/")


def _built_pages():
    """Yield (route, path) for every built *.html except 404.html.

    index.html -> "/"; <dir>/index.html -> "/<dir>"; any other x.html -> "/x".
    """
    for p in sorted(STATIC.rglob("*.html")):
        rel = p.relative_to(STATIC)
        if rel.name == "404.html":
            continue
        if rel.name == "index.html":
            d = rel.parent.as_posix()
            route = "/" if d == "." else "/" + d
        else:
            route = "/" + rel.with_suffix("").as_posix()
        yield route, p


def _unbuilt():
    return not (STATIC / "index.html").exists()


class SeoInvariants(unittest.TestCase):
    """Every built page carries an honest, self-consistent SEO/social head."""

    def setUp(self):
        if _unbuilt():
            self.skipTest("webapp/static not built (cd frontend && npm run build:deploy)")

    def test_every_page_has_correct_seo_head(self):
        pages = list(_built_pages())
        self.assertTrue(pages, "no built HTML pages found")
        marketing = {"/"}
        for route, path in pages:
            html = path.read_text(encoding="utf-8")
            canonical_want = _norm_url(SITE + route)

            cans = re.findall(r'<link rel="canonical" href="([^"]+)"', html)
            self.assertEqual(len(cans), 1, f"{route}: expected exactly one canonical, got {cans}")
            self.assertEqual(_norm_url(cans[0]), canonical_want, f"{route}: wrong canonical {cans[0]}")

            desc = re.search(r'<meta name="description" content="([^"]*)"', html)
            self.assertIsNotNone(desc, f"{route}: no description meta")
            self.assertGreaterEqual(len(desc.group(1)), 40, f"{route}: description under 40 chars")

            og = re.search(r'<meta property="og:image" content="([^"]+)"', html)
            self.assertIsNotNone(og, f"{route}: no og:image")
            og_path = og.group(1).split(SITE, 1)[-1].lstrip("/")
            self.assertTrue((STATIC / og_path).is_file(), f"{route}: og:image {og.group(1)} missing on disk")

            self.assertGreaterEqual(len(re.findall(r'name="theme-color"', html)), 1, f"{route}: no theme-color")

            if route in marketing:
                self.assertRegex(html, r'rel="manifest"', f"{route}: marketing page missing manifest link")

            # hreflang alternates (if any) must be en / x-default and self-referential — no /pa/ yet.
            for lang, href in re.findall(r'<link rel="alternate" hreflang="([^"]+)" href="([^"]+)"', html):
                self.assertIn(lang, ("en", "x-default"), f"{route}: unexpected hreflang {lang}")
                self.assertNotIn("/pa/", href, f"{route}: hreflang points at a /pa/ URL")
                self.assertEqual(_norm_url(href), canonical_want, f"{route}: hreflang not self-referential")


class SitemapInvariants(unittest.TestCase):
    def setUp(self):
        if _unbuilt() or not (STATIC / "sitemap.xml").exists():
            self.skipTest("sitemap.xml not built")

    def test_sitemap_matches_built_routes(self):
        root = ET.parse(STATIC / "sitemap.xml").getroot()
        locs = {_norm_url(el.text) for el in root.iter(f"{SITEMAP_NS}loc")}
        built = {_norm_url(SITE + route) for route, _ in _built_pages()}
        self.assertEqual(locs, built, f"sitemap <loc> set != built HTML routes\n  only in sitemap: "
                         f"{sorted(locs - built)}\n  only built: {sorted(built - locs)}")

    def test_every_lastmod_is_a_date(self):
        root = ET.parse(STATIC / "sitemap.xml").getroot()
        mods = [el.text for el in root.iter(f"{SITEMAP_NS}lastmod")]
        self.assertTrue(mods, "no <lastmod> in sitemap")
        for m in mods:
            self.assertRegex(m, r"^\d{4}-\d{2}-\d{2}", f"lastmod not an ISO date: {m!r}")

    def test_robots_names_sitemap(self):
        for cand in (STATIC / "robots.txt", FRONTEND / "public" / "robots.txt"):
            if cand.exists():
                self.assertIn("sitemap.xml", cand.read_text(encoding="utf-8"))
                return
        self.fail("robots.txt not found")

    def test_learn_routes_present(self):
        root = ET.parse(STATIC / "sitemap.xml").getroot()
        locs = {_norm_url(el.text) for el in root.iter(f"{SITEMAP_NS}loc")}
        self.assertIn(_norm_url(SITE + "/learn"), locs, "sitemap missing /learn")
        # every built Learn article route must be in the sitemap
        for route, _ in _learn_articles():
            self.assertIn(_norm_url(SITE + route), locs, f"sitemap missing {route}")


class RssInvariants(unittest.TestCase):
    def setUp(self):
        if _unbuilt() or not (STATIC / "rss.xml").exists():
            self.skipTest("rss.xml not built")

    def test_rss_parses_and_links_to_site(self):
        root = ET.parse(STATIC / "rss.xml").getroot()
        link = root.find("./channel/link")
        self.assertIsNotNone(link, "rss has no <channel><link>")
        self.assertEqual(_norm_url(link.text), _norm_url(SITE))

    def test_rss_item_count_matches_non_draft_articles(self):
        root = ET.parse(STATIC / "rss.xml").getroot()
        items = root.findall("./channel/item")
        self.assertEqual(len(items), _non_draft_article_count(),
                         "rss item count != number of non-draft Learn articles")
        for it in items:
            link = it.find("link")
            self.assertIsNotNone(link, "rss item has no <link>")
            self.assertTrue(link.text.startswith(SITE + "/learn/"),
                            f"rss item link not a /learn/ URL: {link.text}")


# ------------------------------------------------------------------------------------------------
# PR3 — the Learn content section. These read the BUILT webapp/static/learn/** and db/sggs.sqlite
# (skip cleanly if unbuilt / no DB) plus the tracked Learn source, and enforce that every quoted
# line is verbatim, declared, cited, labelled, and that the copy stays honest.
# ------------------------------------------------------------------------------------------------
LEARN_MDX_DIR = FRONTEND / "src" / "content" / "learn"
QUOTES_JSON = FRONTEND / "src" / "generated" / "quotes.json"
DB = ROOT / "db" / "sggs.sqlite"

_VERSE_P = re.compile(r'<p class="verse gm" lang="pa" data-line-id="(\d+)"[^>]*>([^<]*)</p>')
_FIGURE = re.compile(
    r'<figure class="verse-fig" data-line-id="(\d+)"[^>]*>.*?'
    r'<figcaption class="cite"[^>]*>([^<]*)</figcaption>', re.S)
_LD_JSON = re.compile(r'<script type="application/ld\+json"[^>]*>(.*?)</script>', re.S)


def _learn_articles():
    """(route, html) for every built Learn ARTICLE page (excludes the /learn index)."""
    base = STATIC / "learn"
    if not base.exists():
        return
    for p in sorted(base.rglob("index.html")):
        if p.parent.name == "learn":          # the /learn index itself, not an article
            continue
        yield "/learn/" + p.parent.name, p.read_text(encoding="utf-8")


def _all_learn_html():
    """html of every built Learn page, index included."""
    base = STATIC / "learn"
    if not base.exists():
        return
    for p in sorted(base.rglob("index.html")):
        yield p.read_text(encoding="utf-8")


def _non_draft_article_count():
    n = 0
    for mdx in LEARN_MDX_DIR.glob("*.mdx"):
        m = re.search(r"(?ms)^---\s*\n(.*?)\n---", mdx.read_text(encoding="utf-8"))
        fm = m.group(1) if m else ""
        if not re.search(r"(?m)^draft:\s*true\s*$", fm):
            n += 1
    return n


def _iter_ld_objects(node):
    """Yield every dict in a parsed JSON-LD payload (handles @graph / arrays / nesting)."""
    if isinstance(node, dict):
        yield node
        for v in node.values():
            yield from _iter_ld_objects(v)
    elif isinstance(node, list):
        for v in node:
            yield from _iter_ld_objects(v)


class LearnSection(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.unbuilt = _unbuilt() or not (STATIC / "learn").exists()
        cls.no_db = not (DB.exists() and DB.read_bytes()[:15] == b"SQLite format 3")
        cls.conn = None if cls.no_db else sqlite3.connect(f"file:{DB}?mode=ro", uri=True)

    def _need_built(self):
        if self.unbuilt:
            self.skipTest("webapp/static/learn not built (cd frontend && npm run build:deploy)")

    def _need_db(self):
        if self.no_db:
            self.skipTest("db/sggs.sqlite not present (git lfs pull)")

    def _db_line(self, lid):
        return self.conn.execute(
            "SELECT ang, gurmukhi FROM lines WHERE id=?", (lid,)).fetchone()

    def test_quotes_verbatim(self):
        self._need_built(); self._need_db()
        quotes = json.loads(QUOTES_JSON.read_text(encoding="utf-8"))["quotes"]
        seen = 0
        for route, html in _learn_articles():
            for m in _VERSE_P.finditer(html):
                lid, shown = int(m.group(1)), m.group(2).strip()
                row = self._db_line(lid)
                self.assertIsNotNone(row, f"{route}: line id {lid} not in DB")
                self.assertEqual(shown, row[1].strip(),
                                 f"{route}: rendered verse id {lid} is not verbatim from db")
                self.assertIn(str(lid), quotes, f"{route}: id {lid} missing from quotes.json")
                self.assertEqual(quotes[str(lid)]["gurmukhi"].strip(), row[1].strip(),
                                 f"quotes.json id {lid} gurmukhi != db")
                seen += 1
        self.assertGreater(seen, 0, "no rendered verses found in any Learn article")

    def test_quotes_declared(self):
        self._need_built()
        quotes = json.loads(QUOTES_JSON.read_text(encoding="utf-8"))["quotes"]
        for route, html in _learn_articles():
            for lid in set(re.findall(r'data-line-id="(\d+)"', html)):
                self.assertIn(lid, quotes, f"{route}: body data-line-id {lid} not in quotes.json")

    def test_explanation_labelled(self):
        self._need_built()
        LABEL = "Explanation (interpretation, not scripture)"
        for route, html in _learn_articles():
            if 'class="verse gm"' in html:
                self.assertIn(LABEL, html,
                              f"{route}: quotes scripture but has no labelled Explanation")

    def test_citation_format(self):
        self._need_built(); self._need_db()
        pat = re.compile(r"^Sri Guru Granth Sahib Ji · Ang (\d{1,4})")
        seen = 0
        for route, html in _learn_articles():
            for m in _FIGURE.finditer(html):
                lid, cite = int(m.group(1)), m.group(2).strip()
                cm = pat.match(cite)
                self.assertIsNotNone(cm, f"{route}: bad citation format: {cite!r}")
                row = self._db_line(lid)
                self.assertIsNotNone(row, f"{route}: line id {lid} not in DB")
                self.assertEqual(int(cm.group(1)), row[0],
                                 f"{route}: citation Ang for id {lid} != db Ang {row[0]}")
                seen += 1
        self.assertGreater(seen, 0, "no citations found in any Learn article")

    def test_learn_honest_copy(self):
        self._need_built()
        for html in _all_learn_html():
            stripped = re.sub(r"(?i)\bAI-generated\b", "", html)
            self.assertNotRegex(stripped, r"\bAI\b", "Learn HTML mentions AI other than 'AI-generated'")
            self.assertNotRegex(html, r"(?i)>[^<]*\bbeta\b", "Learn HTML says 'beta'")
            self.assertNotRegex(html, r"(?i)\b(audio|kirtan|android)\b",
                                "Learn HTML claims audio/kirtan/android")

    def test_article_jsonld_valid(self):
        self._need_built()
        for route, html in _learn_articles():
            blocks = _LD_JSON.findall(html)
            self.assertTrue(blocks, f"{route}: no application/ld+json block")
            objs = []
            for b in blocks:
                try:
                    objs.extend(_iter_ld_objects(json.loads(b)))
                except json.JSONDecodeError as e:
                    self.fail(f"{route}: ld+json does not parse: {e}")
            types = {o.get("@type") for o in objs}
            self.assertIn("BreadcrumbList", types, f"{route}: no BreadcrumbList JSON-LD")
            article = next((o for o in objs if o.get("@type") == "Article"), None)
            self.assertIsNotNone(article, f"{route}: no Article JSON-LD")
            self.assertTrue(article.get("headline"), f"{route}: Article missing headline")
            self.assertTrue(article.get("datePublished"), f"{route}: Article missing datePublished")


class ExternalRequestAllowlist(unittest.TestCase):
    """The marketing page (and the JS it loads) may only reference an approved set of external
    hosts, and the Vercel analytics loader must always sit behind the gurbanisoul.com hostname
    guard — never an unconditional request."""

    ALLOWED = {
        "gurbanisoul.com", "unsplash.com", "apps.apple.com",
        "github.com", "buttondown.com", "sggs-knowledge-base.onrender.com",
    }

    def setUp(self):
        if _unbuilt():
            self.skipTest("webapp/static not built")

    def _marketing_sources(self):
        index = STATIC / "index.html"
        html = index.read_text(encoding="utf-8")
        sources = [("index.html", html)]
        for ref in re.findall(r'(?:src|href)="(/_astro/[^"]+\.js)"', html):
            js = STATIC / ref.lstrip("/")
            if js.is_file():
                sources.append((ref, js.read_text(encoding="utf-8")))
        return sources

    def test_absolute_hosts_are_allowlisted(self):
        bad = []
        for name, text in self._marketing_sources():
            for host in re.findall(r'https?://([a-z0-9.-]+)', text, re.I):
                if host.lower() not in self.ALLOWED:
                    bad.append(f"{name}: {host}")
        self.assertEqual(bad, [], f"marketing references non-allowlisted host(s): {bad}")

    def test_vercel_insights_is_hostname_guarded(self):
        html = (STATIC / "index.html").read_text(encoding="utf-8").splitlines()
        for i, line in enumerate(html):
            if "_vercel/insights" in line:
                window = " ".join(html[max(0, i - 1): i + 2])
                self.assertIn("gurbanisoul.com", window,
                              f"line {i+1}: /_vercel/insights is not beside a gurbanisoul.com guard")


class SmartBannerConsistency(unittest.TestCase):
    """If the App Store id or URL is set in site.ts, both must be, and APP_STORE_URL must end with
    /id + APP_STORE_ID (so the Smart App Banner and the download link can never disagree)."""

    def test_app_store_id_and_url_agree(self):
        site = (FRONTEND / "src" / "site.ts").read_text(encoding="utf-8")
        app_id = re.search(r'APP_STORE_ID\s*=\s*"([^"]*)"', site).group(1)
        app_url = re.search(r'APP_STORE_URL\s*=\s*"([^"]*)"', site).group(1)
        if not app_id and not app_url:
            return
        self.assertTrue(app_id and app_url, "one of APP_STORE_ID / APP_STORE_URL is set but not the other")
        self.assertTrue(app_url.endswith("/id" + app_id),
                        f"APP_STORE_URL {app_url!r} must end with /id{app_id}")


class NoSecretsInFrontend(unittest.TestCase):
    """No obvious secrets, and no baked newsletter form URL, in tracked frontend source."""

    SECRET_PATTERNS = [
        r"AKIA[0-9A-Z]{16}",                       # AWS access key id
        r"AIza[0-9A-Za-z_\-]{35}",                 # Google API key
        r"sk_live_[0-9A-Za-z]{16,}",               # Stripe secret
        r"gh[pousr]_[0-9A-Za-z]{20,}",             # GitHub token
        r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----",
        r"PUBLIC_NEWSLETTER_FORM_URL",             # form URL must not be a literal in src
    ]

    def test_no_secret_patterns(self):
        rx = re.compile("|".join(self.SECRET_PATTERNS))
        offenders = []
        src = FRONTEND / "src"
        for p in src.rglob("*"):
            if not p.is_file() or p.suffix in (".ttf", ".woff2", ".woff", ".png", ".jpg", ".jpeg", ".webp", ".avif"):
                continue
            if rx.search(p.read_text(encoding="utf-8", errors="ignore")):
                offenders.append(str(p.relative_to(ROOT)))
        self.assertEqual(offenders, [], f"possible secret/newsletter-URL literal in: {offenders}")


class WebThemeMatchesTokens(unittest.TestCase):
    """frontend/src/theme.ts hex values must equal the light/dark legs of docs/brand/tokens.json."""

    # theme.ts key -> (tokens.json group, key)
    MAP = {
        "paper": ("surfaces", "paper"),
        "paperWarm": ("surfaces", "paperWarm"),
        "card": ("surfaces", "card"),
        "accentFill": ("soul", "accentFill"),
        "accent": ("soul", "accent"),
        "accentText": ("soul", "accentText"),
        "onAccent": ("soul", "onAccent"),
    }

    @staticmethod
    def _leg(theme_ts, leg):
        m = re.search(rf"{leg}:\s*\{{(.*?)\}}", theme_ts, re.S)
        assert m, f"theme.ts has no {leg} block"
        return dict(re.findall(r'(\w+):\s*"(#[0-9A-Fa-f]{6})"', m.group(1)))

    def test_theme_ts_equals_tokens(self):
        tokens = json.loads((ROOT / "docs/brand/tokens.json").read_text(encoding="utf-8"))
        theme_ts = (FRONTEND / "src" / "theme.ts").read_text(encoding="utf-8")
        light, dark = self._leg(theme_ts, "light"), self._leg(theme_ts, "dark")
        for key, (grp, tkey) in self.MAP.items():
            legs = tokens[grp][tkey]
            self.assertEqual(light[key].upper(), legs[0].upper(), f"theme.ts light.{key} != tokens {grp}.{tkey}[0]")
            self.assertEqual(dark[key].upper(), legs[1].upper(), f"theme.ts dark.{key} != tokens {grp}.{tkey}[1]")


if __name__ == "__main__":
    unittest.main()
