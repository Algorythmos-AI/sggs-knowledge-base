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

    def test_trailing_slash_redirect_is_refused(self):
        # trailingSlash:true loops /api/* with the product host's own trailing-slash redirect.
        real = dc.SITE / "vercel.json"
        original = real.read_text(encoding="utf-8")
        try:
            v = json.loads(original); v["trailingSlash"] = True
            real.write_text(json.dumps(v), encoding="utf-8")
            self.assertTrue(any("trailingSlash" in str(p) for p in dc.check_site_config()))
        finally:
            real.write_text(original, encoding="utf-8")

    def test_unsafe_inline_scripts_are_refused(self):
        # inline scripts are allowed by hash (docs-site/scripts/csp.mjs); 'unsafe-inline' would undo that
        real = dc.SITE / "vercel.json"
        original = real.read_text(encoding="utf-8")
        try:
            real.write_text(original.replace("script-src 'self'", "script-src 'self' 'unsafe-inline'"), encoding="utf-8")
            self.assertTrue(any("unsafe-inline" in str(p) for p in dc.check_site_config()))
        finally:
            real.write_text(original, encoding="utf-8")


class Theme(unittest.TestCase):
    CSS = ':root {\n  --sgs-paper: #171412;\n}\n:root[data-theme="light"] {\n  --sgs-paper: #fbf7f0;\n}\n'

    def tokens(self):
        return json.loads((dc.DOCS / "brand" / "tokens.json").read_text(encoding="utf-8"))

    def test_the_site_theme_matches_the_tokens(self):
        self.assertEqual([str(p) for p in dc.check_theme()], [])

    def test_a_drifted_brand_colour_is_refused(self):
        with tempfile.TemporaryDirectory() as d:
            css = Path(d) / "theme.css"
            real = (dc.SITE / "src" / "styles" / "theme.css").read_text(encoding="utf-8")
            css.write_text(real.replace("--sgs-accent-text: #8a6100", "--sgs-accent-text: #8a6101"), encoding="utf-8")
            msgs = [p.msg for p in dc.check_theme(css, self.tokens())]
            self.assertEqual(len(msgs), 1, msgs)
            self.assertIn("light theme --sgs-accent-text is #8A6101", msgs[0])

    def test_a_missing_role_is_refused(self):
        with tempfile.TemporaryDirectory() as d:
            css = Path(d) / "theme.css"
            css.write_text(self.CSS, encoding="utf-8")
            msgs = [p.msg for p in dc.check_theme(css, self.tokens())]
            self.assertTrue(any("lacks --sgs-accent" in m for m in msgs))
            self.assertFalse(any("--sgs-paper " in m and "is #" in m for m in msgs))   # paper matches both legs


class PosterLegend(unittest.TestCase):
    def test_a_poster_without_its_legend_is_refused(self):
        svg = dc.DOCS / "diagrams" / "posters" / "01-system-landscape.svg"
        original = svg.read_text(encoding="utf-8")
        try:
            svg.write_text(original.replace('<g class="pk-legend">', '<g>'), encoding="utf-8")
            self.assertTrue(any("legend" in p.msg and p.file == svg for p in dc.check_posters(dc.load_tokens_hex())))
        finally:
            svg.write_text(original, encoding="utf-8")

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


class Freshness(unittest.TestCase):
    def test_cited_files_are_code_not_docs(self):
        page = dc.DOCS / "architecture" / "request-lifecycle.md"
        text = ('<!-- sggs:code file="webapp/serve.py" symbol="api" -->\n'
                '<!-- sggs:code file="pipeline/build_db.py" repo="sggs-data" -->\n'
                'See [the gateway](../../gateway/routes.json), [a page](overview.md), [gone](../../nope.py).\n'
                '![Poster 08 — x](../diagrams/posters/08-request-lifecycle.svg)\n')
        files = dc.cited_files(page, text)
        self.assertIn("webapp/serve.py", files)
        self.assertIn("gateway/routes.json", files)
        self.assertNotIn("pipeline/build_db.py", files)          # a sibling's file: not this repository's history
        self.assertNotIn("nope.py", files)                       # missing files are dropped
        self.assertFalse(any(f.startswith("docs/") for f in files))
        self.assertTrue(len(files) > 2)                          # the poster's source-of-truth files come in

    def test_the_report_orders_moved_pages_first_and_is_empty_when_fresh(self):
        rows = [{"page": "docs/a.md", "commit": "aaaaaaa", "date": "2026-09-25", "behind": 3, "cited": ["x.py"], "changed": []},
                {"page": "docs/b.md", "commit": "bbbbbbb", "date": "2026-09-25", "behind": 9, "cited": ["y.py"], "changed": ["y.py"]},
                {"page": "docs/c.md", "commit": "ccccccc", "date": "2026-09-01", "behind": 80, "cited": [], "changed": []}]
        md = dc.freshness_markdown(rows)
        self.assertLess(md.index("docs/b.md"), md.index("docs/c.md"))
        self.assertNotIn("docs/a.md", md)
        self.assertIn("| `docs/b.md` | `bbbbbbb` 2026-09-25 | 9 | `y.py` |", md)
        self.assertEqual(dc.freshness_markdown([rows[0]]), "")

    def test_the_repository_report_runs(self):
        rows = dc.freshness()
        self.assertTrue(any(r["page"] == "docs/process/ci-gates.md" for r in rows))
        self.assertTrue(all(isinstance(r["behind"], int) for r in rows))
