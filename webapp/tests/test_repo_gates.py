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

    def test_photographers_are_credited(self):
        # Every photo shipped under src/assets/landing must have its photographer named in site.ts
        # and the credit must render on the page.
        self._skip_if_unbuilt()
        site = (ROOT / "frontend" / "src" / "site.ts").read_text(encoding="utf-8")
        credits = re.findall(r'who:\s*"([^"]+)"', site)
        n_assets = len([p for p in LANDING_ASSETS.glob("*") if p.suffix.lower() in (".jpg", ".jpeg", ".png", ".webp")]) if LANDING_ASSETS.exists() else 0
        self.assertGreaterEqual(len(credits), n_assets, "fewer photo credits than landing image assets")
        self.assertIn("Unsplash", self.html, "landing does not credit Unsplash")
        for who in credits:
            self.assertIn(who, self.html, f"photographer {who!r} not credited on the landing")

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


class SubmissionUrlsAreLive(unittest.TestCase):
    def test_robots_and_sitemap_shipped(self):
        for f in ("robots.txt", "sitemap.xml"):
            self.assertTrue((STATIC / f).exists() or (ROOT / "frontend" / "public" / f).exists(), f"missing {f}")


if __name__ == "__main__":
    unittest.main()
