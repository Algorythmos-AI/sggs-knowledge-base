# -*- coding: utf-8 -*-
"""Verify context: the /api/verify route over the quotation-verification engine (webapp/verify.py)."""
from . import core
from .core import _FALLTHROUGH, _int_str
from verify import verify as verify_claim

# Tables this context reads (webapp/verify.py, through its own read-only connection). The platform split cuts each service's database
# slice from this declaration; webapp/tests/test_declared_tables.py runs every route of the
# context under an SQLite authorizer that denies anything undeclared.
TABLES = frozenset({
    'fts',
    'lines',
})


MAX_CLAIM_CHARS = 600                                # /api/verify?q= — see the route


def _route_verify(p, qs):
    q = qs.get('q', [''])[0].strip()
    if not q: raise ValueError('empty claim')
    # verify() ORs every token into one FTS query and then runs difflib per candidate, so its
    # cost grows with the claim: an 18 KB claim measured ~7 s of CPU on one core. A quotation is
    # a line or two — bound it here (verify.py stays byte-identical to the Swift port).
    if len(q) > MAX_CLAIM_CHARS: raise ValueError(f'claim too long (max {MAX_CLAIM_CHARS} chars)')
    ang_q = qs.get('ang', [None])[0]
    ang_n = _int_str(ang_q, 1, 1430) if ang_q else None
    return verify_claim(q, ang=ang_n, db_path=core.DB)
    return _FALLTHROUGH
