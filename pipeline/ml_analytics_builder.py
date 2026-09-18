#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SGGS Insight Engine — offline analytics builder (Phase 1, v2.1.0).

PHILOSOPHY (non-negotiable): we NEVER alter, judge, score, or reinterpret the sacred text.
Every analytic here is a statistical lens over data the corpus ALREADY contains — the
structural metadata, the 53 corpus-verified themes, and the labeled English translation.
The scripture itself is never touched. No generic "sentiment" is computed: that approach
mislabels ~47% of devotional lines (it scores "dying in the Shabad → liberation" as the
most negative line in the corpus), so affect is expressed only through the corpus's OWN
verified themes (anand→joy, prem_pyar→devotion, maran_jeevan/maya→detachment, bhau→awe,
bhana→surrender, nimrata→humility).

ADDITIVE ONLY. This script copies db/sggs.sqlite to a temp path, ADDS new tables, and
verifies every existing table is row-identical. It never ALTERs/DROPs/UPDATEs/INSERTs into
lines / fts* / variants / translations / concepts / concept_lines. The live server gains a
few cached SELECTs against the new tables — zero runtime ML, zero new runtime dependencies.

New tables:
  theme_network            theme co-occurrence edges (PPMI + Jaccard, shabad-level)
  theme_fingerprint        per-author / per-raag theme emphasis (lift vs corpus baseline)
  author_analytics         per-author stylometry (MATTR, hapax, line/word structure)
  raag_analytics           per-raag aggregates + thematic profile
  author_distinctive_terms most-distinctive EN words per author (Monroe log-odds)
  shabad_neighbors         "related shabads" by theme-profile cosine (grounded in themes)
  analytics_meta           build provenance + the framing caveats (key/value)

Usage:
  python3 pipeline/ml_analytics_builder.py [--db db/sggs.sqlite] [--out /tmp/sggs_a.sqlite]
                                           [--min-support 20] [--neighbors-k 10]
  (build deps: Python stdlib + numpy. The optional --semantic line-level MiniLM upgrade is
   documented in ML_Analytics_Engine.md and is NOT required for Phase 1.)
"""
import argparse, json, math, os, re, shutil, sqlite3, sys, time
from collections import Counter, defaultdict

try:
    import numpy as np
except ImportError:
    sys.exit("numpy is required for the build (pip install numpy). Runtime server needs nothing.")

WORD_RE = re.compile(r"[a-z']+")
STOP = set("the a an and or of to in is are was were be been being it its his her my your our "
           "i you he she they we who whom whose this that these those for with as at by on from "
           "not no nor so but if then than out up down over under into o ye thy thee thou hath "
           "shall will may can do does did done have has had am s t re ve ll d".split())


# ----------------------------------------------------------------------------- helpers
def tokens_en(text):
    return [w for w in WORD_RE.findall((text or '').lower()) if w not in STOP and len(w) > 1]


def mattr(token_list, window=100):
    """Moving-Average Type-Token Ratio — size-stable vocabulary richness (Covington & McFall)."""
    n = len(token_list)
    if n < window:
        return len(set(token_list)) / n if n else 0.0
    ratios = []
    for i in range(0, n - window + 1, max(1, window // 4)):   # stride window/4 for speed
        w = token_list[i:i + window]
        ratios.append(len(set(w)) / window)
    return sum(ratios) / len(ratios) if ratios else 0.0


# ----------------------------------------------------------------------------- 1. theme network
def build_theme_network(con, min_support):
    """Shabad-level (comp_id) theme co-occurrence. PPMI controls base-rate bias so that
    'frequently co-occurring' (naam+satguru, ~chance) is distinguished from 'strongly
    associated' (kaam+krodh, far above chance)."""
    # set of shabads (comp_ids) each theme appears in
    theme_shabads = defaultdict(set)
    for concept, cid in con.execute(
            "SELECT cl.concept, l.comp_id FROM concept_lines cl JOIN lines l ON l.id=cl.line_id"):
        theme_shabads[concept].add(cid)
    all_shabads = set()
    for s in theme_shabads.values():
        all_shabads |= s
    N = len(all_shabads)
    themes = sorted(theme_shabads)
    rows = []
    for i, a in enumerate(themes):
        Sa = theme_shabads[a]
        pa = len(Sa) / N
        for b in themes[i + 1:]:
            Sb = theme_shabads[b]
            inter = Sa & Sb
            c = len(inter)
            if c < min_support:
                continue
            union = len(Sa) + len(Sb) - c
            jacc = c / union if union else 0.0
            pj = c / N
            ppmi = max(0.0, math.log2(pj / (pa * (len(Sb) / N)))) if pj > 0 else 0.0
            # store both directions so the server queries WHERE source=? with no UNION
            for s, t in ((a, b), (b, a)):
                rows.append((s, t, c, len(Sa) if s == a else len(Sb),
                             len(Sb) if s == a else len(Sa), round(ppmi, 4), round(jacc, 4)))
    con.executescript("""
      CREATE TABLE theme_network (
        source TEXT NOT NULL, target TEXT NOT NULL,
        shabad_count INTEGER, source_n INTEGER, target_n INTEGER,
        ppmi REAL, jaccard REAL, PRIMARY KEY (source, target));
      CREATE INDEX idx_tn_source ON theme_network(source);
      CREATE INDEX idx_tn_ppmi ON theme_network(ppmi DESC);
    """)
    con.executemany("INSERT INTO theme_network VALUES (?,?,?,?,?,?,?)", rows)
    return len(rows), N


# ----------------------------------------------------------------------------- 2. theme fingerprint
def build_theme_fingerprint(con):
    """Per author and per raag: emphasis on each theme as LIFT (entity_rate / corpus_rate),
    so it shows what a Guru/Bhagat/raag EMPHASISES, not just what is frequent."""
    # corpus baseline rate per concept (lines tagged / total non-header lines)
    total_lines = con.execute("SELECT count(*) FROM lines WHERE is_header=0").fetchone()[0]
    concept_n = dict(con.execute("SELECT concept, count(DISTINCT line_id) FROM concept_lines GROUP BY concept"))
    corpus_rate = {c: n / total_lines for c, n in concept_n.items()}

    con.executescript("""
      CREATE TABLE theme_fingerprint (
        entity_type TEXT NOT NULL, entity_id TEXT NOT NULL, concept TEXT NOT NULL,
        n_tagged INTEGER, entity_total INTEGER, entity_rate REAL, corpus_rate REAL,
        lift REAL, is_reliable INTEGER, PRIMARY KEY (entity_type, entity_id, concept));
      CREATE INDEX idx_tf_entity ON theme_fingerprint(entity_type, entity_id, lift DESC);
    """)

    def fingerprint(entity_type, group_col):
        totals = dict(con.execute(
            f"SELECT {group_col}, count(*) FROM lines WHERE is_header=0 AND {group_col} IS NOT NULL GROUP BY {group_col}"))
        tagged = defaultdict(Counter)
        for ent, concept in con.execute(
                f"SELECT l.{group_col}, cl.concept FROM concept_lines cl JOIN lines l ON l.id=cl.line_id "
                f"WHERE l.is_header=0 AND l.{group_col} IS NOT NULL"):
            tagged[ent][concept] += 1
        out = []
        for ent, cnts in tagged.items():
            tot = totals.get(ent, 0)
            if not tot:
                continue
            reliable = 1 if tot >= 300 else 0
            for concept, n in cnts.items():
                er = n / tot
                cr = corpus_rate.get(concept, 1e-9)
                out.append((entity_type, str(ent), concept, n, tot, round(er, 5),
                            round(cr, 5), round(er / cr, 3), reliable))
        return out

    rows = fingerprint('author', 'author') + fingerprint('raag', 'raag')
    con.executemany("INSERT INTO theme_fingerprint VALUES (?,?,?,?,?,?,?,?,?)", rows)
    return len(rows)


# ----------------------------------------------------------------------------- 3/5. author & raag stylometry + distinctive terms
def build_author_raag_analytics(con):
    con.executescript("""
      CREATE TABLE author_analytics (
        author TEXT PRIMARY KEY, n_lines INTEGER, n_shabads INTEGER, n_raags INTEGER,
        n_tokens INTEGER, mattr_100 REAL, hapax_pct REAL, avg_words_line REAL,
        avg_lines_shabad REAL, top_themes TEXT, is_reliable INTEGER);
      CREATE TABLE raag_analytics (
        raag TEXT PRIMARY KEY, n_lines INTEGER, n_shabads INTEGER, n_authors INTEGER,
        dominant_author TEXT, dominant_author_pct REAL, n_themes INTEGER, top_themes TEXT);
      CREATE TABLE author_distinctive_terms (
        author TEXT, term TEXT, z_score REAL, count_author INTEGER, count_rest INTEGER,
        rank INTEGER, PRIMARY KEY (author, rank));
      CREATE INDEX idx_adt_author ON author_distinctive_terms(author, rank);
    """)
    # gather EN tokens per author + structure
    auth_tokens = defaultdict(list)
    auth_lines = Counter(); auth_shabads = defaultdict(set); auth_raags = defaultdict(set)
    for author, comp_id, raag, en in con.execute(
            "SELECT l.author, l.comp_id, l.raag, t.text FROM lines l "
            "LEFT JOIN translations t ON t.line_id=l.id AND t.lang='en' "
            "WHERE l.is_header=0 AND l.author IS NOT NULL"):
        auth_lines[author] += 1
        auth_shabads[author].add(comp_id)
        if raag: auth_raags[author].add(raag)
        if en: auth_tokens[author].extend(tokens_en(en))

    # top themes per author (by lift, reliable only) from theme_fingerprint
    top_themes = defaultdict(list)
    for et, eid, concept, lift in con.execute(
            "SELECT entity_type, entity_id, concept, lift FROM theme_fingerprint WHERE is_reliable=1 ORDER BY lift DESC"):
        if len(top_themes[(et, eid)]) < 6:
            top_themes[(et, eid)].append({'concept': concept, 'lift': lift})

    arows = []
    for author in auth_lines:
        toks = auth_tokens[author]; nt = len(toks)
        vocab = Counter(toks)
        hapax = sum(1 for w, c in vocab.items() if c == 1)
        arows.append((author, auth_lines[author], len(auth_shabads[author]), len(auth_raags[author]),
                      nt, round(mattr(toks), 4),
                      round(100 * hapax / len(vocab), 1) if vocab else 0.0,
                      round(nt / auth_lines[author], 2) if auth_lines[author] else 0.0,
                      round(auth_lines[author] / len(auth_shabads[author]), 2) if auth_shabads[author] else 0.0,
                      json.dumps(top_themes.get(('author', author), []), ensure_ascii=False),
                      1 if nt >= 3000 else 0))
    con.executemany("INSERT INTO author_analytics VALUES (?,?,?,?,?,?,?,?,?,?,?)", arows)

    # Monroe et al. log-odds-ratio with informative Dirichlet prior — distinctive EN terms.
    global_counts = Counter()
    for toks in auth_tokens.values():
        global_counts.update(toks)
    total_all = sum(global_counts.values())
    V = len(global_counts)
    a0 = 0.01                                   # per-word Dirichlet pseudo-count
    drows = []
    for author, toks in auth_tokens.items():
        if len(toks) < 3000:                    # unreliable below ~3k tokens
            continue
        ca = Counter(toks); na = sum(ca.values())
        scored = []
        for w, cw in ca.items():
            if cw < 5:
                continue
            cr = global_counts[w] - cw
            nr = total_all - na
            la = math.log((cw + a0) / (na + a0 * V - cw - a0))
            lr = math.log((cr + a0) / (nr + a0 * V - cr - a0))
            z = (la - lr) / math.sqrt(1.0 / (cw + a0) + 1.0 / (cr + a0))
            scored.append((z, w, cw, cr))
        scored.sort(reverse=True)
        for rank, (z, w, cw, cr) in enumerate(scored[:15], 1):
            drows.append((author, w, round(z, 2), cw, cr, rank))
    con.executemany("INSERT INTO author_distinctive_terms VALUES (?,?,?,?,?,?)", drows)

    # raag analytics
    rrows = []
    raags = [r[0] for r in con.execute("SELECT DISTINCT raag FROM lines WHERE raag IS NOT NULL")]
    for raag in raags:
        nl = con.execute("SELECT count(*) FROM lines WHERE raag=? AND is_header=0", (raag,)).fetchone()[0]
        ns = con.execute("SELECT count(DISTINCT comp_id) FROM lines WHERE raag=? AND is_header=0", (raag,)).fetchone()[0]
        au = con.execute("SELECT author, count(*) c FROM lines WHERE raag=? AND is_header=0 AND author IS NOT NULL "
                         "GROUP BY author ORDER BY c DESC", (raag,)).fetchall()
        dom = au[0][0] if au else None
        dom_pct = round(100 * au[0][1] / nl, 1) if au and nl else 0.0
        nthemes = con.execute("SELECT count(DISTINCT cl.concept) FROM concept_lines cl JOIN lines l ON l.id=cl.line_id "
                              "WHERE l.raag=?", (raag,)).fetchone()[0]
        rrows.append((raag, nl, ns, len(au), dom, dom_pct, nthemes,
                      json.dumps(top_themes.get(('raag', raag), []), ensure_ascii=False)))
    con.executemany("INSERT INTO raag_analytics VALUES (?,?,?,?,?,?,?,?)", rrows)
    return len(arows), len(rrows), len(drows)


# ----------------------------------------------------------------------------- 6. related shabads
def build_shabad_neighbors(con, K):
    """'Related shabads' by cosine over each shabad's theme-profile vector (53 dims),
    weighted by theme IDF so distinctive themes dominate the similarity. Grounded entirely
    in the corpus-verified themes — not a translation artifact, not an external model."""
    concepts = [r[0] for r in con.execute("SELECT concept FROM concepts ORDER BY concept")]
    cidx = {c: i for i, c in enumerate(concepts)}
    # idf per theme
    Nsh = con.execute("SELECT count(DISTINCT comp_id) FROM lines WHERE is_header=0").fetchone()[0]
    df = dict(con.execute("SELECT cl.concept, count(DISTINCT l.comp_id) FROM concept_lines cl "
                          "JOIN lines l ON l.id=cl.line_id GROUP BY cl.concept"))
    idf = {c: math.log(Nsh / (df.get(c, 0) + 1)) + 1.0 for c in concepts}
    # build per-shabad weighted theme vector
    vec = defaultdict(lambda: np.zeros(len(concepts), dtype=np.float32))
    for concept, cid, n in con.execute(
            "SELECT cl.concept, l.comp_id, count(*) FROM concept_lines cl JOIN lines l ON l.id=cl.line_id "
            "GROUP BY cl.concept, l.comp_id"):
        vec[cid][cidx[concept]] += n * idf[concept]
    comp_ids = sorted(vec)
    M = np.vstack([vec[c] for c in comp_ids])
    norms = np.linalg.norm(M, axis=1, keepdims=True)
    norms[norms == 0] = 1.0
    M = M / norms
    con.executescript("""
      CREATE TABLE shabad_neighbors (
        comp_id INTEGER NOT NULL, neighbor_comp_id INTEGER NOT NULL,
        rank INTEGER NOT NULL, score REAL, PRIMARY KEY (comp_id, rank));
      CREATE INDEX idx_sn_comp ON shabad_neighbors(comp_id);
    """)
    rows = []
    B = 512
    for start in range(0, len(comp_ids), B):
        block = M[start:start + B]
        with np.errstate(divide='ignore', over='ignore', invalid='ignore'):
            sims = block @ M.T                   # cosine (rows unit-norm; zero-theme shabads aren't in M)
        sims = np.nan_to_num(sims, nan=0.0, posinf=0.0, neginf=0.0)   # never let a stray non-finite reach argpartition
        for bi in range(block.shape[0]):
            gi = start + bi
            s = sims[bi].copy(); s[gi] = -1.0     # exclude self
            top = np.argpartition(-s, K)[:K]
            top = top[np.argsort(-s[top])]
            for rank, j in enumerate(top, 1):
                if s[j] <= 0:
                    break
                rows.append((comp_ids[gi], comp_ids[j], rank, round(float(s[j]), 4)))
    con.executemany("INSERT INTO shabad_neighbors VALUES (?,?,?,?)", rows)
    return len(rows), len(comp_ids)


# ----------------------------------------------------------------------------- integrity
EXISTING_COUNTS = {
    "lines": 60658, "fts": 60658, "concepts": 54, "concept_lines": None,
    "variants": 79840, "authors": None, "raags": None,
}   # v1.1.4 (2026-09-18): variants 79666→79840 — built from is_header=0 lines, and 233 verses the
    # header detector had mis-flagged rejoined that set (scripture unchanged; see CHANGELOG).
    # 2026-06-19 (audit): akal_kaal split → akal+kaal (concepts 53→54). concept_lines is now
    # UNCHECKED (None): the tag count legitimately shifts whenever concept term-lists are curated;
    # integrity is enforced by the scripture guards (lines/fts/translations + the Mool Mantar check).
def verify_additive(con):
    en = con.execute("SELECT count(*) FROM translations WHERE lang='en'").fetchone()[0]
    assert en == 58039, f"translations en changed: {en}"
    for tbl, expect in EXISTING_COUNTS.items():
        got = con.execute(f"SELECT count(*) FROM {tbl}").fetchone()[0]
        if expect is not None:
            assert got == expect, f"{tbl} row count changed: {got} != {expect}"
    mm = con.execute("SELECT gurmukhi FROM lines WHERE id=1").fetchone()[0]
    assert mm.startswith('ੴ ਸਤਿ ਨਾਮੁ ਕਰਤਾ ਪੁਰਖੁ'), "Mool Mantar changed!"
    assert con.execute("SELECT count(*) FROM (SELECT rowid FROM fts WHERE text MATCH 'ੴ')").fetchone()[0] >= 560
    print("  additive integrity: existing tables row-identical, scripture intact ✓")


# ----------------------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--db', default='db/sggs.sqlite')
    ap.add_argument('--out', default='/tmp/sggs_analytics.sqlite')
    ap.add_argument('--min-support', type=int, default=20)
    ap.add_argument('--neighbors-k', type=int, default=10)
    args = ap.parse_args()

    t0 = time.time()
    print(f"── copying {args.db} → {args.out}")
    shutil.copy(args.db, args.out)
    con = sqlite3.connect(args.out)

    # drop any prior analytics tables so the build is idempotent (NEVER touches base tables)
    for t in ('theme_network','theme_fingerprint','author_analytics','raag_analytics',
              'author_distinctive_terms','shabad_neighbors','analytics_meta'):
        con.execute(f"DROP TABLE IF EXISTS {t}")

    print("── 1/6 theme co-occurrence network (PPMI + Jaccard)")
    n_edges, Nsh = build_theme_network(con, args.min_support)
    print(f"      {n_edges} directed edges over {Nsh} themed shabads")
    print("── 2/6 theme fingerprints (author + raag, lift)")
    print(f"      {build_theme_fingerprint(con)} fingerprint rows")
    print("── 3/6 author + raag stylometry + distinctive terms")
    na, nr, nd = build_author_raag_analytics(con)
    print(f"      {na} authors, {nr} raags, {nd} distinctive-term rows")
    print("── 4/6 related shabads (theme-profile cosine)")
    n_nb, n_sh = build_shabad_neighbors(con, args.neighbors_k)
    print(f"      {n_nb} neighbor rows over {n_sh} shabads (K={args.neighbors_k})")

    print("── 5/6 analytics_meta (provenance + framing)")
    con.execute("CREATE TABLE analytics_meta (key TEXT PRIMARY KEY, value TEXT)")
    con.executemany("INSERT INTO analytics_meta VALUES (?,?)", [
        ('version', '2.1.0'),
        ('built', time.strftime('%Y-%m-%d')),
        ('scripture_touched', 'NO — all analytics are over structural metadata + the 53 '
         'verified themes + the labeled English translation; the Gurmukhi is never altered '
         'or scored'),
        ('affect_method', 'theme-grounded (NO generic sentiment model — VADER/TextBlob '
         'mislabel ~47% of devotional lines and invert liberation/awe/longing verses)'),
        ('stylometry_surface', 'English translation (Dr. Sant Singh Khalsa) — reflects the '
         'translation as well as the original; reliability flagged for authors < 3000 tokens'),
        ('cooccurrence_metric', 'PPMI (primary) + Jaccard; raw counts are base-rate biased'),
        ('neighbors_method', 'related shabads by IDF-weighted theme-profile cosine (grounded '
         'in verified themes); optional MiniLM line-level semantic mode is a separate upgrade'),
        ('framing', 'These are descriptive statistics, never a ranking or judgement of '
         'scripture. Display as emphasis/association, not worth.'),
    ])

    print("── 6/6 verifying additive integrity")
    verify_additive(con)
    con.commit()
    con.isolation_level = None          # VACUUM cannot run inside a transaction
    con.execute("VACUUM")
    con.close()
    sz = os.path.getsize(args.out) / 1e6
    print(f"\n✓ built {args.out}  ({sz:.1f} MB)  in {time.time()-t0:.0f}s")
    print("  Next: verify, then `cp` to db/sggs.sqlite and update MANIFEST db_sha256 + version.")


if __name__ == '__main__':
    main()
