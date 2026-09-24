# -*- coding: utf-8 -*-
"""Knowledge context: attributed raag-timing claims (never facts) and composition form metadata."""
import sqlite3
from . import core
from .core import _FALLTHROUGH, _ID_MAX, _int, db, rows_to_list


def _route_timing_clock(p, qs):
    if core._TIMING_CACHE is not None: return core._TIMING_CACHE
    try:
        rows = rows_to_list(db().execute(
            "SELECT c.raag_name, r.roman, r.first_ang, r.seq, c.claim_type, c.pahar, "
            "       c.time_start, c.time_end, c.season, c.occasion, c.confidence, c.notes, "
            "       s.name AS source_name, s.tradition, s.url AS source_url "
            "FROM raag_timing_claims c "
            "JOIN timing_sources s ON s.id = c.source_id "
            "JOIN raags r ON r.name = c.raag_name "
            "ORDER BY r.seq, c.claim_type, c.pahar").fetchall())
        out = {'available': True,
               'pahar_convention': 'pahar 1 = 06:00-09:00 ... pahar 8 = 03:00-06:00 '
                                   '(fixed-clock rendering, 6 AM anchor); pahar 7 '
                                   '(00:00-03:00) deliberately has no raags',
               'claims': {t: [c for c in rows if c['claim_type'] == t]
                          for t in ('primary', 'variant', 'seasonal', 'ceremonial')},
               'note': 'attributed scholarly claims with citations; divergence is '
                       'preserved, never adjudicated'}
        core._TIMING_CACHE = out
        return out
    except sqlite3.OperationalError:
        return {'available': False, 'note': 'timing layer not present in this DB build'}
    return _FALLTHROUGH


def _route_timing_raag(p, qs):   # /api/timing/raag?name=<roman|gurmukhi>
    name = qs.get('name', [''])[0].strip()
    if not name:
        raise ValueError('timing/raag requires ?name=')
    try:
        r = db().execute("SELECT name, roman, first_ang FROM raags WHERE name=? OR roman=?",
                         (name, name.lower())).fetchone()
        if not r:
            return {'available': True, 'raag': name, 'claims': [],
                    'note': 'no such raag'}
        claims = rows_to_list(db().execute(
            "SELECT c.claim_type, c.pahar, c.time_start, c.time_end, c.season, "
            "       c.occasion, c.confidence, c.notes, s.name AS source_name, "
            "       s.tradition, s.url AS source_url "
            "FROM raag_timing_claims c JOIN timing_sources s ON s.id = c.source_id "
            "WHERE c.raag_name = ? ORDER BY c.claim_type, c.pahar", (r['name'],)).fetchall())
        return {'available': True, 'raag': r['name'], 'roman': r['roman'],
                'first_ang': r['first_ang'], 'claims': claims}
    except sqlite3.OperationalError:
        return {'available': False, 'raag': name, 'claims': []}
    return _FALLTHROUGH


def _route_timing_divergence(p, qs):
    try:
        names = [r[0] for r in db().execute(
            "SELECT raag_name FROM raag_timing_claims "
            "WHERE claim_type IN ('primary','variant') "
            "GROUP BY raag_name "
            # divergence = different SOURCES disagreeing; a same-source
            # multi-pahar row (e.g. Bilaval extending 1st->2nd) is an
            # extension, not a dispute
            "HAVING SUM(claim_type = 'variant') > 0 "
            "    OR (COUNT(DISTINCT COALESCE(pahar, -1)) > 1 "
            "        AND COUNT(DISTINCT source_id) > 1) "
            "ORDER BY MIN((SELECT seq FROM raags WHERE name = raag_name))").fetchall()]
        out = []
        for n in names:
            claims = rows_to_list(db().execute(
                "SELECT c.claim_type, c.pahar, c.time_start, c.time_end, c.occasion, "
                "       c.confidence, c.notes, s.name AS source_name, s.tradition, "
                "       s.url AS source_url "
                "FROM raag_timing_claims c JOIN timing_sources s ON s.id = c.source_id "
                "WHERE c.raag_name = ? AND c.claim_type IN ('primary','variant') "
                "ORDER BY c.claim_type, c.pahar", (n,)).fetchall())
            r = db().execute("SELECT roman, first_ang, seq FROM raags WHERE name=?",
                             (n,)).fetchone()
            out.append({'raag': n, 'roman': r['roman'], 'first_ang': r['first_ang'],
                        'claims': claims})
        return {'available': True, 'raags': out,
                'note': 'raags where traditions disagree on timing; every claim '
                        'cited — disagreement is preserved scholarship, not error'}
    except sqlite3.OperationalError:
        return {'available': False, 'raags': []}
    return _FALLTHROUGH


def _route_forms(p, qs):   # /api/forms?comp_id=N
    cid = _int(qs, 'comp_id', 0, 0, _ID_MAX)
    if cid <= 0:
        raise ValueError('forms requires ?comp_id=')
    try:
        row = db().execute(
            "SELECT m.comp_id, m.raag_name, m.first_ang, "
            "       mm.ghar, mm.partaal, mm.has_rahao, mm.has_rahao_dooja, "
            "       mm.dhunni, mm.jati, "
            "       sf.form, sf.pada_count, pg.genre, mm.source_label "
            "FROM shabd_raag_map m "
            "LEFT JOIN shabd_musical_markers mm ON mm.comp_id = m.comp_id "
            "LEFT JOIN shabd_structural_form sf ON sf.comp_id = m.comp_id "
            "LEFT JOIN shabd_poetic_genre pg ON pg.comp_id = m.comp_id "
            "WHERE m.comp_id = ?", (cid,)).fetchone()
        if not row:
            return {'available': True, 'comp_id': cid, 'forms': None}
        return {'available': True, 'comp_id': cid, 'forms': dict(row),
                'note': 'derived only from headings present in the verified text; '
                        'NULL means the heading states no form — never guessed'}
    except sqlite3.OperationalError:
        return {'available': False, 'comp_id': cid, 'forms': None}
    return _FALLTHROUGH
