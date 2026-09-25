#!/usr/bin/env python3
"""The wiki's source-level gates — run on every PR (deploy-docs `docs` job) and by `make docs-check`.

    python3 tools/docs_check.py            # check docs/ (+ pinned sibling docs when installed)
    python3 tools/docs_check.py --db PATH  # also verify cited scripture against the pinned database

Every published page (docs/**/*.md except docs/reports/archive and docs/design) must:
  1. carry frontmatter: `title` (8–120 chars, equal to the body's first H1 read as text) and
     `description` (40–200 chars); optional `sidebar.order`, `verified.{commit,date}`;
  2. link only to things that exist: relative targets resolve on disk, `#anchors` resolve to a
     heading (GitHub slug rules), no root-absolute or localhost links (they break on GitHub);
  3. embed widgets correctly: `<!-- sggs:<name> attr="…" -->` names a widget in
     docs-site/plugins/widgets.schema.json, uses only its attributes, and is followed within three
     lines by static fallback text (the page must read without JavaScript);
  4. keep Mermaid on the brand: no `%%{init` directives, hex colours only from docs/brand/tokens.json;
  5. obey the scripture rule: a verse-sized run of Gurmukhi (four words or more, or 30+ characters)
     outside code appears only inside a blockquote whose last line cites
     `— Sri Guru Granth Sahib Ji · Ang N`; with --db, each quoted line must equal a line of that Ang
     byte for byte. Names and titles of up to three words may be written in prose;
  6. carry a valid `verified` stamp where one is required (REQUIRE_VERIFIED, filled per phase);
  7. posters (docs/diagrams/posters/*.svg): the spec in docs/diagrams/README.md (viewBox 1600 wide,
     <title>+<desc>, brand colours, no brand red, text ≥ 16px, steps sidecar in step, footer
     naming existing source files).
Site configuration: docs-site/vercel.json routes /api to the product host (frontend/src/site.ts
SITE_URL) with git deployments off, and docs-site/sources.lock.json is well-formed.

Stdlib only. Output uses GitHub annotations; exit 1 on any error.
"""
from __future__ import annotations

import argparse
import json
import re
import sqlite3
import subprocess
import sys
import unicodedata
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
SITE = ROOT / "docs-site"
SOURCES_DIR = SITE / ".sources"
NOT_PUBLISHED = ("docs/reports/archive/", "docs/design/")
REQUIRE_VERIFIED: tuple[str, ...] = ()   # e.g. ("docs/process/", "docs/engineering/") once stamped (P5)
STALE_AFTER_COMMITS = 60
TITLE_LEN, DESC_LEN = (8, 120), (40, 200)
CITATION_RE = re.compile(r"^—\s*Sri Guru Granth Sahib Ji\s*·\s*Ang\s+(\d{1,4})\s*$")
GURMUKHI_RUN = re.compile(r"[਀-੿][਀-੿‌‍ ]*[਀-੿]|[਀-੿]")
FENCE_RE = re.compile(r"^(`{3,}|~{3,})")
WIDGET_RE = re.compile(r"^<!--\s*sggs:([a-z][a-z0-9-]*)((?:\s+[a-z][a-z0-9-]*=\"[^\"<>]*\")*)\s*-->\s*$")
ATTR_RE = re.compile(r"([a-z][a-z0-9-]*)=\"([^\"<>]*)\"")
LINK_RE = re.compile(r"(?<!\!)\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
DEF_RE = re.compile(r"^\[[^\]]+\]:\s*(\S+)", re.M)
HEX_RE = re.compile(r"#[0-9a-fA-F]{3}(?:[0-9a-fA-F]{3})?\b")


@dataclass
class Problem:
    file: Path
    line: int
    msg: str
    level: str = "error"

    def __str__(self):
        return f"::{self.level} file={_rel(self.file)},line={self.line}::{self.msg}"


def _rel(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:      # a fixture outside the repository (tests)
        return str(path)


# ── helpers ────────────────────────────────────────────────────────────────────────────────────
def published_pages() -> list[Path]:
    pages = [p for p in sorted(DOCS.rglob("*.md"))
             if not str(p.relative_to(ROOT)).startswith(NOT_PUBLISHED)]
    if SOURCES_DIR.exists():
        pages += sorted(p for p in SOURCES_DIR.rglob("*.md") if not p.name.startswith("."))
    return pages


def parse_frontmatter(text: str) -> tuple[dict | None, int]:
    """The small YAML subset the wiki uses: `key: "quoted"` / `key: value` and one level of nesting."""
    if not text.startswith("---\n"):
        return None, 0
    end = text.find("\n---\n", 4)
    if end == -1:
        return {}, 0
    block = text[4:end].splitlines()
    fm: dict = {}
    parent = None
    for raw in block:
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        m = re.match(r"^(\s*)([A-Za-z_][\w-]*):\s*(.*)$", raw)
        if not m:
            return {"__bad__": raw}, len(block) + 2
        indent, key, val = m.groups()
        val = val.strip()
        if val.startswith('"') and val.endswith('"'):
            val = bytes(val[1:-1], "utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8") if "\\" in val else val[1:-1]
        elif val.startswith("'") and val.endswith("'"):
            val = val[1:-1]
        if indent:
            if parent is None:
                return {"__bad__": raw}, len(block) + 2
            fm[parent][key] = val
        elif val == "":
            fm[key] = {}
            parent = key
        else:
            fm[key] = val
            parent = None
    return fm, len(block) + 2


def strip_inline_md(s: str) -> str:
    s = re.sub(r"`([^`]*)`", r"\1", s)
    s = re.sub(r"\*\*([^*]*)\*\*", r"\1", s)
    s = re.sub(r"\*([^*]*)\*", r"\1", s)
    s = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", s)
    return s.strip()


def github_slug(heading: str) -> str:
    s = strip_inline_md(heading).lower()
    s = re.sub(r"[^\w\- ]", "", s, flags=re.UNICODE)
    return s.replace(" ", "-")


def body_lines(text: str, fm_len: int) -> list[tuple[int, str, bool]]:
    """(line number, line, in_code_fence) for the body, 1-based numbering of the whole file."""
    out = []
    fence = None
    for i, line in enumerate(text.splitlines(), 1):
        if i <= fm_len:
            continue
        m = FENCE_RE.match(line)
        if m and (fence is None or line.startswith(fence)):
            fence = None if fence else m.group(1)
            out.append((i, line, True))
            continue
        out.append((i, line, fence is not None))
    return out


def headings(text: str) -> list[str]:
    fm, n = parse_frontmatter(text)
    return [github_slug(l[2:]) if l.startswith("# ") else github_slug(l.lstrip("#").strip())
            for _, l, code in body_lines(text, n) if not code and re.match(r"^#{1,6}\s", l)]


def anchors_of(path: Path) -> set[str]:
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return set()
    seen: dict[str, int] = {}
    out = set()
    for slug in headings(text):
        n = seen.get(slug, 0)
        out.add(slug if n == 0 else f"{slug}-{n}")
        seen[slug] = n + 1
    return out


def strip_code_spans(line: str) -> str:
    return re.sub(r"`[^`]*`", "", line)


def load_tokens_hex() -> set[str]:
    t = json.loads((DOCS / "brand" / "tokens.json").read_text(encoding="utf-8"))
    hexes = {"#FFFFFF", "#201A12", "#F3ECDD"}  # white and the two inks the site theme adds
    for group in ("surfaces", "soul", "brand", "status"):
        for legs in t[group].values():
            hexes.update(h.upper() for h in legs)
    hexes.discard("#DA291C")  # brand red never appears in diagrams
    return hexes


def widget_schema() -> dict:
    return json.loads((SITE / "plugins" / "widgets.schema.json").read_text(encoding="utf-8"))["widgets"]


# ── checks ─────────────────────────────────────────────────────────────────────────────────────
def check_page(path: Path, tokens_hex: set[str], widgets: dict, db: sqlite3.Connection | None) -> list[Problem]:
    P: list[Problem] = []
    text = path.read_text(encoding="utf-8")
    rel = _rel(path)
    fm, fm_len = parse_frontmatter(text)
    if fm is None:
        return [Problem(path, 1, "missing frontmatter (title, description)")]
    if "__bad__" in fm:
        return [Problem(path, 1, f"frontmatter line not understood: {fm['__bad__']!r}")]
    lines = body_lines(text, fm_len)

    # 1. frontmatter
    title, desc = str(fm.get("title", "")), str(fm.get("description", ""))
    if not TITLE_LEN[0] <= len(title) <= TITLE_LEN[1]:
        P.append(Problem(path, 2, f"title must be {TITLE_LEN[0]}–{TITLE_LEN[1]} characters (is {len(title)})"))
    if not DESC_LEN[0] <= len(desc) <= DESC_LEN[1]:
        P.append(Problem(path, 3, f"description must be {DESC_LEN[0]}–{DESC_LEN[1]} characters (is {len(desc)})"))
    h1 = next(((n, l) for n, l, code in lines if not code and l.startswith("# ")), None)
    if h1 is None:
        P.append(Problem(path, fm_len + 1, "the body needs a `# Title` heading (GitHub shows it; the site strips it)"))
    elif strip_inline_md(h1[1][2:]) != title:
        P.append(Problem(path, h1[0], f"H1 {strip_inline_md(h1[1][2:])!r} must equal frontmatter title {title!r}"))
    if "verified" in fm:
        v = fm["verified"] if isinstance(fm["verified"], dict) else {}
        if not re.fullmatch(r"[0-9a-f]{7,40}", str(v.get("commit", ""))) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", str(v.get("date", ""))):
            P.append(Problem(path, 1, "verified needs commit (7–40 hex) and date (YYYY-MM-DD)"))
        else:
            P.extend(check_verified_commit(path, str(v["commit"])))
    elif any(rel.startswith(d) for d in REQUIRE_VERIFIED):
        P.append(Problem(path, 1, "this page must carry `verified: {commit, date}` (last read against the code)"))

    # 2. links  3. widgets  4. mermaid  5. scripture
    quote_block: list[tuple[int, str]] = []
    mermaid: list[str] | None = None
    for n, line, code in lines:
        if code:
            if mermaid is not None:
                if FENCE_RE.match(line):
                    P.extend(check_mermaid(path, n, "\n".join(mermaid), tokens_hex))
                    mermaid = None
                else:
                    mermaid.append(line)
            elif re.match(r"^(`{3,}|~{3,})\s*mermaid\b", line):
                mermaid = []
            continue
        for m in LINK_RE.finditer(strip_code_spans(line)):
            P.extend(check_link(path, n, m.group(1)))
        if line.startswith("[") and DEF_RE.match(line):
            P.extend(check_link(path, n, DEF_RE.match(line).group(1)))
        w = WIDGET_RE.match(line.strip())
        if w:
            P.extend(check_widget(path, n, w, widgets, lines))
        # scripture: collect blockquote runs
        if line.startswith(">"):
            quote_block.append((n, line[1:].strip()))
        else:
            if quote_block:
                P.extend(check_quote(path, quote_block, db))
                quote_block = []
            for run in GURMUKHI_RUN.finditer(strip_code_spans(line)):
                if is_phrase(run.group(0)):
                    P.append(Problem(path, n, "Gurmukhi phrase outside code must be a cited blockquote ending "
                                             "`— Sri Guru Granth Sahib Ji · Ang N` (technical tokens go in code spans)"))
    if quote_block:
        P.extend(check_quote(path, quote_block, db))
    return P


def is_phrase(run: str) -> bool:
    """A verse-sized run of Gurmukhi. Names and titles (a bani, a salok, a raag — up to three
    words, under 30 characters) may be written in prose; anything longer is a quotation."""
    run = run.strip()
    if run == "ੴ":
        return False
    return len(run.split()) >= 4 or len(run) >= 30


def check_link(path: Path, n: int, target: str) -> list[Problem]:
    if re.match(r"^(?:[a-z][a-z0-9+.-]*:|//)", target, re.I):
        if "localhost" in target or "127.0.0.1" in target:
            return [Problem(path, n, f"link to a local host: {target}")]
        return []
    if target.startswith("#"):
        return [] if target[1:] in anchors_of(path) else [Problem(path, n, f"anchor {target} not found in this page")]
    if target.startswith("/"):
        return [Problem(path, n, f"root-absolute link {target} breaks on GitHub; use a relative path")]
    file_part, _, anchor = target.partition("#")
    dest = (path.parent / file_part).resolve()
    if not dest.exists():
        return [Problem(path, n, f"broken link: {target} ({_rel(dest)} does not exist)")]
    if anchor and dest.suffix == ".md" and anchor not in anchors_of(dest):
        return [Problem(path, n, f"anchor #{anchor} not found in {_rel(dest)}")]
    return []


def check_widget(path: Path, n: int, m: re.Match, widgets: dict, lines) -> list[Problem]:
    name, attrs = m.group(1), dict(ATTR_RE.findall(m.group(2)))
    spec = widgets.get(name)
    if spec is None:
        return [Problem(path, n, f"unknown widget sggs:{name} (docs-site/plugins/widgets.schema.json)")]
    P = [Problem(path, n, f"widget sggs:{name} has no attribute {k!r}") for k in attrs if k not in spec["attrs"]]
    P += [Problem(path, n, f"widget sggs:{name} needs attribute {k!r}") for k, v in spec["attrs"].items() if v.get("required") and k not in attrs]
    following = [l for nn, l, code in lines if n < nn <= n + 3]
    if not any(l.strip() and not WIDGET_RE.match(l.strip()) and not l.startswith("#") for l in following):
        P.append(Problem(path, n, f"widget sggs:{name} needs static fallback text within the next 3 lines"))
    return P


def check_mermaid(path: Path, n: int, src: str, tokens_hex: set[str]) -> list[Problem]:
    P = []
    if re.search(r"%%\{\s*init", src):
        P.append(Problem(path, n, "Mermaid `%%{init` directives are not allowed — the site theme is central"))
    bad = sorted({h.upper() for h in HEX_RE.findall(src)} - tokens_hex)
    if bad:
        P.append(Problem(path, n, f"Mermaid colours must come from docs/brand/tokens.json; not allowed: {', '.join(bad)}"))
    if "accTitle" not in src:
        P.append(Problem(path, n, "Mermaid diagram has no `accTitle:` (screen readers get no name)", level="warning"))
    return P


def check_quote(path: Path, block: list[tuple[int, str]], db: sqlite3.Connection | None) -> list[Problem]:
    gm_lines = [(n, l) for n, l in block if GURMUKHI_RUN.search(strip_code_spans(l)) and is_phrase(strip_code_spans(l))]
    if not gm_lines:
        return []
    last_n, last = block[-1]
    m = CITATION_RE.match(strip_inline_md(last))
    if not m:
        return [Problem(path, last_n, "a blockquote with scripture must end with `— Sri Guru Granth Sahib Ji · Ang N`")]
    ang = int(m.group(1))
    if not 1 <= ang <= 1430:
        return [Problem(path, last_n, f"Ang {ang} is out of range 1–1430")]
    if db is None:
        return [Problem(path, last_n, f"scripture cited (Ang {ang}) but no database to verify it against (run with --db)", level="notice")]
    rows = {r[0] for r in db.execute("SELECT gurmukhi FROM lines WHERE ang=?", (ang,))}
    rows |= {r[0] for r in db.execute("SELECT text FROM lines WHERE ang=?", (ang,))}
    rows = {unicodedata.normalize("NFC", r) for r in rows if r}
    P = []
    for n, l in gm_lines:
        q = unicodedata.normalize("NFC", strip_inline_md(l).strip())
        if q not in rows:
            P.append(Problem(path, n, f"quoted line is not a verbatim line of Ang {ang} in the pinned database"))
    return P


def check_verified_commit(path: Path, commit: str) -> list[Problem]:
    try:
        subprocess.run(["git", "cat-file", "-e", f"{commit}^{{commit}}"], cwd=ROOT, check=True, capture_output=True)
        behind = subprocess.run(["git", "rev-list", "--count", f"{commit}..HEAD"], cwd=ROOT, capture_output=True, text=True)
        n = int(behind.stdout.strip() or 0) if behind.returncode == 0 else 0
    except (subprocess.CalledProcessError, FileNotFoundError):
        return [Problem(path, 1, f"verified commit {commit[:7]} is not in this repository's history", level="warning")]
    if n > STALE_AFTER_COMMITS:
        return [Problem(path, 1, f"verified against {commit[:7]}, {n} commits ago — re-read this page against the code", level="warning")]
    return []


def check_posters(tokens_hex: set[str]) -> list[Problem]:
    P: list[Problem] = []
    pdir = DOCS / "diagrams" / "posters"
    if not pdir.exists():
        return P
    referenced = set()
    for page in published_pages():
        for m in re.finditer(r"!\[([^\]]*)\]\(([^)\s]*diagrams/posters/[^)\s]+\.svg)\)", page.read_text(encoding="utf-8")):
            referenced.add(Path(m.group(2)).name)
            if not m.group(1).strip():
                P.append(Problem(page, 1, f"poster {Path(m.group(2)).name} needs alt text"))
    for svg in sorted(pdir.glob("*.svg")):
        s = svg.read_text(encoding="utf-8")
        head = s[:2000]
        if not re.search(r'viewBox="0 0 1600 \d+"', head):
            P.append(Problem(svg, 1, 'poster viewBox must be "0 0 1600 H"'))
        if 'width="100%"' not in head or re.search(r'<svg[^>]*\sheight="', head):
            P.append(Problem(svg, 1, 'poster <svg> needs width="100%" and no fixed height'))
        if 'role="img"' not in head:
            P.append(Problem(svg, 1, 'poster <svg> needs role="img"'))
        if not re.search(r"<title>[^<]{5,}</title>", s) or not re.search(r"<desc>[^<]{40,}</desc>", s):
            P.append(Problem(svg, 1, "poster needs <title> (its alt) and a <desc> of at least 40 characters"))
        if "#DA291C" in s.upper():
            P.append(Problem(svg, 1, "brand red never appears in a poster"))
        bad = sorted({h.upper() for h in HEX_RE.findall(s)} - tokens_hex)
        if bad:
            P.append(Problem(svg, 1, f"poster colours must come from docs/brand/tokens.json; not allowed: {', '.join(bad)}"))
        small = [fs for fs in re.findall(r'font-size="?(\d+(?:\.\d+)?)', s) if float(fs) < 16]
        small += [fs for fs in re.findall(r"font-size:\s*(\d+(?:\.\d+)?)px", s) if float(fs) < 16]
        if small:
            P.append(Problem(svg, 1, f"poster text must be at least 16px (found {sorted(set(small))})"))
        if "Source of truth:" not in s:
            P.append(Problem(svg, 1, "poster footer must read `Source of truth: <files>`"))
        else:
            for f in re.findall(r"Source of truth:\s*([^<]+)<", s)[:1]:
                for name in re.split(r"\s*[·,]\s*", f.strip()):
                    name = name.strip()
                    if name and not (ROOT / name).exists() and not name.startswith("Algorythmos-AI/"):
                        P.append(Problem(svg, 1, f"poster footer names a file that does not exist: {name}"))
        if not re.search(r"v\d+\.\d+\.\d+ · verified \d{4}-\d{2}-\d{2} · [0-9a-f]{7}", s):
            P.append(Problem(svg, 1, "poster needs a version stamp `vX.Y.Z · verified YYYY-MM-DD · <sha7>`"))
        steps_svg = set(re.findall(r'id="(step-\d{2})"', s))
        sidecar = svg.with_suffix(".steps.json")
        if sidecar.exists():
            try:
                steps = json.loads(sidecar.read_text(encoding="utf-8"))
                ids = {st["id"] for st in steps}
                for st in steps:
                    for k in ("id", "title", "caption"):
                        if not st.get(k):
                            P.append(Problem(sidecar, 1, f"step {st.get('id', '?')} needs {k}"))
                if ids != steps_svg:
                    P.append(Problem(sidecar, 1, f"steps sidecar and <g id=\"step-NN\"> groups differ: {sorted(ids ^ steps_svg)}"))
            except (ValueError, TypeError, KeyError) as e:
                P.append(Problem(sidecar, 1, f"steps sidecar is not a list of steps: {e}"))
        elif steps_svg:
            P.append(Problem(svg, 1, "poster has step groups but no .steps.json sidecar"))
        if svg.name not in referenced:
            P.append(Problem(svg, 1, "poster is not referenced by any page"))
    return P


def check_site_config() -> list[Problem]:
    P: list[Problem] = []
    vercel = SITE / "vercel.json"
    site_ts = ROOT / "frontend" / "src" / "site.ts"
    try:
        v = json.loads(vercel.read_text(encoding="utf-8"))
        host = re.search(r'SITE_URL\s*=\s*"https://([^/"]+)"', site_ts.read_text(encoding="utf-8")).group(1)
        rw = [r for r in v.get("rewrites", []) if r.get("source") == "/api/:path*"]
        if not rw or rw[0].get("destination") != f"https://{host}/api/:path*":
            P.append(Problem(vercel, 1, f"the /api rewrite must go to https://{host}/api/:path* (frontend/src/site.ts SITE_URL)"))
        git = v.get("git", {}).get("deploymentEnabled", {})
        if git.get("main") is not False or git.get("integration") is not False:
            P.append(Problem(vercel, 1, "git.deploymentEnabled must be false for main and integration (deploys are CI-gated)"))
        csp = next((h["value"] for h in v["headers"][0]["headers"] if h["key"] == "Content-Security-Policy"), "")
        if "connect-src 'self'" not in csp or "frame-ancestors 'none'" not in csp:
            P.append(Problem(vercel, 1, "CSP must keep connect-src 'self' and frame-ancestors 'none'"))
    except (OSError, ValueError, AttributeError, KeyError, IndexError) as e:
        P.append(Problem(vercel, 1, f"cannot validate docs-site/vercel.json: {e}"))
    lock = SITE / "sources.lock.json"
    try:
        srcs = json.loads(lock.read_text(encoding="utf-8"))["sources"]
        for name, s in srcs.items():
            if not (isinstance(s.get("repository"), str) and s["repository"].count("/") == 1):
                P.append(Problem(lock, 1, f"{name}: repository must be owner/name"))
            if not re.fullmatch(r"[0-9a-f]{40}", str(s.get("commit", ""))):
                P.append(Problem(lock, 1, f"{name}: commit must be a 40-hex sha"))
            if not re.fullmatch(r"[a-z][a-z0-9-]*", str(s.get("alias", ""))):
                P.append(Problem(lock, 1, f"{name}: alias must be a lowercase URL segment"))
            if not isinstance(s.get("include"), list) or not isinstance(s.get("files"), dict):
                P.append(Problem(lock, 1, f"{name}: needs include (list) and files (path -> sha256)"))
    except (OSError, ValueError, KeyError, AttributeError) as e:
        P.append(Problem(lock, 1, f"cannot read sources.lock.json: {e}"))
    return P


def run(db_path: Path | None = None) -> list[Problem]:
    tokens_hex = load_tokens_hex()
    widgets = widget_schema()
    db = None
    if db_path and db_path.exists():
        db = sqlite3.connect(f"file:{db_path}?mode=ro&immutable=1", uri=True)
    problems: list[Problem] = []
    for page in published_pages():
        problems += check_page(page, tokens_hex, widgets, db)
    problems += check_posters(tokens_hex)
    problems += check_site_config()
    return problems


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--db", type=Path, default=ROOT / "db" / "sggs.sqlite", help="pinned database (verifies cited scripture)")
    a = ap.parse_args(argv)
    problems = run(a.db)
    for p in problems:
        print(p)
    errors = [p for p in problems if p.level == "error"]
    n_pages = len(published_pages())
    print(f"docs_check: {n_pages} pages, {len(errors)} error(s), {len(problems) - len(errors)} warning(s)/notice(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
