# ADR-0007: Three repositories — data, platform, app — joined by pinned artifacts

**Status:** accepted (2026-09-24, release 1.3.8)

**Context.** One repository carried the corpus and database pipeline, the API and web, and the iOS
app. They release on different cadences, need different reviewers and toolchains, and a change to
one could silently move another (a rebuilt database committed with a web fix; an iOS build reading
the web's files by relative path). The monolith was first split into bounded contexts in code
(`webapp/sggs/`: reader, search, verification, insights, knowledge, each declaring the tables it
reads), which made the boundaries explicit before the repositories moved.

**Decision.** Three repositories, each owning one thing, history carried over with `git filter-repo`
(every carried file byte-identical to its source):

- `Algorythmos-AI/sggs-data` — the corpus, the database, the rebuild pipeline, the scripture gates,
  the editorial ledger and the evidence. It publishes each database by commit and sha256.
- `Algorythmos-AI/sggs-platform` (this repository, renamed from `sggs-knowledge-base`) — the API and
  the web. It serves exactly the database `dataset.lock.json` pins (ADR-0008).
- `Algorythmos-AI/gurbani-soul-ios` — the app. It vendors this repository's golden contract at a
  pinned platform release and the iOS database builder from sggs-data, and keeps the one-number
  policy (ADR-0004) itself: `MARKETING_VERSION` equals the platform release it vendors.

Nothing crosses a repository boundary except pinned, hash-verified artifacts; no build reads
another repository's working tree.

**Consequences.** A data change lands in sggs-data first and reaches this repository as a reviewed
lock bump; a platform release reaches the app as a reviewed vendor sync. Each repository has its own
CI, rulesets (as code) and release tags. `check_release_complete.py` proves a release across them by
matching the platform commit recorded in the app's ledger. The old repository name redirects; the
Render service and every public hostname are unchanged.
