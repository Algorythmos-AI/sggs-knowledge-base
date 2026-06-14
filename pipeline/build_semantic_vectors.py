#!/usr/bin/env python3
"""
build_semantic_vectors.py — Phase 2 offline semantic builder (PRODUCTION).

Embeds the English translation of every line with sentence-transformers
`all-MiniLM-L6-v2`, computes cosine top-K nearest neighbours, and stores them in
a NEW, purely-additive SQLite table `line_neighbors(line_id, neighbor_id, score)`.

This is a BUILD-TIME tool. Its heavy deps (torch, sentence-transformers) must live
in a throwaway venv and never touch the 100%-offline stdlib runtime (serve.py).
Run it once; serve.py then reads the precomputed table with a plain SELECT.

    python -m venv .venv-embed && source .venv-embed/bin/activate
    pip install --upgrade pip
    pip install "torch>=2.2" "sentence-transformers>=3.0"
    python pipeline/build_semantic_vectors.py --db db/sggs.sqlite
    deactivate

The table schema is IDENTICAL to the numpy "lite" builder, so this run simply
upgrades the same table in place to true-semantic quality (provenance is recorded
in analytics_meta so the UI/endpoint can tell which builder produced it).

Idempotent: drops and rebuilds line_neighbors. Never modifies any other table.
"""
import argparse, sqlite3, time, sys

TABLE = "line_neighbors"


def log(msg): print(f"[semantic] {msg}", flush=True)


def load_corpus(con):
    """(ids, texts) for every line that has a non-empty English translation."""
    rows = con.execute(
        "SELECT line_id, text FROM translations "
        "WHERE lang='en' AND text IS NOT NULL AND TRIM(text) <> '' ORDER BY line_id"
    ).fetchall()
    ids = [r[0] for r in rows]
    texts = [r[1] for r in rows]
    return ids, texts


def write_neighbors(con, ids, idx_pairs, scores, provenance):
    """idx_pairs: (n, k) int array of neighbour POSITIONS; scores: (n, k) float.
    Positions are mapped back to line_ids via `ids`. Purely additive."""
    con.execute(f"DROP TABLE IF EXISTS {TABLE}")
    con.execute(
        f"CREATE TABLE {TABLE} ("
        " line_id INTEGER NOT NULL, neighbor_id INTEGER NOT NULL, score REAL NOT NULL,"
        " PRIMARY KEY (line_id, neighbor_id))"
    )
    # No separate index on line_id: the PK's leftmost column already covers WHERE line_id=?
    # (a standalone idx_line_neighbors_line is pure redundant bloat, ~6.7 MB — verified).
    batch, BATCH = [], 50_000
    for i, lid in enumerate(ids):
        for j, pos in enumerate(idx_pairs[i]):
            nid = ids[int(pos)]
            if nid == lid:
                continue
            batch.append((lid, nid, float(scores[i][j])))
            if len(batch) >= BATCH:
                con.executemany(f"INSERT OR IGNORE INTO {TABLE} VALUES (?,?,?)", batch)
                batch.clear()
    if batch:
        con.executemany(f"INSERT OR IGNORE INTO {TABLE} VALUES (?,?,?)", batch)
    # provenance (additive meta row; ignored by older code paths)
    con.execute("CREATE TABLE IF NOT EXISTS analytics_meta (key TEXT PRIMARY KEY, value TEXT)")
    con.execute("INSERT OR REPLACE INTO analytics_meta VALUES ('line_neighbors_source', ?)", (provenance,))
    con.execute("INSERT OR REPLACE INTO analytics_meta VALUES ('line_neighbors_built', ?)",
                (time.strftime('%Y-%m-%d %H:%M'),))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default="db/sggs.sqlite")
    ap.add_argument("--model", default="sentence-transformers/all-MiniLM-L6-v2")
    ap.add_argument("--topk", type=int, default=10)
    ap.add_argument("--batch", type=int, default=256, help="embedding batch size")
    ap.add_argument("--query-chunk", type=int, default=2048, help="rows per similarity block")
    args = ap.parse_args()

    try:
        import numpy as np
        from sentence_transformers import SentenceTransformer
        import torch
    except ImportError as e:
        sys.exit(f"Missing build dep: {e}. Activate the venv and pip install "
                 f"torch sentence-transformers first (see this file's header).")

    con = sqlite3.connect(args.db)
    ids, texts = load_corpus(con)
    n = len(ids)
    log(f"corpus: {n} English lines")
    if n == 0:
        sys.exit("No English translations found — nothing to embed.")

    log(f"loading model {args.model} (first run downloads ~90 MB to ~/.cache; offline after) …")
    model = SentenceTransformer(args.model)
    t0 = time.time()
    emb = model.encode(texts, batch_size=args.batch, convert_to_numpy=True,
                       normalize_embeddings=True, show_progress_bar=True)
    log(f"embedded {n} lines in {time.time()-t0:.1f}s -> {emb.shape}")

    emb = np.asarray(emb, dtype=np.float32)
    et = torch.from_numpy(emb)
    K = args.topk + 1                                   # +1: the self-match is dropped later
    top_idx = np.empty((n, K), dtype=np.int64)
    top_sc = np.empty((n, K), dtype=np.float32)
    t0 = time.time()
    for s in range(0, n, args.query_chunk):
        e = min(s + args.query_chunk, n)
        sims = et[s:e] @ et.T                            # (block, n) cosine (rows are L2-normed)
        sc, ix = torch.topk(sims, K, dim=1)
        top_idx[s:e] = ix.numpy()
        top_sc[s:e] = sc.numpy()
        log(f"  neighbours {e}/{n}")
    log(f"top-{args.topk} search in {time.time()-t0:.1f}s")

    write_neighbors(con, ids, top_idx, top_sc, provenance="minilm-l6-v2")
    con.commit()
    log(f"inserted neighbours into {TABLE}; compacting …")
    con.isolation_level = None
    con.execute("VACUUM")
    cnt = con.execute(f"SELECT COUNT(*) FROM {TABLE}").fetchone()[0]
    con.close()
    log(f"done. {TABLE} rows = {cnt}. serve.py /api/neighbors is now true-semantic.")


if __name__ == "__main__":
    main()
