# CSQLite — vendored SQLite (pinned)

Vendored to make FTS5 `unicode61` tokenization and `bm25` ranking **byte-identical on every device /
iOS version**, instead of relying on the host's system SQLite (whose version — and thus Unicode tables
and ranking math — varies). This is the exact engine that built the corpus FTS index and the golden
vectors, so the parity suite passing on it is a complete proof of fidelity.

- **Version:** SQLite **3.51.0** (`SQLITE_VERSION "3.51.0"`)
- **Source:** https://www.sqlite.org/2025/sqlite-amalgamation-3510000.zip (official amalgamation)
- **Archive SHA-256:** `1caf7116f2910600d04473ad69d37ec538fa62fa36adccd37b5e0e43647c98be`
- **Files:** `sqlite3.c`, `include/sqlite3.h`, `include/sqlite3ext.h` (verbatim from the amalgamation)
- **Compile flags** (`Package.swift` → `CSQLite` target): `SQLITE_ENABLE_FTS5`, `SQLITE_ENABLE_FTS4`,
  `SQLITE_ENABLE_FTS3_TOKENIZER`, `SQLITE_THREADSAFE=2`, `SQLITE_DQS=3`.
- **License:** SQLite is in the **public domain** (no attribution required; recorded here for provenance).

To upgrade: the pinned version MUST match the SQLite that builds the corpus index + goldens (currently
3.51.0). Bump both together and re-run `swift test` — the parity suite is the gate.
