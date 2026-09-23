#!/usr/bin/env python3
"""
build_semantic_vectors_lite.py — Phase 2 semantic builder (LITE, exact lexical).

Produces the additive `line_neighbors(line_id, neighbor_id, score)` table that powers
/api/neighbors, the Semantic Trail (/trail) and the Reader's "Related Verses".

Method (v2, 2026-06-19): EXACT sparse TF-IDF cosine over the English translations —
no random projection. TF-IDF = sublinear TF (1+log tf) × document-frequency IDF; a
small stop-list (incl. archaic forms). Neighbours are the exact top-K cosine, with:
  • header / label lines EXCLUDED (they are metadata, not Gurbani meaning),
  • verbatim-twin DE-DUPLICATION (a line's identical English copy elsewhere — e.g. a
    recurring invocation or refrain — never crowds the list; the recurrence stays in
    the corpus, it is just not offered back as a "discovery"),
  • a MIN-SCORE floor (weak/noise matches are dropped rather than padded to K),
  • TRUE cosine stored as `score` (a calibrated 0–1 closeness, not a projected proxy).

This replaces the earlier tf-idf→128-d random-projection ("tfidf-randproj-lite"),
which agreed with the exact top-10 only ~57% of the time. Exact sparse cosine is both
more accurate AND cheaper at this corpus size (~6.4k-term vocab, ~7 terms/line).

    python pipeline/build_semantic_vectors_lite.py --db db/sggs.sqlite

Build-time deps: numpy + scipy (sparse). The runtime server (serve.py) stays 100%
stdlib. Idempotent and purely additive — only DROP/CREATEs `line_neighbors`. The
MiniLM builder (build_semantic_vectors.py) may later overwrite the same table with
true contextual embeddings; provenance is recorded in analytics_meta either way.

SCRIPTURE SAFETY: read-only over the verbatim corpus; computes only over the separate
English-translation layer; never edits, reorders, or de-duplicates the scripture text.
"""
import argparse, re, sqlite3, time, math, sys
from build_clock import stamp
import numpy as np
try:
    from scipy import sparse
except ImportError:
    sys.exit("[semantic-lite] this builder needs scipy:  pip install scipy\n"
             "  (build-time only — serve.py remains stdlib-only.)")

TABLE = "line_neighbors"

STOP = set("""a an and are as at be but by for if in into is it no not of on or such that the
their then there these they this to was will with i you he she we us our your his her its from
have has had do does did so than too very can may might shall should would could not o thou thee
thy hath unto shall yourself himself herself itself within without upon out up down over under
all any are been being where when who whom which what while because about above after again""".split())

TOKEN = re.compile(r"[a-z]{2,}")


def log(m): print(f"[semantic-lite] {m}", flush=True)


def norm_en(s: str) -> str:
    """Normalised English key for verbatim-twin de-dup (lowercased content words)."""
    return " ".join(TOKEN.findall((s or "").lower()))


def load_corpus(con):
    """(ids, texts) for every CONTENT line (is_header=0) with a non-empty English
    translation. Headers/labels ("Pauree:", "First Mehl:") are excluded — they are
    metadata, not verses, and only produced boilerplate self-matches."""
    rows = con.execute(
        "SELECT t.line_id, t.text FROM translations t JOIN lines l ON l.id = t.line_id "
        "WHERE t.lang='en' AND t.text IS NOT NULL AND TRIM(t.text) <> '' AND l.is_header = 0 "
        "ORDER BY t.line_id").fetchall()
    return [r[0] for r in rows], [r[1] for r in rows]


def build_tfidf(texts, min_df, max_features):
    """Exact L2-normalised sparse TF-IDF matrix (n × V), scipy CSR."""
    n = len(texts)
    toks = [[t for t in TOKEN.findall(s.lower()) if t not in STOP] for s in texts]
    df = {}
    for ts in toks:
        for w in set(ts):
            df[w] = df.get(w, 0) + 1
    vocab_items = sorted(((w, d) for w, d in df.items() if d >= min_df), key=lambda x: -x[1])[:max_features]
    vocab = {w: i for i, (w, _) in enumerate(vocab_items)}
    V = len(vocab)
    idf = np.zeros(V, dtype=np.float32)
    for w, d in vocab_items:
        idf[vocab[w]] = math.log((1 + n) / (1 + d)) + 1.0
    log(f"vocabulary: {V} terms (min_df={min_df})")

    rows, cols, vals = [], [], []
    for di, ts in enumerate(toks):
        if not ts:
            continue
        counts = {}
        for w in ts:
            j = vocab.get(w)
            if j is not None:
                counts[j] = counts.get(j, 0) + 1
        for j, c in counts.items():
            rows.append(di); cols.append(j)
            vals.append((1.0 + math.log(c)) * idf[j])          # sublinear tf × idf
    X = sparse.csr_matrix((np.asarray(vals, dtype=np.float32),
                           (np.asarray(rows, dtype=np.int64), np.asarray(cols, dtype=np.int64))),
                          shape=(n, V), dtype=np.float32)
    norms = np.sqrt(np.asarray(X.multiply(X).sum(axis=1)).ravel())
    norms[norms == 0] = 1.0
    X = sparse.diags((1.0 / norms).astype(np.float32)) @ X      # L2-normalise rows → cosine via dot
    return X.tocsr()


def topk_exact(X, ids, en, k, min_score, cand, block):
    """Exact cosine top-K with header-excluded corpus, verbatim-twin de-dup and a
    min-score floor. Returns parallel lists (line_id, neighbor_id, score)."""
    n = X.shape[0]
    Xt = X.T.tocsr()
    out_l, out_n, out_s = [], [], []
    for s in range(0, n, block):
        e = min(s + block, n)
        S = (X[s:e] @ Xt).tocsr()                              # (b, n) sparse cosine block
        for bi in range(e - s):
            i = s + bi
            a, b = S.indptr[bi], S.indptr[bi + 1]
            idxs = S.indices[a:b]
            scs = S.data[a:b]
            if idxs.size == 0:
                continue
            # take the strongest `cand` candidates, then refine
            if idxs.size > cand:
                # keep every score tied with the cand-th best, so the candidate set does
                # not depend on how argpartition breaks ties at the boundary
                kth = np.partition(-scs, cand - 1)[cand - 1]
                keep = -scs <= kth
                idxs, scs = idxs[keep], scs[keep]
            order = np.lexsort((idxs, -scs))                   # score desc, ties by column index (stable)
            seen = {en[i]}                                     # skip the seed's own verbatim twins
            cnt = 0
            for o in order:
                j = int(idxs[o]); sc = float(scs[o])
                if j == i:
                    continue
                if sc < min_score:
                    break                                      # sorted desc → nothing better remains
                key = en[j]
                if key in seen:                                # collapse verbatim-identical neighbours
                    continue
                seen.add(key)
                out_l.append(ids[i]); out_n.append(ids[j]); out_s.append(round(sc, 4))
                cnt += 1
                if cnt >= k:
                    break
        log(f"  neighbours {e}/{n}")
    return out_l, out_n, out_s


def write_neighbors(con, lids, nids, scs, provenance):
    con.execute(f"DROP TABLE IF EXISTS {TABLE}")
    con.execute(f"CREATE TABLE {TABLE} ("
                " line_id INTEGER NOT NULL, neighbor_id INTEGER NOT NULL, score REAL NOT NULL,"
                " PRIMARY KEY (line_id, neighbor_id))")
    con.executemany(f"INSERT OR IGNORE INTO {TABLE} VALUES (?,?,?)",
                    ((int(a), int(b), float(c)) for a, b, c in zip(lids, nids, scs)))
    con.execute("CREATE TABLE IF NOT EXISTS analytics_meta (key TEXT PRIMARY KEY, value TEXT)")
    con.execute("INSERT OR REPLACE INTO analytics_meta VALUES ('line_neighbors_source', ?)", (provenance,))
    con.execute("INSERT OR REPLACE INTO analytics_meta VALUES ('line_neighbors_built', ?)",
                (stamp('%Y-%m-%d %H:%M'),))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default="db/sggs.sqlite")
    ap.add_argument("--topk", type=int, default=10)
    ap.add_argument("--min-score", type=float, default=0.30, help="drop neighbours below this cosine")
    ap.add_argument("--min-df", type=int, default=2)
    ap.add_argument("--max-features", type=int, default=20000)
    ap.add_argument("--cand", type=int, default=60, help="candidates examined per line before de-dup/top-K")
    ap.add_argument("--block", type=int, default=1024)
    ap.add_argument("--no-vacuum", action="store_true")
    # accepted for backward-compat with older invocations (random-projection era); ignored now:
    ap.add_argument("--dim", type=int, default=None, help=argparse.SUPPRESS)
    ap.add_argument("--seed", type=int, default=None, help=argparse.SUPPRESS)
    args = ap.parse_args()

    con = sqlite3.connect(args.db)
    ids, texts = load_corpus(con)
    n = len(ids)
    log(f"corpus: {n} content English lines  ·  exact sparse TF-IDF cosine")
    if n == 0:
        sys.exit("No English translations found.")
    en = [norm_en(t) for t in texts]

    t0 = time.time()
    X = build_tfidf(texts, args.min_df, args.max_features)
    log(f"tf-idf built in {time.time()-t0:.1f}s  ·  nnz={X.nnz}")
    t0 = time.time()
    lids, nids, scs = topk_exact(X, ids, en, args.topk, args.min_score, args.cand, args.block)
    log(f"exact top-{args.topk} in {time.time()-t0:.1f}s  ·  {len(lids)} edges")

    write_neighbors(con, lids, nids, scs, provenance="tfidf-exact-cosine-lite")
    con.commit()
    if not args.no_vacuum:
        con.isolation_level = None
        con.execute("VACUUM")
    cnt = con.execute(f"SELECT COUNT(*) FROM {TABLE}").fetchone()[0]
    seeds = con.execute(f"SELECT COUNT(DISTINCT line_id) FROM {TABLE}").fetchone()[0]
    con.close()
    log(f"done. {TABLE} rows = {cnt}  ·  seed lines = {seeds}")


if __name__ == "__main__":
    main()
