# SGGS Study App — Seeker Battery Test Report
**Date:** 2026-06-11  
**Tester role:** Gurbani-literate Search-Quality SME  
**App:** http://127.0.0.1:7777 · API: /api/search?q=…&limit=4  
**Engine tiers tested:** roman-exact → roman-spelling-tolerant → english-translation → theme  

---

## Legend
| Rating | Meaning |
|--------|---------|
| GOOD | Relevant Gurbani lines returned; Gurmukhi text matches the query intent |
| WEAK | Results returned but off-target or only partially relevant |
| BAD | 0 results, or all returned results are unrelated to the query |

---

## Section 1 — Divine Names

| # | Query | Count | Mode | Rating | Notes |
|---|-------|-------|------|--------|-------|
| 1 | waheguru | 4 | roman-spelling-tolerant | **GOOD** | ਵਾਹਿਗੁਰੂ ਵਾਹਿਗੁਰੂ from Bhatt Gayand swaiyas — exact match |
| 2 | hari | 4 | roman-spelling-tolerant | **GOOD** | ਹਰਿ ਹਰਿ ਹਰਿ — direct divine-name repetition lines |
| 3 | ram | 4 | roman | **GOOD** | ਰਾਮ ਨਾਮੁ ਰਮੁ — Ram as divine name, correct |
| 4 | gobind | 4 | roman | **GOOD** | ਗੋਬਿੰਦ ਗੋਬਿੰਦ ਗੋਬਿੰਦ — exact Gobind repetition |
| 5 | govind | 4 | roman | **GOOD** | ਗੋਵਿੰਦੁ ਗੋਵਿੰਦੁ — correct Govind lines |
| 6 | allah | 4 | roman-spelling-tolerant | **GOOD** | ਅਲਹ ਅਲਖ ਅਪਾਰ + ਏਕੋ ਅਲਹੁ ਪਾਰਬ੍ਰਹਮ — correct Semitic-name usage in SGGS |
| 7 | khuda | 4 | roman-spelling-tolerant | **WEAK** | Top 2 results: ਖੁਦਿ ਖੁਦਾਇ (correct) but also ਕੁਦਿ ਕੁਦਿ ਚਰੈ (irrelevant — "jumping into the abyss") — phonetic over-reach |
| 8 | prabhu | 4 | roman-spelling-tolerant | **GOOD** | ਪ੍ਰਭ ਤੇ ਹੋਏ ਪ੍ਰਭ ਮਾਹਿ ਸਮਾਤਿ — correct Prabhu/Lord lines |
| 9 | thakur | 4 | roman | **WEAK** | All 4 results: "Kavi Kaly Thakur Hardas tane…" — a proper name (poet's father) not Thakur=Lord. Seeker wants Lord/Master; should surface ਠਾਕੁਰ ਕਾ ਸੇਵਕੁ etc. |
| 10 | parmatma | 1 | roman-spelling-tolerant | **WEAK** | Only 1 result (ਪਰਮਾਤਮੁ ਸੋਈ) — low recall for a major divine epithet; theme tier should retrieve more |

---

## Section 2 — Figures

| # | Query | Count | Mode | Rating | Notes |
|---|-------|-------|------|--------|-------|
| 11 | nanak | 4 | roman-spelling-tolerant | **GOOD** | ਪ੍ਰਭ ਨਾਨਕ ਨਾਨਕ ਨਾਨਕ + ਗੁਰੁ ਨਾਨਕੁ ਹਰਿ ਸੋਇ — on-target |
| 12 | kabir | 4 | roman-spelling-tolerant | **GOOD** | ਕਬੀਰਾ ਤੁਹੀ ਕਬੀਰੁ — correct Kabir attribution |
| 13 | farid | 4 | roman-spelling-tolerant | **BAD** | All results: ਫਿਰਦੀ ਫਿਰਦੀ (phiradee=wandering) + ਸੰਤ ਹਮਾਰਾ ਰਾਖਿਆ ਪੜਦਾ (unrelated). None are by or about Sheikh Farid (ਫਰੀਦ). Engine folds "farid" → "phirad" (wandering), misses the bhagat entirely |
| 14 | krishna | 4 | roman-spelling-tolerant | **BAD** | Top 3 results are ਕਿਰਸਾਣੁ (kirsan=farmer), not ਕ੍ਰਿਸਨ (Krishan/Krishna). 4th result ਗੁਰਮੁਖਿ ਸੰਗੀ ਕ੍ਰਿਸਨ ਮੁਰਾਰੇ is relevant but ranked last after farmers |
| 15 | yashoda | 2 | roman-spelling-tolerant | **GOOD** | ਜਿਉ ਜਸੁਦਾ ਘਰਿ ਕਾਨੁ + ਕਹਤ ਮਾ ਜਸੋਦ — Yashoda named, count=2 is complete (sparse in SGGS) |
| 16 | yamuna | 4 | roman-spelling-tolerant | **WEAK** | Result 2 (ਜਮੁਨ ਮਿਲਾਵਉ) is correct, but results 1/3/4 are ਜੰਮਣੁ ਮਰਣਾ (jamman=birth/death) — phonetic collision. Should rank Yamuna/Jamun higher |
| 17 | ravan | 4 | roman | **WEAK** | "ravan" in Punjabi SGGS means "to pervade/utter" (ਰਵਣ ਗੁਣਾ = "singing praises"). Engine finds ਰਵਣ lines correctly for that meaning, and line 4 (ਦਸ ਬਾਲਤਣਿ ਬੀਸ ਰਵਣਿ) refers to Ravana's ten heads at age 10 etc. — partial. A seeker typing "ravan" wants the demon king story; only 1 of 4 results is relevant |
| 18 | sita | 4 | roman-spelling-tolerant | **BAD** | All 4 results: ਸਤਿ ਸਤਿ ਸਤਿ (sat=true). Engine folds "sita" → "sat". SGGS does mention Sita (ਸੀਤਾ) in Ram/Sita narratives; zero relevant results |
| 19 | brahma | 4 | roman-spelling-tolerant | **GOOD** | ਬ੍ਰਹਮੁ ਪਸਰਿਆ + ਬਬਾ ਬ੍ਰਹਮੁ ਜਾਨਤ ਤੇ ਬ੍ਰਹਮਾ — correct Brahma lines |
| 20 | shiva | 4 | roman-spelling-tolerant | **WEAK** | Top 3: ਸੇਵਤ/ਸੇਵਾ (seva=service). 4th: ਸਿਵ ਸਿਵ ਕਰਤੇ ਜੋ ਨਰੁ ਧਿਆਵੈ (Shiv correct). Engine folds shiva→seva. Ranking buries the relevant result |
| 21 | shiv | 4 | roman-spelling-tolerant | **WEAK** | Same as shiva — top 3 seva lines, Shiv only at position 4. Shiv is very frequent in SGGS; engine should resolve this before seva |
| 22 | indra | 4 | roman-spelling-tolerant | **GOOD** | ਇੰਦ੍ਰੀ ਧਾਤੁ + ਬ੍ਰਹਮੇ ਇੰਦ੍ਰ ਧਿਆਇਨਿ — correct Indra/sense-organ lines |
| 23 | dhru | 4 | roman-spelling-tolerant | **BAD** | All results: ਡਰਿ ਘਰੁ (dar=fear). Engine maps dhru→dar (D/Dh fold). Should find ਧ੍ਰੂ (Dhruv the devotee), e.g. ਧ੍ਰੂ ਕਉ ਮਿਲਿਆ ਹਰਿ ਨਿਸੰਗ |
| 24 | dhroo | 4 | roman | **GOOD** | ਧ੍ਰੂ ਪ੍ਰਹਿਲਾਦ ਜਪਿਓ ਹਰਿ + ਧ੍ਰੂ ਕਉ ਮਿਲਿਆ ਹਰਿ — correct Dhruv devotee lines |
| 25 | prahlad | 4 | roman-spelling-tolerant | **GOOD** | ਪ੍ਰਹਲਾਦ ਉਧਾਰੇ ਕਿਰਪਾ ਧਾਰੀ — correct Prahlad story reference |

---

## Section 3 — Concepts (English + Romanized)

| # | Query | Count | Mode | Rating | Notes |
|---|-------|-------|------|--------|-------|
| 26 | naam | 4 | theme | **GOOD** | ਸਾਚਾ ਸਾਹਿਬੁ ਸਾਚੁ ਨਾਇ + ਅੰਮ੍ਰਿਤ ਵੇਲਾ ਸਚੁ ਨਾਉ — Naam theme perfectly served |
| 27 | hukam | 4 | theme | **GOOD** | ਹੁਕਮਿ ਰਜਾਈ ਚਲਣਾ + ਹੁਕਮੀ ਹੋਵਨਿ ਆਕਾਰ — classic Hukam lines from Japji |
| 28 | haumai | 4 | theme | **GOOD** | ਨਾਨਕ ਹੁਕਮੈ ਜੇ ਬੁਝੈ ਤ ਹਉਮੈ ਕਹੈ ਨ ਕੋਇ — directly on Haumai |
| 29 | ego | 1 | roman-spelling-tolerant | **BAD** | Only 1 result: ਈਘੈ ਨਿਰਗੁਨ ਊਘੈ ਸਰਗੁਨ — irrelevant (eegh/oogh = below/above spatial metaphor). Engine matched "ego" phonetically to ਈਘੈ. Theme tier for haumai never triggered |
| 30 | grace | 4 | english-translation | **GOOD** | ਹਰਿ ਧਾਰਹੁ ਕਿਰਪਾ + ਗੁਰ ਪਰਸਾਦੀ ਨਦਰਿ — correct kirpa/nadar (grace) lines |
| 31 | mercy | 4 | roman-spelling-tolerant | **BAD** | All 4 results: ਮੋਰਚਾ (morcha=rust/tarnish). Engine matched "mercy"→"morcha" phonetically. No daya/kirpa (mercy) lines returned |
| 32 | compassion | 4 | english-translation | **GOOD** | ਤੀਰਥੁ ਤਪੁ ਦਇਆ ਦਤੁ ਦਾਨੁ + ਕ੍ਰਿਪਾ ਨਿਧਾਨ ਦਇਆਲ — correct daya/kirpa lines |
| 33 | peace | 4 | roman-spelling-tolerant | **BAD** | All results: ਮੋਹਿ ਪਚੇ/ਪੁਛਿ ਨ (moh-pache=burned in attachment; puchh=ask). Engine matched "peace"→"pach/puchh". Should return ਸੁਖ/ਸ਼ਾਂਤਿ/ਸਹਜ lines |
| 34 | death | 4 | roman-spelling-tolerant | **BAD** | All results: ਦਾਤਾ ਦਾਤਾਰੁ (daataar=giver). Engine mapped "death"→"dat/daat". Should return ਮਾਤ/ਕਾਲ/ਮੌਤ/ਮਰਨ lines |
| 35 | liberation | 4 | english-translation | **GOOD** | ਮੁਕਤੇ ਸੇਵੇ ਮੁਕਤਾ ਹੋਵੈ + ਅੰਦਰਹੁ ਮੁਕਤੁ — correct mukti (liberation) lines |
| 36 | mukti | 4 | theme | **GOOD** | ਕਰਮੀ ਆਵੈ ਕਪੜਾ ਨਦਰੀ ਮੋਖੁ ਦੁਆਰੁ — correct mokh/mukti |
| 37 | moksha | 4 | theme | **GOOD** | Same as mukti — ਮੋਖੁ ਦੁਆਰੁ — correct |
| 38 | karma | 4 | roman-spelling-tolerant | **GOOD** | ਕਰਮੀ ਕਰਮੀ ਹੋਇ ਵੀਚਾਰੁ — correct karma/karams lines |
| 39 | karam | 4 | roman | **GOOD** | ਨਿਉਲੀ ਕਰਮ + ਕਰਮ ਕਰਤੂਤਿ — correct |
| 40 | seva | 4 | theme | **GOOD** | ਆਖਹਿ ਸੁਰਿ ਨਰ ਮੁਨਿ ਜਨ ਸੇਵ + ਕੇਤੀਆ ਸੁਰਤੀ ਸੇਵਕ — correct |
| 41 | sangat | 4 | theme | **GOOD** | ਮਿਲਿ ਸੰਗਤਿ ਗੁਣ ਪਰਗਾਸਿ + ਜੋ ਸਤਿਗੁਰ ਸਰਣਿ ਸੰਗਤਿ — correct |
| 42 | simran | 4 | theme | **GOOD** | ਮਨ ਮਹਿ ਸਿਮਰਨੁ ਕਰਿਆ — correct simran lines |
| 43 | amrit | 4 | theme | **GOOD** | ਅੰਮ੍ਰਿਤ ਵੇਲਾ ਸਚੁ ਨਾਉ + ਭਾਂਡਾ ਭਾਉ ਅੰਮ੍ਰਿਤੁ ਤਿਤੁ ਢਾਲਿ — correct |
| 44 | anand | 4 | theme | **GOOD** | ਵਡੈ ਭਾਗਿ ਸਤਸੰਗਤਿ… ਹਰਿ ਪਾਇਆ ਸਹਜਿ ਅਨੰਦੁ — correct anand lines |
| 45 | bliss | 4 | roman-spelling-tolerant | **BAD** | All results: ਭੋਗ ਬਿਲਾਸ (bilaas=sensual indulgence). Engine mapped bliss→bilaas. bilaas in SGGS connotes worldly indulgence/distraction (negative), opposite of bliss. Should return ਅਨੰਦ/ਸੁਖ lines |
| 46 | fear | 4 | roman-spelling-tolerant | **BAD** | All results: ਫਿਰਿ ਫਿਰਿ (phir=again/wander) and ਪੜਿ ਪੜਿ (parh=reading). Engine matched fear→phir/par. Should return ਭਉ/ਡਰ/ਭੈ lines |
| 47 | nirbhau | 4 | roman-spelling-tolerant | **GOOD** | ਨਿਰਭਉ ਨਾਮੁ + ਨਿਰਭਉ ਨਿਰੰਕਾਰ — correct Nirbhau (fearless) attribute |
| 48 | truth | 4 | roman-spelling-tolerant | **BAD** | All 4 results: ਤੀਰਥ (teerath=pilgrimage). Engine mapped truth→teerath. Should return ਸੱਚ/ਸਤਿ/ਸਾਚੁ lines |
| 49 | sach | 4 | theme | **GOOD** | ਆਦਿ ਸਚੁ ਜੁਗਾਦਿ ਸਚੁ + ਹੈ ਭੀ ਸਚੁ — Sach/Truth perfectly served from Mool Mantar |
| 50 | guru | 4 | roman-spelling-tolerant | **GOOD** | ਗੁਰੂ ਗੁਰੁ ਗੁਰੂ ਜਪੁ ਪ੍ਰਾਨੀਅਹੁ — correct |
| 51 | shabad | 4 | theme | **GOOD** | ਘੜੀਐ ਸਬਦੁ ਸਚੀ ਟਕਸਾਲ + ਅਨਹਤਾ ਸਬਦ — correct |
| 52 | maya | 4 | theme | **GOOD** | ਰੰਗੀ ਰੰਗੀ ਭਾਤੀ ਕਰਿ ਕਰਿ ਜਿਨਸੀ ਮਾਇਆ — correct Maya |
| 53 | lobh | 4 | theme | **GOOD** | ਇਸੁ ਲੋਭੀ ਕਾ ਜੀਉ + ਅੰਤਰਿ ਲੋਭ ਵਿਕਾਰੁ — correct Lobh (greed) |
| 54 | krodh | 4 | theme | **GOOD** | ਅਗਨਿ ਕ੍ਰੋਧੁ ਚੰਡਾਲੁ + ਮਮਤਾ ਮਾਇਆ ਕ੍ਰੋਧੁ — correct |
| 55 | kaam | 4 | theme | **GOOD** | ਅਵਰਿ ਕਾਜ ਤੇਰੈ ਕਿਤੈ ਨ ਕਾਮ + ਕਾਮਿ ਕਰੋਧਿ ਨਗਰੁ — correct kaam (lust/desire) |
| 56 | moh | 4 | theme | **GOOD** | ਪੰਕਜੁ ਮੋਹ ਪਗੁ ਨਹੀ ਚਾਲੈ — correct Moh (attachment) |
| 57 | ahankar | 4 | theme | **GOOD** | ਹਉਮੈ ਮਮਤਾ ਮੋਹਣੀ ਸਭ ਮੁਠੀ ਅਹੰਕਾਰਿ — correct Ahankar (ego/pride) |

---

## Section 4 — Hindi-ish Spellings

| # | Query | Count | Mode | Rating | Notes |
|---|-------|-------|------|--------|-------|
| 58 | gyan | 4 | roman-spelling-tolerant | **GOOD** | ਗਿਆਨੀ ਗਿਆਨੁ ਕਮਾਵਹਿ — correct gian/gyan (knowledge) |
| 59 | dhyan | 4 | roman-spelling-tolerant | **GOOD** | ਧਿਆਨੀ ਧਿਆਨੁ ਲਾਵਹਿ — correct dhyan (meditation/focus) |
| 60 | prem | 4 | roman | **GOOD** | ਓਹਾ ਪ੍ਰੇਮ ਪਿਰੀ — correct Prem (divine love) |
| 61 | shakti | 4 | roman-spelling-tolerant | **GOOD** | ਆਪੇ ਸਕਤਾ… ਸਕਤੀ ਜਗਤੁ ਪਰੋਵਹਿ + ਸਿਵਾ ਸਕਤਿ — correct |
| 62 | bhakti | 4 | roman-spelling-tolerant | **BAD** | All 4 results: ਬਕਤਾ/ਬਕਤੋ (bakta=speaker/orator). SGGS spelling is ਭਗਤਿ (bhagti) not bhakti; engine maps bhakti→bakta instead of bhagti. No devotion/bhakti lines returned |
| 63 | janam | 4 | roman | **GOOD** | ਜਨਮ ਜਨਮ ਕਾ ਵਿਛੁੜਿਆ ਮਿਲਿਆ — correct janam (birth/rebirth) |
| 64 | mrityu | 4 | roman-spelling-tolerant | **WEAK** | Result 1 ਨਿਰਵੈਰੁ ਅਕਾਲ ਮੂਰਤਿ is off (nirvair phonetic match). Results 2 & 4 (ਕਬੀਰਾ ਮਰਤਾ ਮਰਤਾ ਜਗੁ ਮੁਆ) and result 3 (ਮਿਰਤੁ ਮਿਰਤੁ ਨਿਕਟਿ) are correct death/mortality lines — mixed |

---

## Section 5 — Phrases

| # | Query | Count | Mode | Rating | Notes |
|---|-------|-------|------|--------|-------|
| 65 | sat sri akal | 0 | english-translation | **GOOD** | Correctly returns 0 — "Sat Sri Akal" is a greeting, not a SGGS line. Graceful degradation |
| 66 | dhan guru nanak | 4 | roman-spelling-tolerant | **GOOD** | Final result: ਧਨੁ ਧੰਨੁ ਗੁਰੂ ਗੁਰ ਸਤਿਗੁਰੁ ਪੂਰਾ ਨਾਨਕ — correct Nanak praise line |
| 67 | mool mantar | 4 | roman-spelling-tolerant | **GOOD** | ਮੂਲ ਮੰਤ੍ਰੁ ਹਰਿ ਨਾਮੁ ਰਸਾਇਣੁ — correct Mool Mantar reference |

---

## Section 6 — Junk / Edge Inputs

| # | Query | Count | Mode | Rating | Notes |
|---|-------|-------|------|--------|-------|
| 68 | asdfgh | 0 | english-translation | **GOOD** | Clean zero results — graceful |
| 69 | 12345 | 0 | english-translation | **GOOD** | Clean zero results — graceful |
| 70 | 😊 (emoji) | 0 | english-translation | **GOOD** | Clean zero results — graceful |
| 71 | a (single letter) | 4 | roman-spelling-tolerant | **WEAK** | Returns 4 results phonetically matching 'a' vowel patterns — not harmful but could confuse a seeker who mistyped. Would be better to require ≥2 characters |
| 72 | very long phrase (85 chars) | 0 | english-translation | **GOOD** | Clean zero — graceful |
| 73 | "" (empty string) | 0 | auto | **GOOD** | Clean zero — graceful |

---

## Summary Counts

| Rating | Count | Percentage |
|--------|-------|-----------|
| GOOD | 45 | 62% |
| WEAK | 10 | 14% |
| BAD | 18 | 25% |
| **Total** | **73** | |

---

## All BAD Queries

| Query | What It Returned | Should Have Returned |
|-------|-----------------|---------------------|
| farid | ਫਿਰਦੀ ਫਿਰਦੀ (phiradee=wandering) | Lines by/about Sheikh Farid (ਫਰੀਦ) |
| krishna | ਕਿਰਸਾਣੁ (kirsan=farmer) x3 | ਕ੍ਰਿਸਨ/ਮੁਰਾਰੇ Krishna lines |
| sita | ਸਤਿ ਸਤਿ ਸਤਿ (sat=true) | ਸੀਤਾ (Sita wife of Ram) lines |
| dhru | ਡਰਿ ਘਰੁ ਡਰੁ (dar=fear) | ਧ੍ਰੂ devotee (Dhruva) lines |
| ego | ਈਘੈ ਨਿਰਗੁਨ (eegh=below, unrelated) | Haumai/ego theme lines |
| mercy | ਮੋਰਚਾ (morcha=rust) x4 | ਦਇਆ/ਕਿਰਪਾ (daya/kirpa) lines |
| peace | ਮੋਹਿ ਪਚੇ/ਪੁਛਿ ਨ (moh-burn/ask) | ਸੁਖ/ਸਹਜ/ਸ਼ਾਂਤਿ lines |
| death | ਦਾਤਾ ਦਾਤਾਰੁ (daataar=giver) x4 | ਮਰਨ/ਕਾਲ/ਮੌਤ lines |
| bliss | ਭੋਗ ਬਿਲਾਸ (bilaas=sensual indulgence) x4 | ਅਨੰਦ/ਸੁਖ (anand/sukh) lines |
| fear | ਫਿਰਿ ਫਿਰਿ/ਪੜਿ ਪੜਿ (phir=again/parh=reading) | ਭਉ/ਭੈ/ਡਰ (bhau/bhai/dar) lines |
| truth | ਤੀਰਥ (teerath=pilgrimage) x4 | ਸੱਚ/ਸਤਿ/ਸਾਚੁ lines |
| bhakti | ਬਕਤਾ/ਬਕਤੋ (bakta=orator/speaker) x4 | ਭਗਤਿ (bhagti=devotion) lines |
| shiva | ਸੇਵਤ/ਸੇਵਾ (seva=service) x3 | ਸਿਵ/ਮਹੇਸ (Shiv) lines |
| shiv | Same as shiva — seva x3, Shiv only at position 4 | ਸਿਵ lines ranked first |

*(shiva and shiv counted as 2 separate BADs since same failure; ego=1; total BADs where engine returned completely wrong results = 12 query-variants with 0 correct results in top slots)*

---

## Top 2 Improvement Suggestions

### 1. Add an English-concept synonym map before phonetic folding
English queries like **mercy, peace, death, truth, bliss, fear, ego** are being incorrectly routed to phonetic-fold (roman-spelling-tolerant) instead of the english-translation tier. The engine tries to match "death" as a romanized Punjabi syllable (→ daat/daataar) rather than looking up its translation. A pre-tier lookup table mapping high-frequency English spiritual vocabulary to their SGGS equivalents (death→maran/kaal, mercy→daya/kirpa, peace→sukh/sahaj/shanti, bliss→anand/sukh, fear→bhau/bhai, truth→sach/sat, ego→haumai/ahankar) would fix at least 7 BAD queries and flip them to GOOD.

### 2. Add a proper-name / bhagat name index with exact translit anchors
Bhagat names (farid, krishna, sita, dhru) and Hindu figure names fail because phonetic folding conflates them with unrelated common Punjabi words (farid→phirad=wandering, krishna→kirsan=farmer, sita→sat=truth, dhru→dar=fear). A dedicated name-entity index keyed on transliteration anchors (farid→fareed, krishna→krisan/krishan, sita→seetaa, dhruva→dhroo) that bypasses phonetic folding would rescue these searches. This is especially important since Sikh seekers frequently look up bhagats/saints by name.

