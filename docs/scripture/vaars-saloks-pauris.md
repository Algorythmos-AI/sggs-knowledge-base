---
title: "Vaars, saloks and pauris"
description: "The twenty-two ballads inside the raags: pauris by one author with saloks interleaved from several, why attribution needs a rule, and how the pipeline detects a Vaar by its title, not its shape."
sidebar:
  order: 3
verified:
  commit: 6332e947
  date: "2026-09-25"
---
# Vaars, saloks and pauris

> **Explanation, not scripture — scholar review pending (gate G3).** These pages explain the
> scripture to engineers and students. Every quoted line is verbatim from the pinned database and
> cited by Ang; everything else is explanation, written by engineers and awaiting a Granthi's
> review. Where this page and the scripture differ, the scripture is right.

A **[[Vaar]]** is a ballad: a sequence of [[Pauri|pauris]] — stanzas — each preceded, in
the Granth's arrangement, by one or more [[Salok|saloks]], couplet-style verses. The
pauris are by one author; the saloks that go with them are drawn from several Gurus and carry
their own [[Mahalla]] headers. Twenty-two Vaars sit inside the raags; the pinned database lists
them like this:

| # | Raag | Angs | Pauris | Saloks | Pauris by | Salok authors |
|---|---|---|---|---|---|---|
| 1 | `ਸਿਰੀਰਾਗੁ` (*sireeraag*) | 83–91 | 21 | 43 | Guru Ram Das Ji (M4) | 4 |
| 2 | `ਮਾਝ` (*maajh*) | 137–150 | 27 | 63 | Guru Nanak Dev Ji (M1) | 4 |
| 3 | `ਗਉੜੀ` (*gaurhee*) | 300–317 | 33 | 68 | Guru Ram Das Ji (M4) | 3 |
| 4 | `ਗਉੜੀ` (*gaurhee*) | 318–323 | 21 | 42 | Guru Arjan Dev Ji (M5) | 1 |
| 5 | `ਆਸਾ` (*aasaa*) | 462–475 | 24 | 59 | Guru Nanak Dev Ji (M1) | 2 |
| 6 | `ਗੂਜਰੀ` (*goojaree*) | 508–517 | 22 | 44 | Guru Amar Das Ji (M3) | 1 |
| 7 | `ਗੂਜਰੀ` (*goojaree*) | 517–524 | 21 | 42 | Guru Arjan Dev Ji (M5) | 1 |
| 8 | `ਬਿਹਾਗੜਾ` (*bihaagarhaa*) | 548–556 | 21 | 41 | Guru Ram Das Ji (M4) | 5 |
| 9 | `ਵਡਹੰਸੁ` (*vadahans*) | 585–594 | 21 | 43 | Guru Ram Das Ji (M4) | 2 |
| 10 | `ਸੋਰਠਿ` (*sorath*) | 642–653 | 29 | 58 | Guru Ram Das Ji (M4) | 4 |
| 11 | `ਜੈਤਸਰੀ` (*jaitasaree*) | 705–710 | 20 | 20 | Guru Arjan Dev Ji (M5) | 1 |
| 12 | `ਸੂਹੀ` (*soohee*) | 785–792 | 20 | 47 | Guru Amar Das Ji (M3) | 3 |
| 13 | `ਬਿਲਾਵਲੁ` (*bilaaval*) | 849–855 | 13 | 27 | Guru Ram Das Ji (M4) | 3 |
| 14 | `ਰਾਮਕਲੀ` (*raamakalee*) | 947–956 | 21 | 53 | Guru Amar Das Ji (M3) | 3 |
| 15 | `ਰਾਮਕਲੀ` (*raamakalee*) | 957–966 | 22 | 44 | Guru Arjan Dev Ji (M5) | 1 |
| 16 | `ਰਾਮਕਲੀ` (*raamakalee*) | 966–968 | 8 | 0 | Satta & Balwand | 0 |
| 17 | `ਮਾਰੂ` (*maaroo*) | 1086–1094 | 22 | 47 | Guru Amar Das Ji (M3) | 5 |
| 18 | `ਮਾਰੂ` (*maaroo*) | 1094–1102 | 23 | 52 | Guru Arjan Dev Ji (M5) | 1 |
| 19 | `ਬਸੰਤੁ` (*basant*) | 1193–1193 | 3 | 0 | Guru Arjan Dev Ji (M5) | 0 |
| 20 | `ਸਾਰੰਗ` (*saarang*) | 1237–1251 | 36 | 74 | Guru Ram Das Ji (M4) | 5 |
| 21 | `ਮਲਾਰ` (*malaar*) | 1278–1291 | 28 | 58 | Guru Nanak Dev Ji (M1) | 4 |
| 22 | `ਕਾਨੜਾ` (*kaanarhaa*) | 1312–1318 | 15 | 30 | Guru Ram Das Ji (M4) | 1 |

## Why attribution needs a rule

Read line by line, a Vaar looks like a stream of alternating authors: a salok of Guru Nanak Dev Ji,
a salok of Guru Angad Dev Ji, then a pauri. The pauri belongs to the Vaar's author even though the
line just before it carried another Guru's `ਮਃ` header. So the pipeline gives a Vaar's pauris the
Vaar's author (`vaar_author`), never the author of the preceding salok — one of the engineering
[invariants](../engineering/invariants.md). The Vaar with no saloks is Satta and Balwand's
(Angs 966–968), the one composition in the Granth by those two authors; the short Vaar on Ang 1193
is Guru Arjan Dev Ji's in Basant.

## Detected by title, not by shape

Twenty-two is the count of Vaars **by title header** — a heading carrying `ਵਾਰ` with `ਕੀ` or
`ਧੁਨੀ`. Detecting Vaars structurally, by runs of pauris, over- and under-counts, so the pipeline
never does it. The `vaars` and `vaar_units` tables in the database hold every Vaar's anatomy —
`/api/analytics/vaars` and `/api/analytics/vaar?id=N` serve them — and `golden_analytics.ndjson`
pins the count.

## In the app

The daily banis include Asa Ki Vaar (Vaar 5 above, Angs 462–475), read both as printed and in its
kirtan interleave with the chhants of Angs 448–451 — two [[Nitnem]] variants of one registry key —
and a Vaar's pauri numbers come only from the markers the scripture prints
([Nitnem for engineers](../ios/nitnem-for-engineers.md)).

Read next: [The Bhatts and the Swaiyye](bhatts-and-swaiyye.md).
