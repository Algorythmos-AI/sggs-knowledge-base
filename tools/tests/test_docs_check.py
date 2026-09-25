"""tools/docs_check.py — the rules, exercised on small fixture pages (stdlib unittest)."""
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("docs_check", ROOT / "tools" / "docs_check.py")
dc = importlib.util.module_from_spec(spec)
sys.modules["docs_check"] = dc
spec.loader.exec_module(dc)

FM = '---\ntitle: "A fixture page"\ndescription: "A description that is comfortably longer than forty characters."\n---\n# A fixture page\n\n'


class Fixture(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.tokens = dc.load_tokens_hex()
        self.widgets = dc.widget_schema()

    def tearDown(self):
        self.tmp.cleanup()

    def page(self, body, name="page.md"):
        p = self.dir / name
        p.write_text(body, encoding="utf-8")
        return p

    def errors(self, body, name="page.md"):
        return [pr.msg for pr in dc.check_page(self.page(body, name), self.tokens, self.widgets, None) if pr.level == "error"]


class Frontmatter(Fixture):
    def test_clean_page_passes(self):
        self.assertEqual(self.errors(FM + "Body.\n"), [])

    def test_missing_frontmatter(self):
        self.assertTrue(any("missing frontmatter" in e for e in self.errors("# A page\n\nBody.\n")))

    def test_h1_must_match_title(self):
        self.assertTrue(any("must equal frontmatter title" in e for e in self.errors(FM.replace("# A fixture page", "# Other"))))

    def test_short_description(self):
        bad = FM.replace('description: "A description that is comfortably longer than forty characters."', 'description: "too short"')
        self.assertTrue(any("description must be" in e for e in self.errors(bad)))

    def test_code_span_in_h1_reads_as_text(self):
        body = '---\ntitle: "Keep comp_id"\ndescription: "A description that is comfortably longer than forty characters."\n---\n# Keep `comp_id`\n\nBody.\n'
        self.assertEqual(self.errors(body), [])


class Links(Fixture):
    def test_broken_relative_link(self):
        self.assertTrue(any("broken link" in e for e in self.errors(FM + "See [x](missing.md).\n")))

    def test_anchor_resolves_with_github_slug(self):
        self.page(FM + "## Prime directive: never `edit`\n", "other.md")
        self.assertEqual(self.errors(FM + "See [x](other.md#prime-directive-never-edit).\n"), [])
        self.assertTrue(any("anchor" in e for e in self.errors(FM + "See [x](other.md#nope).\n")))

    def test_root_absolute_and_localhost_rejected(self):
        self.assertTrue(any("root-absolute" in e for e in self.errors(FM + "[x](/architecture/)\n")))
        self.assertTrue(any("local host" in e for e in self.errors(FM + "[x](http://localhost:7777/api)\n")))

    def test_links_inside_code_are_ignored(self):
        self.assertEqual(self.errors(FM + "Run `[x](missing.md)` and\n\n```\n[y](also-missing.md)\n```\n"), [])


class Widgets(Fixture):
    def test_widget_needs_fallback(self):
        self.assertTrue(any("fallback" in e for e in self.errors(FM + "<!-- sggs:status -->\n\n\n\n## Next\n")))
        self.assertEqual(self.errors(FM + "<!-- sggs:status -->\nLive status appears here.\n"), [])

    def test_unknown_widget_or_attribute(self):
        self.assertTrue(any("unknown widget" in e for e in self.errors(FM + "<!-- sggs:nope -->\nfallback\n")))
        self.assertTrue(any("no attribute" in e for e in self.errors(FM + '<!-- sggs:status q="x" -->\nfallback\n')))


class Mermaid(Fixture):
    def test_palette_and_init(self):
        self.assertTrue(any("not allowed" in e for e in self.errors(FM + "```mermaid\nflowchart LR\n  classDef x fill:#123456\n```\n")))
        self.assertTrue(any("init" in e for e in self.errors(FM + "```mermaid\n%%{init: {'theme':'dark'}}%%\nflowchart LR\n```\n")))
        self.assertEqual(self.errors(FM + "```mermaid\nflowchart LR\n  accTitle: t\n  classDef x fill:#FDF6E3,color:#201A12\n```\n"), [])


class Scripture(Fixture):
    VERSE = "ਸੋਚੈ ਸੋਚਿ ਨ ਹੋਵਈ ਜੇ ਸੋਚੀ ਲਖ ਵਾਰ ॥"

    def test_names_in_prose_are_fine_but_verses_are_not(self):
        self.assertEqual(self.errors(FM + "The ਗੁਰਦੇਵ ਮਾਤਾ salok and `ਮਃ ੧` headers.\n"), [])
        self.assertTrue(any("cited blockquote" in e for e in self.errors(FM + f"{self.VERSE}\n")))

    def test_cited_blockquote_passes_without_db(self):
        body = FM + f"> {self.VERSE}\n>\n> — Sri Guru Granth Sahib Ji · Ang 1\n"
        self.assertEqual(self.errors(body), [])

    def test_uncited_blockquote_fails(self):
        self.assertTrue(any("must end with" in e for e in self.errors(FM + f"> {self.VERSE}\n")))

    @unittest.skipUnless((ROOT / "db" / "sggs.sqlite").exists(), "pinned database not installed")
    def test_quote_is_verified_against_the_database(self):
        import sqlite3
        db = sqlite3.connect(f"file:{ROOT / 'db' / 'sggs.sqlite'}?mode=ro&immutable=1", uri=True)
        good = self.page(FM + f"> {self.VERSE}\n>\n> — Sri Guru Granth Sahib Ji · Ang 1\n", "good.md")
        bad = self.page(FM + f"> {self.VERSE}\n>\n> — Sri Guru Granth Sahib Ji · Ang 2\n", "bad.md")
        self.assertEqual([p.msg for p in dc.check_page(good, self.tokens, self.widgets, db) if p.level == "error"], [])
        self.assertTrue(any("not a verbatim line" in p.msg for p in dc.check_page(bad, self.tokens, self.widgets, db)))


class SiteConfig(unittest.TestCase):
    def test_site_config_is_valid(self):
        self.assertEqual([str(p) for p in dc.check_site_config() if p.level == "error"], [])

    def test_unknown_vercel_json_key_is_refused(self):
        # `vercel deploy` rejects additional properties such as "_comment" (seen on the first docs deploy).
        real = dc.SITE / "vercel.json"
        original = real.read_text(encoding="utf-8")
        try:
            v = json.loads(original); v["_comment"] = "x"
            real.write_text(json.dumps(v), encoding="utf-8")
            self.assertTrue(any("_comment" in str(p) for p in dc.check_site_config()))
        finally:
            real.write_text(original, encoding="utf-8")

    def test_repo_docs_pass(self):
        errors = [str(p) for p in dc.run(ROOT / "db" / "sggs.sqlite") if p.level == "error"]
        self.assertEqual(errors, [])


if __name__ == "__main__":
    unittest.main()


class CodeWidget(Fixture):
    """`<!-- sggs:code -->`: the excerpt's target must exist and its symbol be findable."""

    def test_platform_file_and_symbol(self):
        self.assertEqual(self.errors(FM + '<!-- sggs:code file="webapp/sggs/core.py" symbol="LINE_COLS" -->\nSource: core.py.\n'), [])
        self.assertTrue(any("does not exist" in e for e in self.errors(FM + '<!-- sggs:code file="webapp/nope.py" symbol="x" -->\nfallback\n')))
        self.assertTrue(any("not found" in e for e in self.errors(FM + '<!-- sggs:code file="webapp/sggs/core.py" symbol="no_such_symbol" -->\nfallback\n')))
        self.assertTrue(any("symbol= or lines=" in e for e in self.errors(FM + '<!-- sggs:code file="webapp/sggs/core.py" -->\nfallback\n')))
        self.assertTrue(any("lines must be" in e for e in self.errors(FM + '<!-- sggs:code file="webapp/sggs/core.py" lines="x" -->\nfallback\n')))
        self.assertTrue(any("bad file" in e for e in self.errors(FM + '<!-- sggs:code file="../etc/passwd" lines="1-2" -->\nfallback\n')))

    def test_sibling_file_must_be_pinned(self):
        self.assertTrue(any("unknown repo" in e for e in self.errors(FM + '<!-- sggs:code file="x.py" repo="nope" symbol="f" -->\nfallback\n')))
        if "sggs-data" in dc.sibling_sources():
            self.assertTrue(any("does not pin" in e for e in self.errors(FM + '<!-- sggs:code file="pipeline/not-pinned.py" repo="sggs-data" symbol="f" -->\nfallback\n')))
            self.assertEqual(self.errors(FM + '<!-- sggs:code file="pipeline/reconcile.py" repo="sggs-data" lines="1-10" -->\nfallback\n'), [])


class SiblingPages(unittest.TestCase):
    """Pages installed from a sibling repository are canonical elsewhere: what only that repository
    can fix is a notice here, and poster footers may name their pinned files."""

    def test_pinned_file_names(self):
        if "sggs-data" in dc.sibling_sources():
            self.assertTrue(dc.pinned_file("sggs-data/pipeline/reconcile.py"))
        self.assertFalse(dc.pinned_file("sggs-data/pipeline/nope.py"))
        self.assertFalse(dc.pinned_file("nope/x.py"))

    def test_sibling_pages_get_notices_not_errors(self):
        installed = sorted(dc.SOURCES_DIR.rglob("*.md")) if dc.SOURCES_DIR.exists() else []
        if not installed:
            self.skipTest("sibling docs not installed (tools/fetch_sibling_docs.py)")
        tokens, widgets = dc.load_tokens_hex(), dc.widget_schema()
        for page in installed:
            self.assertTrue(dc.is_sibling(page))
            for pr in dc.check_page(page, tokens, widgets, None):
                self.assertIn(pr.level, ("notice", "warning"), f"{page}: {pr.msg}")
        self.assertFalse(dc.is_sibling(dc.DOCS / "README.md"))


class Drift(unittest.TestCase):
    """The engine pages and posters name what the code names."""

    def test_mode_literals_are_read_from_the_code(self):
        lits = dc.search_mode_literals()
        for expected in ("gurmukhi", "gurmukhi-skeleton", "roman", "roman-spelling-tolerant", "first-letters", "english",
                         "english-translation", "variant-match", "mixed-script", "skeleton-blob", "seeker-lexicon",
                         "passage-match", "(honorifics dropped)", "+ honorific-dropped"):
            self.assertIn(expected, lits)

    def test_thresholds_are_read_from_the_code(self):
        t = dc.verify_thresholds()
        self.assertEqual(t["_THRESH_EXACT"], "0.95")
        self.assertEqual(t["_THRESH_PROBABLE"], "0.85")
        self.assertEqual(t["_THRESH_GAP"], "0.05")

    def test_repo_has_no_drift(self):
        self.assertEqual([str(p) for p in dc.check_drift()], [])


class Terms(Fixture):
    def test_known_terms_pass_and_unknown_fail(self):
        self.assertEqual(self.errors(FM + "An [[Ang]] and a [[Salok|salok]] are fine; `[[not-a-term]]` in code is ignored.\n"), [])
        self.assertTrue(any("not a glossary term" in e for e in self.errors(FM + "A [[Frobnicator]] here.\n")))
