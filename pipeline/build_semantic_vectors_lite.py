#!/usr/bin/env python3
"""
build_semantic_vectors_lite.py — Phase 2 semantic builder (LITE, zero-heavy-deps).

A numpy-only stand-in for build_semantic_vectors.py: it produces the SAME additive
`line_neighbors(line_id, neighbor_id, score)` table so the /api/neighbors endpoint
and the Reader's "Related Verses" UI work immediately — no torch, no model download.

Method: TF-IDF over the English translations (sublinear TF, document-frequency IDF)
projected to a dense space by a seeded Gaussian random projection (Johnson–
Lindenstrauss: cosine distances are preserved in expectation), then exact blocked
cosine top-K. It is a faithful *lexical-semantic* approximation; the MiniLM builder
later overwrites the same table with true contextual embeddings.

    python pipeline/build_semantic_vectors_lite.py --db db/sggs.sqlite

Idempotent and purely additive — only creates/replaces line_neighbors.
"""
import argparse, re, sqlite3, time, math, sys, os
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_semantic_vectors import load_corpus, write_neighbors, TABLE  # identical schema/writer

STOP = set("""a an and are as at be but by for if in into is it no not of on or such that the
their then there these they this to was will with i you he she we us our your his her its from
have has had do does did so than too very can may might shall should would could not o thou thee
thy hath unto shall yourself himself herself itself within without upon out up down over under
all any are been being where when who whom which what while because about above after again""".split())

TOKEN = re.compile(r"[a-z]{2,}")


def log(m): print(f"[semantic-lite] {m}", flush=True)


def build_vectors(texts, dim, min_df, max_features, seed):
    n = len(texts)
    toks = [[t for t in TOKEN.findall(s.lower()) if t not in STOP] for s in texts]
    # document frequency → vocabulary
    df = {}
    for ts in toks:
        for w in set(ts):
            df[w] = df.get(w, 0) + 1
    vocab_items = [(w, d) for w, d in df.items() if d >= min_df]
    vocab_items.sort(key=lambda x: -x[1])
    vocab_items = vocab_items[:max_features]
    vocab = {w: i for i, (w, _) in enumerate(vocab_items)}
    V = len(vocab)
    idf = np.zeros(V, dtype=np.float32)
    for w, d in vocab_items:
        idf[vocab[w]] = math.log((1 + n) / (1 + d)) + 1.0
    log(f"vocabulary: {V} terms (min_df={min_df})")

    # seeded Gaussian random projection  R: (V, dim)
    rng = np.random.default_rng(seed)
    R = rng.standard_normal((V, dim), dtype=np.float32) / math.sqrt(dim)

    # accumulate per-doc projected tf-idf via a single scatter-add
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
            vals.append((1.0 + math.log(c)) * idf[j])           # sublinear tf × idf
    rows = np.asarray(rows, dtype=np.int64)
    cols = np.asarray(cols, dtype=np.int64)
    vals = np.asarray(vals, dtype=np.float32)
    X = np.zeros((n, dim), dtype=np.float32)
    np.add.at(X, rows, R[cols] * vals[:, None])
    # L2-normalise (zero rows stay zero → they simply get no neighbours)
    norms = np.linalg.norm(X, axis=1, keepdims=True)
    np.divide(X, norms, out=X, where=norms > 0)
    return X


def topk_neighbors(X, k, block):
    n = X.shape[0]
    K = k + 1
    top_idx = np.empty((n, K), dtype=np.int64)
    top_sc = np.empty((n, K), dtype=np.float32)
    for s in range(0, n, block):
        e = min(s + block, n)
        sims = X[s:e] @ X.T                                       # (b, n) cosine
        part = np.argpartition(-sims, K - 1, axis=1)[:, :K]       # unordered top-K
        rowscores = np.take_along_axis(sims, part, axis=1)
        order = np.argsort(-rowscores, axis=1)                    # sort those K
        top_idx[s:e] = np.take_along_axis(part, order, axis=1)
        top_sc[s:e] = np.take_along_axis(rowscores, order, axis=1)
        log(f"  neighbours {e}/{n}")
    return top_idx, top_sc


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default="db/sggs.sqlite")
    ap.add_argument("--dim", type=int, default=128)
    ap.add_argument("--topk", type=int, default=10)
    ap.add_argument("--min-df", type=int, default=2)
    ap.add_argument("--max-features", type=int, default=20000)
    ap.add_argument("--block", type=int, default=2048)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--no-vacuum", action="store_true")
    args = ap.parse_args()

    con = sqlite3.connect(args.db)
    ids, texts = load_corpus(con)
    n = len(ids)
    log(f"corpus: {n} English lines  ·  projecting to {args.dim}d")
    if n == 0:
        sys.exit("No English translations found.")
    t0 = time.time()
    X = build_vectors(texts, args.dim, args.min_df, args.max_features, args.seed)
    log(f"vectors built in {time.time()-t0:.1f}s")
    t0 = time.time()
    idx, sc = topk_neighbors(X, args.topk, args.block)
    log(f"top-{args.topk} cosine in {time.time()-t0:.1f}s")
    write_neighbors(con, ids, idx, sc, provenance="tfidf-randproj-lite")
    con.commit()
    if not args.no_vacuum:
        con.isolation_level = None
        con.execute("VACUUM")
    cnt = con.execute(f"SELECT COUNT(*) FROM {TABLE}").fetchone()[0]
    con.close()
    log(f"done. {TABLE} rows = {cnt}")


if __name__ == "__main__":
    main()
