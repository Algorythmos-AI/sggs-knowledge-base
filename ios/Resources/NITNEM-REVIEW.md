# Nitnem non-SGGS text — scholar review attestation

The Nitnem registry bundled in the iOS database contains, besides pointers into the
verified Sri Guru Granth Sahib Ji corpus, a **separate, labelled layer** of text that
is *not* from Sri Guru Granth Sahib Ji: Jaap Sahib, Tav-Prasad Savaiye, Benti Chaupai,
Shabad Hazare Patshahi 10 and the Dasam portions of Rehras Sahib (Sri Dasam Granth),
and Ardaas. That text (`extra_lines`) is taken from the ShabadOS open database and
converted; it is **not** covered by the character-for-character reconcile proof that
protects the SGGS corpus.

`pipeline/check_release_license.sh` reads this file. A build whose manifest says
`banis_bundled: true` and whose database has non-SGGS lines passes the release gate
**only** when the line below reads exactly `REVIEWED: true`.

Review procedure: `docs/nitnem/review-pack/` — every extra line printed beside the
SGPC Nitnem Gutka reading, checked by a Granthi or Gurbani scholar. Record the
reviewer, date and gutka edition here and flip the flag in the same commit.

| Field | Value |
|---|---|
| Reviewer (name / role) | _unfilled_ |
| Date reviewed | _unfilled_ |
| Reference edition compared | _unfilled — e.g. SGPC Nitnem Gutka, Amritsar, edition/year_ |
| Corrections applied (commit ids) | _unfilled_ |
| Lines reviewed | _unfilled_ |

REVIEWED: false
