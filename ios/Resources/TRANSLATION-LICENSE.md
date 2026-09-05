# English translation — distribution licence attestation

The bundled iOS database (`personal` profile) embeds the English translation of
Sri Guru Granth Sahib by **Dr. Sant Singh Khalsa**, obtained via the ShabadOS open
database (see `NOTICE.md`). That layer is licensed to this project for personal,
local, non-commercial study **unless** a written distribution licence has been
obtained. TestFlight and App Store distribution count as distribution.

`pipeline/check_release_license.sh` reads this file. A build that bundles the
translation (`en_bundled: true` in its manifest) passes the release gate **only**
when the line below reads exactly `LICENSED: true`.

Fill in the fields when the licence is in hand and flip the flag in the same commit.

| Field | Value |
|---|---|
| Grantor (rights holder / contact) | _unfilled_ |
| Date granted | _unfilled_ |
| Scope | _unfilled — must name TestFlight and App Store distribution_ |
| Reference (letter / email / agreement id) | _unfilled_ |
| Attribution line required in-app | "English translation by Dr. Sant Singh Khalsa (sourced via BaniDB)." |

LICENSED: false
