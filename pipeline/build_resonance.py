#!/usr/bin/env python3
"""
build_resonance.py — Phase 3 offline builder: Cross-Contributor Resonance.

Aggregates the line-level semantic graph (`line_neighbors`) up to the author level:
for every line by author A, how often do its nearest-meaning neighbours belong to
author B? Normalised to **lift** against B's share of the corpus, this measures
theological/expressive resonance *controlling for how much Bani each voice left* —
surfacing, e.g., the tight echo among the Bhagats (Kabir / Namdev / Ravidas) and
across traditions (Sufi Farid, the Bhatts).

Writes a NEW, purely-additive table `author_resonance(src_author, dst_author,
edges, mean_score, lift)`. Build-time only (numpy not even needed); the runtime
reads it with a plain SELECT.

    python pipeline/build_resonance.py --db db/sggs.sqlite

Idempotent and additive — only creates/replaces author_resonance.
"""
import argparse, sqlite3, time, collections

TABLE = "author_resonance"


def log(m): print(f"[resonance] {m}", flush=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default="db/sggs.sqlite")
    ap.add_argument("--no-vacuum", action="store_true")
    args = ap.parse_args()
    con = sqlite3.connect(args.db)

    # author of every authored line; corpus-share denominator = English-eligible lines
    auth = dict(con.execute("SELECT id, author FROM lines WHERE author IS NOT NULL"))
    en_ids = [r[0] for r in con.execute("SELECT line_id FROM translations WHERE lang='en'")]
    share_n = collections.Counter(auth[i] for i in en_ids if i in auth)
    total = sum(share_n.values())
    log(f"{len(auth)} authored lines · {total} English-authored lines across {len(share_n)} voices")

    obs = collections.Counter()           # (A,B) -> directed neighbour count
    ssum = collections.Counter()          # (A,B) -> sum of cosine score
    from_tot = collections.Counter()      # A -> total neighbour edges originating from A's lines
    t0 = time.time()
    for lid, nid, sc in con.execute("SELECT line_id, neighbor_id, score FROM line_neighbors"):
        a = auth.get(lid); b = auth.get(nid)
        if not a or not b:
            continue
        obs[(a, b)] += 1; ssum[(a, b)] += sc; from_tot[a] += 1
    log(f"aggregated {sum(obs.values())} authored edges in {time.time()-t0:.1f}s")

    rows = []
    for (a, b), o in obs.items():
        exp = from_tot[a] * (share_n[b] / total) if from_tot[a] and total else 0
        lift = (o / exp) if exp > 0 else 0.0
        rows.append((a, b, o, ssum[(a, b)] / o, round(lift, 4)))

    con.execute(f"DROP TABLE IF EXISTS {TABLE}")
    con.execute(
        f"CREATE TABLE {TABLE} ("
        " src_author TEXT NOT NULL, dst_author TEXT NOT NULL,"
        " edges INTEGER NOT NULL, mean_score REAL, lift REAL,"
        " PRIMARY KEY (src_author, dst_author))")
    con.executemany(f"INSERT INTO {TABLE} VALUES (?,?,?,?,?)", rows)
    con.execute("CREATE TABLE IF NOT EXISTS analytics_meta (key TEXT PRIMARY KEY, value TEXT)")
    con.execute("INSERT OR REPLACE INTO analytics_meta VALUES ('author_resonance_built', ?)",
                (time.strftime('%Y-%m-%d %H:%M'),))
    con.commit()
    if not args.no_vacuum:
        con.isolation_level = None
        con.execute("VACUUM")
    n = con.execute(f"SELECT COUNT(*) FROM {TABLE}").fetchone()[0]
    con.close()
    log(f"done. {TABLE} rows = {n}")


if __name__ == "__main__":
    main()
