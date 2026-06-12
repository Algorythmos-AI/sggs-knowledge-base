"""
verify_prototype.py
Gurbani quotation verification engine — stdlib only, importable.

Normalization cascade:
  1. Script detection  (Gurmukhi vs Roman)
  2. VERIFIED_EXACT   : NFC + punct-stripped byte match
  3. VERIFIED         : NFC/skeleton phrase-FTS => single hit, ratio >= 0.95
  4. PROBABLE         : best ratio >= 0.85, gap to second >= 0.05
  5. AMBIGUOUS        : top-two both >= 0.80, gap < 0.05
  6. NOT_FOUND        : best ratio < 0.70 (or no FTS hits)

Ang modifier on top: +ANG_MATCH / +ANG_MISMATCH(actual=N)

DB: /tmp/sggs.db  (SQLite, read-only, FTS5 'fts', content table 'lines')
"""

import re
import sqlite3
import unicodedata
import difflib
from typing import Optional

# ---------------------------------------------------------------------------
# Thresholds
# ---------------------------------------------------------------------------
DB_PATH          = "/tmp/sggs.db"
_THRESH_EXACT    = 0.95
_THRESH_PROBABLE = 0.85
_THRESH_AMBIG    = 0.80
_THRESH_GAP      = 0.05

# Gurmukhi vowel diacritics (matras) to strip for skeleton
_GURMUKHI_MATRAS = set("ਾਿੀੁੂੇੈੋੌ੍ੰਂਃ਼ੱੑੵ")
_PUNCT_RE        = re.compile(r"[॥।੦-੯|]")

# ---------------------------------------------------------------------------
# Script / text helpers
# ---------------------------------------------------------------------------

def _is_gurmukhi(s: str) -> bool:
    return any(0x0A00 <= ord(c) <= 0x0A7F for c in s)


def _skeletonize(s: str) -> str:
    """Strip matras from Gurmukhi string to produce consonant skeleton."""
    return "".join(c for c in s if c not in _GURMUKHI_MATRAS)


def _clean_gurmukhi(s: str) -> str:
    """Remove daanda, Gurmukhi digits, pipes; collapse whitespace."""
    return " ".join(_PUNCT_RE.sub("", s).split())


def _roman_to_tn(s: str) -> str:
    """
    Reduce a roman-transliteration token to translit_norm form:
    lowercase, drop vowels a/e/i/o/u, collapse repeated consonants.
    Mirrors the translit_norm column built at DB-creation time.
    """
    s = s.lower()
    s = re.sub(r"[aeiou]", "", s)
    s = re.sub(r"(.)\1+", r"\1", s)
    return s

# ---------------------------------------------------------------------------
# FTS query builders
# ---------------------------------------------------------------------------

def _fts_phrase(tokens: list, column: str = "", n: int = 4) -> str:
    phrase = " ".join(tokens[: min(n, len(tokens))])
    return f'{column}: "{phrase}"' if column else f'"{phrase}"'


def _fts_or(tokens: list, column: str = "") -> str:
    joined = " OR ".join(tokens)
    return f"{column}: ({joined})" if column else joined

# ---------------------------------------------------------------------------
# DB helpers
# ---------------------------------------------------------------------------

def _fetch_line(cur: sqlite3.Cursor, rowid: int) -> Optional[dict]:
    cur.execute(
        "SELECT id, ang, gurmukhi, translit, translit_norm, raag, author, comp_id, section "
        "FROM lines WHERE id = ?",
        (rowid,),
    )
    row = cur.fetchone()
    if row is None:
        return None
    return dict(zip(("id", "ang", "gurmukhi", "translit", "translit_norm", "raag", "author",
                     "comp_id", "section"), row))


def _fts_query(cur: sqlite3.Cursor, q: str, limit: int = 10) -> list:
    cur.execute(
        "SELECT rowid, rank FROM fts WHERE fts MATCH ? ORDER BY rank LIMIT ?",
        (q, limit),
    )
    return cur.fetchall()

# ---------------------------------------------------------------------------
# Lookup strategies
# ---------------------------------------------------------------------------

def _search_gurmukhi(cur: sqlite3.Cursor, nfc: str):
    """
    Three-stage Gurmukhi FTS lookup.
    Returns (candidates: [(rowid, rank)], exact_hit: rowid | None).
    """
    tokens = nfc.split()
    claim_clean = _clean_gurmukhi(nfc)

    # Stage 1: NFC text phrase (phrase match, very fast)
    rows = _fts_query(cur, _fts_phrase(tokens, "text"))
    exact_hit = None
    for rid, _ in rows:
        row = _fetch_line(cur, rid)
        if row and _clean_gurmukhi(row["gurmukhi"]) == claim_clean:
            exact_hit = rid
            break
    if rows:
        return rows, exact_hit

    # Stage 2: skeleton phrase (handles matra spelling variants)
    sk_tokens = _skeletonize(nfc).split()
    if sk_tokens:
        rows = _fts_query(cur, _fts_phrase(sk_tokens, "skeleton"))
        if rows:
            return rows, None

    # Stage 3: skeleton OR (broad fallback)
    if sk_tokens:
        rows = _fts_query(cur, _fts_or(sk_tokens, "skeleton"))
        if rows:
            return rows, None

    return [], None


def _search_roman(cur: sqlite3.Cursor, claim: str):
    """
    Two-stage Roman transliteration FTS lookup.
    Returns (candidates: [(rowid, rank)], exact_hit: rowid | None).
    """
    claim_lower = claim.lower().strip()
    tokens = claim_lower.split()

    # Stage 1: translit phrase (exact spelling)
    rows = _fts_query(cur, _fts_phrase(tokens, "translit"))
    exact_hit = None
    for rid, _ in rows:
        row = _fetch_line(cur, rid)
        if row and (row.get("translit") or "").lower().strip() == claim_lower:
            exact_hit = rid
            break
    if rows:
        return rows, exact_hit

    # Stage 2: translit_norm phrase (vowel-reduced, tolerates spelling variants)
    tn_tokens = [_roman_to_tn(w) for w in tokens]
    rows = _fts_query(cur, _fts_phrase(tn_tokens, "translit_norm"))
    if rows:
        return rows, None

    # Stage 3: translit_norm OR
    rows = _fts_query(cur, _fts_or(tn_tokens, "translit_norm"))
    return rows, None

# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------

def _score(candidate_row: dict, claim_clean: str, claim_tn: str, is_gurmukhi: bool) -> float:
    if is_gurmukhi:
        db_clean = _clean_gurmukhi(candidate_row["gurmukhi"])
        return difflib.SequenceMatcher(None, claim_clean, db_clean).ratio()
    else:
        db_tn = candidate_row.get("translit_norm") or ""
        return difflib.SequenceMatcher(None, claim_tn, db_tn).ratio()

# ---------------------------------------------------------------------------
# Verdict determination
# ---------------------------------------------------------------------------

def _make_verdict(candidates, exact_hit, claim_clean, claim_tn, is_gurmukhi, cur):
    if not candidates:
        return {
            "verdict": "NOT_FOUND", "confidence": 0.0,
            "matched_line_id": None, "_best_row": None,
            "distance_details": {"note": "no FTS hits"},
        }

    scored = []
    for rid, _ in candidates:
        row = _fetch_line(cur, rid)
        if row is None:
            continue
        ratio = _score(row, claim_clean, claim_tn, is_gurmukhi)
        scored.append((ratio, rid, row))

    if not scored:
        return {
            "verdict": "NOT_FOUND", "confidence": 0.0,
            "matched_line_id": None, "_best_row": None,
            "distance_details": {"note": "scoring yielded no rows"},
        }

    scored.sort(key=lambda x: -x[0])
    best_ratio, best_rid, best_row = scored[0]
    second_ratio = scored[1][0] if len(scored) > 1 else 0.0
    gap = best_ratio - second_ratio

    # Containment tier: the claim is a clean FRAGMENT of a canonical line
    # (people quote half-tuks constantly). Requires >= 3 words or >= 12 chars.
    if exact_hit is None and (claim_clean or claim_tn):
        needle = claim_clean if is_gurmukhi else claim_tn
        if needle and (len(needle) >= 12 or len(needle.split()) >= 3):
            for ratio, rid, row in scored:
                hay = _clean_gurmukhi(row["gurmukhi"]) if is_gurmukhi \
                      else (row.get("translit_norm") or "")
                if f" {needle} " in f" {hay} ":
                    return {
                        "verdict": "VERIFIED_PARTIAL",
                        "confidence": 0.95,
                        "matched_line_id": rid, "_best_row": row,
                        "distance_details": {"note": "claim is a fragment of this full line",
                                             "fragment_len": len(needle)},
                    }

    if exact_hit is not None:
        verdict = "VERIFIED_EXACT"
        confidence = 1.0
    elif best_ratio >= _THRESH_EXACT:
        verdict = "VERIFIED"
        confidence = best_ratio
    elif best_ratio >= _THRESH_PROBABLE:
        if second_ratio >= _THRESH_AMBIG and gap < _THRESH_GAP:
            verdict = "AMBIGUOUS"
        else:
            verdict = "PROBABLE"
        confidence = best_ratio
    else:
        verdict = "NOT_FOUND"
        confidence = best_ratio

    best_rid_out = best_rid if verdict != "NOT_FOUND" else None
    best_row_out = best_row if verdict != "NOT_FOUND" else None

    return {
        "verdict": verdict,
        "confidence": round(confidence, 4),
        "matched_line_id": best_rid_out,
        "_best_row": best_row_out,
        "distance_details": {
            "best_ratio": round(best_ratio, 4),
            "second_ratio": round(second_ratio, 4),
            "gap": round(gap, 4),
            "candidates_scored": len(scored),
        },
    }

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def verify(claim: str, ang: Optional[int] = None, db_path: str = DB_PATH) -> dict:
    """
    Verify a claimed Gurbani quotation against the canonical SGGS corpus.

    Parameters
    ----------
    claim   : Claimed text — Gurmukhi, Roman transliteration, or mixed.
    ang     : Claimed Ang (page) number, or None to skip ang check.
    db_path : Path to sggs.db SQLite file (read-only access used).

    Returns
    -------
    {
      verdict          : str   — VERIFIED_EXACT|VERIFIED|PROBABLE|AMBIGUOUS|NOT_FOUND
                                 with optional suffix +ANG_MATCH or +ANG_MISMATCH(actual=N)
      confidence       : float — 0.0 – 1.0
      matched_line_id  : int|None
      ang              : int|None   — actual ang from DB
      gurmukhi         : str|None   — canonical DB gurmukhi
      raag             : str|None
      author           : str|None
      distance_details : dict  — scoring metadata
    }
    """
    con = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    cur = con.cursor()

    try:
        claim = claim.strip()
        nfc   = unicodedata.normalize("NFC", claim)
        is_g  = _is_gurmukhi(nfc)

        if is_g:
            claim_clean = _clean_gurmukhi(nfc)
            claim_tn    = ""
            candidates, exact_hit = _search_gurmukhi(cur, nfc)
        else:
            claim_clean = ""
            claim_tn    = " ".join(_roman_to_tn(w) for w in nfc.lower().split())
            candidates, exact_hit = _search_roman(cur, nfc)

        result = _make_verdict(candidates, exact_hit, claim_clean, claim_tn, is_g, cur)

        best_row: Optional[dict] = result.pop("_best_row", None)
        actual_ang = best_row["ang"] if best_row else None

        # Ang modifier
        ang_tag = ""
        if result["verdict"] not in ("NOT_FOUND",) and ang is not None and actual_ang is not None:
            ang_tag = "+ANG_MATCH" if ang == actual_ang else f"+ANG_MISMATCH(actual={actual_ang})"
        result["verdict"] = result["verdict"] + ang_tag

        result["ang"]      = actual_ang
        result["gurmukhi"] = best_row["gurmukhi"] if best_row else None
        result["raag"]     = best_row["raag"]     if best_row else None
        result["author"]   = best_row["author"]   if best_row else None
        result["comp_id"]  = best_row["comp_id"]  if best_row else None   # lets the UI open
        result["section"]  = best_row["section"]  if best_row else None   # the full shabad

        return result

    finally:
        con.close()

# ---------------------------------------------------------------------------
# CLI self-test
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import time

    TEST_CASES = [
        ("(a) exact Gurmukhi",
         "ਸੋਚੈ ਸੋਚਿ ਨ ਹੋਵਈ ਜੇ ਸੋਚੀ ਲਖ ਵਾਰ", None),

        ("(b) misspelled Gurmukhi",
         "ਸੋਚੇ ਸੋਚ ਨ ਹੋਵਈ ਜੇ ਸੋਚੀ ਲਖ ਵਾਰ", None),

        ("(c) roman exact",
         "pavan guroo paanee pitaa maataa dharat mahat", None),

        ("(d) roman misremembered",
         "pavan guru pani pita mata dharti mahat", None),

        ("(e) fabricated -- must be NOT_FOUND",
         "ਨਾਨਕ ਸੋਨੇ ਦੀ ਚਿੜੀਆ ਉਡ ਗਈ", None),

        ("(f) real line + wrong ang (actual=1, claim=999)",
         "ਸੋਚੈ ਸੋਚਿ ਨ ਹੋਵਈ ਜੇ ਸੋਚੀ ਲਖ ਵਾਰ", 999),

        ("(g) ardas line -- NOT in SGGS, no false-positive",
         "ਨਾਨਕ ਨਾਮ ਚੜ੍ਹਦੀ ਕਲਾ", None),
    ]

    W = 42
    print(f"{'─'*80}")
    print(f"{'Label':<{W}} {'Verdict':<38} {'Conf':>5}  {'ms':>6}")
    print(f"{'─'*80}")

    for label, claim, ang in TEST_CASES:
        t0 = time.perf_counter()
        r  = verify(claim, ang=ang)
        ms = (time.perf_counter() - t0) * 1000

        print(f"{label:<{W}} {r['verdict']:<38} {r['confidence']:>5.3f}  {ms:>6.1f}ms")
        parts = []
        if r["ang"]:
            parts.append(f"ang={r['ang']}")
        dd = r.get("distance_details", {})
        if "best_ratio" in dd:
            parts.append(f"best_ratio={dd['best_ratio']}")
        if r.get("gurmukhi"):
            parts.append(f"gurmukhi={r['gurmukhi'][:55]}")
        if parts:
            print(f"  {' | '.join(parts)}")
        print()

    print(f"{'─'*80}")
