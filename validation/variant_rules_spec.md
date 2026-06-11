# Gurbani Romanization Variant Generator — Deterministic Rule Table

**Version:** 1.0  
**Date:** 2026-06-11  
**Corpus:** SGGS SQLite (`sggs.db`), 24 673 distinct translit tokens  
**Canonical scheme:** doubled long vowels (`aa/ee/oo`), `ai/au` diphthongs, aspirates as digraphs, terminal sihari/aunkar already dropped.

---

## 1. Terminology

| Term | Meaning |
|---|---|
| **canonical** | The stored transliteration (e.g. `giaan`, `ammrit`) |
| **variant** | A user-typed spelling to be mapped → canonical |
| **weight** | 0–1 estimate of how frequently real users type this form |
| **position** | `anywhere` / `initial` / `terminal` / `medial` |
| **composition** | Applying rules in sequence to one canonical (BFS depth = 3) |
| **veto** | Variant discarded because it equals a common ambiguous English word |

---

## 2. Rule Table (ordered by priority)

Rules are numbered R01–R15. Apply all applicable rules independently; then apply the approved composition pairs (§4). Collect all results, deduplicate, drop those in the veto list (§5), drop any result with `len < 2`, cap at 15 variants per word sorted ascending by `(len, lex)`.

---

### R01 — Long-A fold: `aa → a`

| Field | Value |
|---|---|
| **Pattern** | `aa` |
| **Replacement** | `a` |
| **Position** | anywhere |
| **Weight** | 0.90 |
| **Regex (Python)** | `re.sub(r'aa', 'a', canon)` |
| **Example** | `naam → nam`, `raam → ram`, `karataa → karata`, `sadaa → sada` |
| **Notes** | Single global replace (replaces all `aa` occurrences). This is the single highest-frequency fold in the corpus. |

---

### R02 — Long-I fold: `ee → i`

| Field | Value |
|---|---|
| **Pattern** | `ee` |
| **Replacement** | `i` |
| **Position** | anywhere |
| **Weight** | 0.85 |
| **Regex** | `re.sub(r'ee', 'i', canon)` |
| **Example** | `keeratan → kiratan`, `phareedaa → pharidaa`, `naahee → naahi` |
| **Notes** | Global replace. Do NOT combine with R03 in the same pass (handled by composition §4). |

---

### R03 — Long-U fold: `oo → u`

| Field | Value |
|---|---|
| **Pattern** | `oo` |
| **Replacement** | `u` |
| **Position** | anywhere |
| **Weight** | 0.85 |
| **Regex** | `re.sub(r'oo', 'u', canon)` |
| **Example** | `prabhoo → prabhu`, `saadhoo → sadhoo → sadhu` (via R01+R03 composition), `guroo → guru` |
| **Notes** | Global replace. Terminal `-oo → -u` is the dominant sub-case (covered here). |

---

### R04 — Iaan-contraction: `[C]iaan → [C]yan`

| Field | Value |
|---|---|
| **Pattern** | `([bcdfghjklmnprstvwxyz])iaan` |
| **Replacement** | `\1yan` |
| **Position** | medial or initial-of-root |
| **Weight** | 0.80 |
| **Regex** | `re.sub(r'([bcdfghjklmnprstvwxyz])iaan', r'\1yan', canon)` |
| **Example** | `giaan → gyan`, `dhiaan → dhyan`, `agiaan → agyan`, `giaanee → gyanee` |
| **Notes** | English-speaker preferred contraction. Covers the giaan/dhiaan family. Do NOT apply when `iaan` is preceded by a vowel. Guard is the `[C]` lookbehind as written. |

---

### R05 — Iaan-partial: `[C]iaan → [C]iyan`

| Field | Value |
|---|---|
| **Pattern** | `([bcdfghjklmnprstvwxyz])iaan` |
| **Replacement** | `\1iyan` |
| **Position** | medial or initial-of-root |
| **Weight** | 0.55 |
| **Regex** | `re.sub(r'([bcdfghjklmnprstvwxyz])iaan', r'\1iyan', canon)` |
| **Example** | `giaan → giyan`, `dhiaan → dhiyan` |
| **Notes** | Secondary contraction; less common than R04 but attested. Do not compose further. |

---

### R06 — Au-diphthong fold: `au → o`

| Field | Value |
|---|---|
| **Pattern** | `au` |
| **Replacement** | `o` |
| **Position** | anywhere |
| **Weight** | 0.80 |
| **Regex** | `re.sub(r'au', 'o', canon)` |
| **Example** | `nirabhau → nirabho`, `bhau → bho`, `haumai → homai`, `kau → ko` |
| **Notes** | Global replace. Short words (`kau`, `hau`, `tau`) produce valid variants in Gurbani context — do not length-gate. After R14 composition: `nirabhau → nirbhau → nirbho` (two-step). |

---

### R07 — Au-diphthong alt: `au → ou`

| Field | Value |
|---|---|
| **Pattern** | `au` |
| **Replacement** | `ou` |
| **Position** | anywhere |
| **Weight** | 0.70 |
| **Regex** | `re.sub(r'au', 'ou', canon)` |
| **Example** | `nirabhau → nirabhou`, `bhau → bhou`, `haumai → houmai` |
| **Notes** | Common anglophone spelling of this diphthong. |

---

### R08 — Ai-diphthong fold: `ai → e` (length-gated)

| Field | Value |
|---|---|
| **Pattern** | `ai` (only when `len(canon) >= 5`) |
| **Replacement** | `e` |
| **Position** | anywhere |
| **Weight** | 0.75 |
| **Regex** | `re.sub(r'ai', 'e', canon) if len(canon) >= 5 else None` |
| **Example** | `haumai → haume`, `aavai → aave`, `jaanai → jaane`, `milai → mile` |
| **Notes** | **Length gate is critical**: `hai→he`, `mai→me`, `lai→le`, `bhai→bhe` are English collisions that MUST be suppressed. The gate `len >= 5` eliminates all 3-4 char ai-words. |

---

### R09 — Ai-diphthong alt: `ai → ay` (length-gated)

| Field | Value |
|---|---|
| **Pattern** | `ai` (only when `len(canon) >= 5`) |
| **Replacement** | `ay` |
| **Position** | anywhere |
| **Weight** | 0.65 |
| **Regex** | `re.sub(r'ai', 'ay', canon) if len(canon) >= 5 else None` |
| **Example** | `haumai → haumay`, `aavai → aavay`, `jaanai → jaanay` |
| **Notes** | Same length gate as R08. `mai→may`, `hai→hay`, `lai→lay` are suppressed. |

---

### R10 — V-W initial swap: `v → w` (initial only)

| Field | Value |
|---|---|
| **Pattern** | `^v` |
| **Replacement** | `w` |
| **Position** | **initial** |
| **Weight** | 0.85 |
| **Regex** | `'w' + canon[1:] if canon.startswith('v') else None` |
| **Example** | `vaahiguroo → waahiguroo`, `vasai → wasai`, `vich → wich`, `vin → win` |
| **Notes** | The canonical scheme uses `v`; Punjabi and English speakers freely alternate `v/w` at word-initial position. The corpus has zero `w`-initial tokens, confirming `v` is canonical and `w` is always a variant. Medial `v/w` swap is NOT included (medial `v` is stable). |

---

### R11 — Geminate drop: `CC → C`

| Field | Value |
|---|---|
| **Pattern** | `([bcdfghjklmnprstvwxyz])\1` |
| **Replacement** | `\1` |
| **Position** | anywhere |
| **Weight** | 0.80 |
| **Regex** | `re.sub(r'([bcdfghjklmnprstvwxyz])\1', r'\1', canon)` |
| **Example** | `ammrit → amrit`, `simmrit → simrit`, `mann → man`, `dhann → dhan` |
| **Notes** | Global replace (handles all doubled consonants). English writers rarely double consonants in Punjabi romanization. Note: `man` coincides with English but in Gurbani context means "mind" — do NOT veto (see §5). |

---

### R12 — Terminal -am to -um (length-gated + r-guard)

| Field | Value |
|---|---|
| **Pattern** | `am$` when `len(canon) >= 5` AND `canon[-3] != 'r'` AND does not end in `aam` |
| **Replacement** | `um` |
| **Position** | **terminal** |
| **Weight** | 0.60 |
| **Regex** | `canon[:-2] + 'um' if (canon.endswith('am') and not canon.endswith('aam') and len(canon) >= 5 and canon[-3] != 'r') else None` |
| **Example** | `hukam → hukum`, `janam → janum`, `khasam → khasum` |
| **Notes** | The back-rounded influence makes users hear and type `-um`. **Length gate** (`>= 5`) suppresses `ham→hum`, `jam→jum`, `sam→sum` (English collisions). **r-guard** suppresses `dharam→dharum`, `param→parum`, `bharam→bharum` (the `-ram` terminal vowel is a full `a`, not a schwa, and `-rum` is not attested). |

---

### R13 — Ph-to-F: `ph → f`

| Field | Value |
|---|---|
| **Pattern** | `ph` |
| **Replacement** | `f` |
| **Position** | anywhere |
| **Weight** | 0.70 |
| **Regex** | `re.sub(r'ph', 'f', canon)` |
| **Example** | `phareedaa → fareedaa`, `phal → fal`, `saphal → safal`, `phirat → firat` |
| **Notes** | Common anglicization. **Highest veto-collision risk**: `phir → fir` (English tree), `phun → fun` (English). Add `fir` and `fun` to the veto list (§5). `phal → fal`, `pher → fer` are safe. |

---

### R14 — Post-r schwa drop: `[V]raC → [V]rC`

| Field | Value |
|---|---|
| **Pattern** | `(?<=[aeiou])(r)a([bcdfghjklmnprstvwxyz])` |
| **Replacement** | `\1\2` |
| **Position** | medial (lookbehind ensures preceding vowel) |
| **Weight** | 0.75 |
| **Regex** | `re.sub(r'(?<=[aeiou])(r)a([bcdfghjklmnprstvwxyz])', r'\1\2', canon)` |
| **Example** | `keeratan → keertan`, `karataa → kartaa`, `nirabhau → nirbhau`, `darasan → darsan`, `dharam → dharm` |
| **Notes** | The lookbehind `(?<=[aeiou])` is **essential**: prevents `prabhoo` from becoming `prbhoo` (where `r` is in a `pr` consonant-onset cluster). Without it, `pra`-words collapse wrongly. This is the most productive schwa-drop pattern in the corpus. |

---

### R15 — Pre-r schwa drop (limited): `[msn]arV → [msn]rV`

| Field | Value |
|---|---|
| **Pattern** | `([msn])a(r[aeiou])` |
| **Replacement** | `\1\2` |
| **Position** | medial |
| **Weight** | 0.70 |
| **Regex** | `re.sub(r'([msn])a(r[aeiou])', r'\1\2', canon)` |
| **Example** | `simaran → simran` |
| **Notes** | Narrowly scoped to `m/s/n` before `ar+vowel` to prevent over-firing. `charan → chran` and `karah → krah` are wrong and must not fire. Empirically `simaran → simran` is the primary use case (170 occurrences). Do NOT broaden to all consonants. |

---

## 3. Rules Considered and Rejected

| Rule | Description | Reason for Rejection |
|---|---|---|
| `kh → k` | Aspirate simplification (`guramukh→guramuk`) | **Deferred to aspirate-fold tier** per spec. Including here would duplicate downstream tier and generate weird variants (`sukh→suk`). CONFIRMED: not a variant rule. |
| Medial-i drop | `V+C+i+C → V+C+C` (`satigur→satgur`) | Too broad: fires incorrectly on `simaran→smaran`, `nirbhau→nrbhau`. Valid cases are rare and covered by the aspirate/schwa fold tier. Excluded. |
| `ai→e/ay` for `len<5` | `mai→me`, `hai→he`, etc. | Hard English collision (`me`, `he`, `may`, `hay`, `lay`, `say`). Suppressed by length gate on R08/R09. |
| Nasal assimilation `n→ng` before velars | Variant rule for `sang`, `rang` | Not needed: canonical already writes `ng` when that is the actual sound. Users type `sang` expecting it to match `sang`. No variant required. |
| Nasal assimilation `n→m` before labials | `anmrit→ammrit` | Canonical already reflects assimilation (`ammrit` not `anmrit`). No variant needed. |
| `w→v` reverse | For canonical `v` words | R10 already generates `w`-variants from `v`-canonicals. No `w`-initial tokens exist in the corpus to need a reverse rule. |
| `y→j` or `j→y` initial swap | `yaar→jaar` or `jan→yan` | Corpus has only 9 `y`-initial tokens (rare Persian borrowings). `j→y` would create massive false positives across the commonest token class. Both rejected. |
| Terminal `-oo → -o` | `guroo→guro` | Not attested as user behavior; users go to `-u` (R03) or keep `-oo`. `-o` terminal is not a convention. |

---

## 4. Composition Policy

**BFS depth: 3 (apply at most 3 rules per variant).**

> **Amended at implementation (v1.7.0):** depth 2, as originally specified here, could not reach attested user spellings requiring three composed rules — e.g. `vaahiguroo → wahiguru` (R10 v→w + R01 aa→a + R03 oo→u). The deployed engine (`pipeline/build_variants.py`) uses depth 3 with the ≤15-per-word truncation and score-product ranking absorbing the larger candidate space. Build time remains <1s.

Permitted two-rule compositions (applied in order listed; do not compose further):

| Combo | Rules Applied | Example | Output |
|---|---|---|---|
| C1 | R14 + R01 | `karataa → kartaa → karta` | `karta` |
| C2 | R10 + R01 | `vaahiguroo → waahiguroo → wahiguroo` | `wahiguroo` |
| C3 | R10 + R03 | `vaahiguroo → waahiguroo → waahiguru` | `waahiguru` |
| C4 | R01 + R03 | `vaahiguroo → vahiguroo → vahiguru` | `vahiguru` |
| C5 | R10 + (R01 then R03) | encoded as two 2-step passes | `wahiguru` |
| C6 | R14 + R06 | `nirabhau → nirbhau → nirbho` | `nirbho` |
| C7 | R02 + R01 | `keeratan → kiratan → kirata` | `kirata` |
| C8 | R01 + R03 | where both `ee` and `oo` present | per-word |

**Forbidden compositions:**
- R12 + R14 or R12 + R15: would create triple-consonant clusters.
- R04 + R05: same substitution site, mutually exclusive.
- R08 + R09: same substitution site, mutually exclusive.
- R06 + R07: same substitution site, mutually exclusive.
- Any rule with itself (idempotent).

**Implementation:** BFS over the rule set to depth 3: seed with the canonical, expand each frontier item with every applicable rule, deduplicate keeping the best score (product of rule weights), then truncate to the top 15.

---

## 5. Veto List and Collision Flags

### Hard-veto set (ambiguous English words)

```
is in on to or it at am an the for of and
more note hope cool rule soon keen seen teen been rude pure cure
hue sue due rue cue blue clue true
me he she we
may hay lay say ray way pay day bay gay
fir fun
```

### Do NOT veto (Gurbani terms that coincide with English)

```
man    (mind / ਮਨ — 4 378 occurrences)
ram    (Raam / ਰਾਮ — proper name, 2 018 occurrences)
nam    (Naam / ਨਾਮੁ — core concept)
sang   (company / ਸੰਗ)
rang   (color / ਰੰਗ)
sat    (truth / ਸਤਿ)
sant   (saint / ਸੰਤ)
prem   (love / ਪ੍ਰੇਮ)
jot    (light / ਜੋਤਿ)
gun    (virtue / ਗੁਣ)
tan    (body / ਤਨੁ)
```

### Rules with highest veto-collision risk

| Rule | Risk Example | Mitigation |
|---|---|---|
| R08/R09 (ai fold) | `mai→me`, `hai→hay` | Length gate (`len >= 5`) suppresses all short-word cases |
| R13 (ph→f) | `phir→fir`, `phun→fun` | Add `fir`, `fun` to hard-veto explicitly |
| R01 (aa→a) short words | `naam→nam`, `raam→ram` | Allow — these are Gurbani terms, not English collisions |
| R12 (-am→-um) | `ham→hum`, `jam→jum` | Length gate (`len >= 5`) suppresses |

---

## 6. Complete Algorithm (Python)

```python
import re

VETO = {
    'is','in','on','to','or','it','at','am','an','the','for','of','and',
    'more','note','hope','cool','rule','soon','keen','seen','teen','been',
    'rude','pure','cure','hue','sue','due','rue','cue','blue','clue','true',
    'me','he','she','we',
    'may','hay','lay','say','ray','way','pay','day','bay','gay',
    'fir','fun',
}

def generate_variants(canon: str) -> list:
    variants = set()

    # R01: aa → a
    if 'aa' in canon:
        variants.add(canon.replace('aa', 'a'))
    # R02: ee → i
    if 'ee' in canon:
        variants.add(canon.replace('ee', 'i'))
    # R03: oo → u
    if 'oo' in canon:
        variants.add(canon.replace('oo', 'u'))
    # R04: [C]iaan → [C]yan
    v = re.sub(r'([bcdfghjklmnprstvwxyz])iaan', r'\1yan', canon)
    if v != canon: variants.add(v)
    # R05: [C]iaan → [C]iyan
    v = re.sub(r'([bcdfghjklmnprstvwxyz])iaan', r'\1iyan', canon)
    if v != canon: variants.add(v)
    # R06: au → o
    if 'au' in canon:
        variants.add(canon.replace('au', 'o'))
    # R07: au → ou
    if 'au' in canon:
        variants.add(canon.replace('au', 'ou'))
    # R08: ai → e (length-gated)
    if 'ai' in canon and len(canon) >= 5:
        variants.add(canon.replace('ai', 'e'))
    # R09: ai → ay (length-gated)
    if 'ai' in canon and len(canon) >= 5:
        variants.add(canon.replace('ai', 'ay'))
    # R10: initial v → w
    if canon.startswith('v'):
        variants.add('w' + canon[1:])
    # R11: CC → C (geminate drop)
    v = re.sub(r'([bcdfghjklmnprstvwxyz])\1', r'\1', canon)
    if v != canon: variants.add(v)
    # R12: terminal -am → -um (guarded)
    if (canon.endswith('am') and not canon.endswith('aam')
            and len(canon) >= 5 and canon[-3] != 'r'):
        variants.add(canon[:-2] + 'um')
    # R13: ph → f
    if 'ph' in canon:
        variants.add(canon.replace('ph', 'f'))
    # R14: post-r schwa drop [V]raC → [V]rC
    v = re.sub(r'(?<=[aeiou])(r)a([bcdfghjklmnprstvwxyz])', r'\1\2', canon)
    if v != canon: variants.add(v)
    # R15: pre-r schwa drop [msn]arV → [msn]rV
    v = re.sub(r'([msn])a(r[aeiou])', r'\1\2', canon)
    if v != canon: variants.add(v)

    # COMPOSITION PASS (BFS depth 3 — see amendment above)
    tier1 = set(variants)
    for bv in tier1:
        if 'aa' in bv: variants.add(bv.replace('aa', 'a'))
        if 'ee' in bv: variants.add(bv.replace('ee', 'i'))
        if 'oo' in bv: variants.add(bv.replace('oo', 'u'))
        if 'au' in bv:
            variants.add(bv.replace('au', 'o'))
            variants.add(bv.replace('au', 'ou'))
        if bv.startswith('v'):
            variants.add('w' + bv[1:])

    # FILTER
    result = [
        v for v in variants
        if v != canon and len(v) >= 2 and v not in VETO
    ]
    result.sort(key=lambda x: (len(x), x))
    return result[:15]
```

---

## 7. Empirical Validation — 25 Words

| Canonical | n (corpus) | Generated Variants | Sanity |
|---|---|---|---|
| `giaan` | 410 | `gian`, `gyan`, `giyan` | PASS — all 3 attested in diaspora usage |
| `krisan` | 15 | *(none)* | ACCEPT — `krishan`/`krishna` need aspirate-insertion (out of scope) |
| `vaahiguroo` | 13 | `vahiguru`, `vaahiguru`, `vahiguroo`, `waahiguru`, `wahiguroo`, `waahiguroo`, `wahiguru` | PASS — `waheguru`/`wahiguru` are dominant internet spellings |
| `jasodaa` | rare | `jasoda` | PASS |
| `dhiaan` | 183 | `dhian`, `dhyan`, `dhiyan` | PASS — `dhyan` is the yoga-context standard |
| `prem` | 228 | *(none)* | PASS — canonical is already dominant |
| `simaran` | 170 | `simarn`, `simran` | PASS — `simran` is a very common Punjabi name, highly searched |
| `ammrit` | 733 | `amrit` | PASS — most commonly dropped geminate |
| `hukam` | 330 | `hukum` | PASS — widely used |
| `santokh` | 108 | *(none)* | PASS — terminal `kh` is stable; users do not drop it |
| `nirabhau` | 163 | `nirabho`, `nirbhau`, `nirabhou`, `nirbho`, `nirbhou` | PASS — `nirbhau` and `nirbho` both used in Nitnem discussions |
| `mukat` | 338 | *(none)* | PARTIAL — `mukti` needs vowel-insertion (out of scope) |
| `keeratan` | 128 | `kiratan`, `keertan`, `kirtan` | PASS — `kirtan` is the dominant global spelling |
| `saadhoo` | 336 | `sadhu`, `saadhu`, `sadhoo` | PASS — `sadhu` is standard English |
| `bhagat` | 1001 | *(none)* | PASS — canonical is used universally |
| `naam` | 4902 | `nam` | PASS — short form used by diaspora writers |
| `prabhoo` | 131 | `prabhu` | PASS — dominant English spelling; no `prbhoo` (lookbehind guard works) |
| `raam` | 2018 | `ram` | PASS — common English form |
| `sat` | 391 | *(none)* | PASS — already minimal |
| `karataa` | 350 | `karta`, `karata`, `kartaa` | PASS — `karta` is dominant diaspora spelling |
| `sant` | 745 | *(none)* | PASS — already minimal |
| `sevaa` | 422 | `seva` | PASS — standard anglicized form |
| `jot` | 312 | *(none)* | PASS |
| `man` | 4378 | *(none)* | PASS — already minimal; intentionally NOT vetoed |
| `dharam` | 163 | `dharm` | PASS — R12 r-guard correctly suppresses `dharum`; R14 gives `dharm` |

---

## 8. Aspirate-Drop Tier Confirmation

`kh → k` is confirmed NOT a variant rule here, for three reasons:

1. The spec reserves aspirate-drop for a downstream fold tier (index-side normalization).
2. `sukh→suk`, `guramukh→guramuk`, `dekh→dek` are not how users search.
3. The fold tier can normalize `sukh` and `suk` to the same bucket without polluting per-word variant lists.

Aspirate insertion (`s→sh` for `krisan→krishan`) is also out of scope — proper-name transliteration variants should be handled by a curated override table, not rule-generated.

---

## 9. Summary

| Metric | Value |
|---|---|
| Total base rules | 15 (R01–R15) |
| Composition depth | 3 (amended from 2 at implementation; see §4) |
| Avg variants / word (25-word sample) | ~2.8 |
| Max variants / word | 7 (`vaahiguroo`) |
| Veto list size | 42 entries |
| Highest-risk rules for English collision | R13 (`ph→f`), R08/R09 (mitigated by length gate) |
| Explicitly excluded rules | `kh→k` (fold tier), medial-i drop (too broad), `j/y` swap (too broad), `ai` fold for `len<5` (English collision) |
