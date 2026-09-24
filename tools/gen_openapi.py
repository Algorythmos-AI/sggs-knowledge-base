#!/usr/bin/env python3
"""Generate contract/openapi.json — the OpenAPI 3.1 description of every /api/* route.

    python3 tools/gen_openapi.py [--check]

Routes, parameters, limits and descriptions are declared once in ROUTES below (they mirror
webapp/serve.py:api(); a unit test fails if a route is added to or removed from either
side). Response schemas are INFERRED from real responses of the in-process API on
db/sggs.sqlite, so the spec cannot drift from what the server actually returns: --check
regenerates in memory and exits 1 if the committed file differs (run by the test suite).

Stdlib only. Written as JSON (valid OpenAPI) so the repo's stdlib-only tests can parse it.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "webapp"))
import serve  # noqa: E402

OUT = ROOT / "contract" / "openapi.json"
API_CONTRACT_VERSION = "1.0.0"   # bump only for an API change; breaking changes get a new major
ID_MAX = serve._ID_MAX


def q(name, schema, desc, required=False):
    return {"name": name, "in": "query", "required": required, "description": desc, "schema": schema}


def p(name, schema, desc):
    return {"name": name, "in": "path", "required": True, "description": desc, "schema": schema}


INT = {"type": "integer"}
STR = {"type": "string"}
IDS = {"type": "string", "pattern": "^[0-9]{1,12}(,[0-9]{1,12})*$"}

# path -> (tag, summary, parameters, samples[(concrete path, query)], extra error codes)
ROUTES = {
    "/api/meta": ("Meta", "Build identity and corpus statistics (version, commit, counts).", [],
                  [("/api/meta", {})], []),
    "/api/health": ("Meta", "Integrity self-test: line/Ang counts, FTS, verbatim Mool Mantar, ੴ count, live verify, bani registry.", [],
                    [("/api/health", {})], []),
    "/api/search": ("Search", "Search the Granth through the ranked waterfall (exact FTS, seeker lexicon, variants, English, passage, fold).", [
        q("q", {"type": "string", "maxLength": 300}, "Query in Gurmukhi, romanised Gurmukhi or English.", True),
        q("mode", {"type": "string", "enum": ["auto", "gurmukhi", "roman", "english", "first", "theme"], "default": "auto"}, "Search mode."),
        q("limit", dict(INT, minimum=0, maximum=200, default=50), "Page size (clamped)."),
        q("offset", dict(INT, minimum=0, maximum=1000000, default=0), "Page offset (clamped).")],
        [("/api/search", {"q": ["waheguru"]}), ("/api/search", {"q": ["ਨਾਮੁ"], "mode": ["gurmukhi"]}),
         ("/api/search", {"q": ["haumai"], "mode": ["theme"]})], []),
    "/api/ang/{n}": ("Scripture", "Every verbatim line of one Ang, with its raag, section, authors and the composition it continues.", [
        p("n", dict(INT, minimum=1, maximum=1430), "Ang number (clamped to 1–1430).")],
        [("/api/ang/1", {}), ("/api/ang/712", {})], []),
    "/api/shabad/{comp_id}": ("Scripture", "Every verbatim line of one composition, heading run included.", [
        p("comp_id", dict(INT, minimum=0, maximum=ID_MAX), "Composition id.")],
        [("/api/shabad/2", {}), ("/api/shabad/682", {})], ["404"]),
    "/api/random": ("Scripture", "A complete structural unit (Hukam) chosen at random.", [],
                    [("/api/random", {"_seed": 1}), ("/api/random", {"_seed": 400})], []),
    "/api/lines": ("Scripture", "Verbatim lines by id (used to repair saved Study-Trail pins).", [
        q("ids", IDS, "Comma-separated line ids (at most 300 are read).", True)],
        [("/api/lines", {"ids": ["1,2,3"]})], []),
    "/api/verify": ("Verify", "Is this quotation really in the Granth? Returns a verdict, confidence and the matched line.", [
        q("q", {"type": "string", "minLength": 1, "maxLength": serve.MAX_CLAIM_CHARS}, "The quotation to verify.", True),
        q("ang", dict(INT, minimum=1, maximum=1430), "Claimed Ang, checked against the match.")],
        [("/api/verify", {"q": ["ਸੋਚੈ ਸੋਚਿ ਨ ਹੋਵਈ ਜੇ ਸੋਚੀ ਲਖ ਵਾਰ"], "ang": ["1"]}),
         ("/api/verify", {"q": ["ਨਾਨਕ ਸੋਨੇ ਦੀ ਚਿੜੀਆ ਉਡ ਗਈ"]})], []),
    "/api/word": ("Search", "Occurrences of one Gurmukhi word.", [
        q("w", STR, "The word.", True)],
        [("/api/word", {"w": ["ਸਚੁ"]})], []),
    "/api/themes/network": ("Insights", "Theme co-occurrence network (PPMI + Jaccard).", [
        q("concept", STR, "Restrict to one concept's edges."),
        q("min_ppmi", {"type": "number", "minimum": 0, "default": 0}, "Minimum PPMI (finite)."),
        q("limit", dict(INT, minimum=1, maximum=2000, default=200), "Maximum edges.")],
        [("/api/themes/network", {}), ("/api/themes/network", {"min_ppmi": ["0.7"], "limit": ["40"]})], []),
    "/api/analytics/author": ("Insights", "Author stylometry list, or one author's profile (radar fingerprint + distinctive terms).", [
        q("author", STR, "Author name; omit for the list."),
        q("full", {"type": "string", "enum": ["1"]}, "Return every concept axis (radar) instead of the top 12.")],
        [("/api/analytics/author", {}), ("/api/analytics/author", {"author": ["Guru Arjan Dev Ji (M5)"], "full": ["1"]})], []),
    "/api/analytics/raag": ("Insights", "Raag analytics list, or one raag's profile.", [
        q("raag", STR, "Raag name; omit for the list.")],
        [("/api/analytics/raag", {})], []),
    "/api/analytics/progression": ("Insights", "Theme progression through one raag (binned).", [
        q("raag", STR, "Raag name.", True),
        q("bins", dict(INT, minimum=8, maximum=80, default=36), "Number of bins."),
        q("top", dict(INT, minimum=2, maximum=10, default=7), "Themes per bin.")],
        [("/api/analytics/progression", {"raag": ["ਆਸਾ"]})], []),
    "/api/analytics/resonance": ("Insights", "Author resonance chord (semantic-neighbour lift between authors).", [
        q("min_lines", dict(INT, minimum=1, default=250), "Minimum lines per author."),
        q("min_lift", {"type": "number", "minimum": 0, "default": 1.0}, "Minimum lift (finite)."),
        q("min_edges", dict(INT, minimum=1, default=8), "Minimum edges per pair.")],
        [("/api/analytics/resonance", {})], []),
    "/api/analytics/vaars": ("Insights", "The 22 Vaars.", [], [("/api/analytics/vaars", {})], []),
    "/api/analytics/vaar": ("Insights", "One Vaar's anatomy (pauris and saloks, attributed).", [
        q("id", dict(INT, minimum=0, maximum=ID_MAX), "Vaar id.", True)],
        [("/api/analytics/vaar", {"id": ["1"]})], []),
    "/api/analytics/constellation": ("Insights", "Concept constellation: verses carrying a concept, clustered by co-concept.", [
        q("concept", STR, "Concept key.", True),
        q("author", STR, "Only verses by this author."),
        q("raag", STR, "Only verses in this raag.")],
        [("/api/analytics/constellation", {"concept": ["naam"]})], []),
    "/api/related": ("Insights", "Related compositions (theme-profile cosine).", [
        q("comp_id", dict(INT, minimum=0, maximum=ID_MAX), "Composition id.", True)],
        [("/api/related", {"comp_id": ["2"]})], []),
    "/api/line_concepts": ("Insights", "Concepts carried by each line (Study Trail).", [
        q("ids", IDS, "Comma-separated line ids (at most 300 are read).", True)],
        [("/api/line_concepts", {"ids": ["10,11,12"]})], []),
    "/api/neighbors": ("Insights", "Semantic neighbours of a line (exact sparse cosine; relatedness bands in the UI).", [
        q("line_id", dict(INT, minimum=0, maximum=ID_MAX), "Line id.", True),
        q("limit", dict(INT, minimum=1, maximum=50, default=10), "Maximum neighbours.")],
        [("/api/neighbors", {"line_id": ["100"]})], []),
    "/api/timing/clock": ("Knowledge", "Raag-timing claims on the pahar clock (attributed claims, never facts).", [],
                          [("/api/timing/clock", {})], []),
    "/api/timing/raag": ("Knowledge", "Timing claims for one raag, with sources.", [
        q("name", STR, "Raag name, Gurmukhi or romanised.", True)],
        [("/api/timing/raag", {"name": ["todi"]})], []),
    "/api/timing/divergence": ("Knowledge", "Raags whose sources disagree on timing (divergence preserved, never adjudicated).", [],
                               [("/api/timing/divergence", {})], []),
    "/api/forms": ("Knowledge", "Structural, poetic and musical form metadata for one composition.", [
        q("comp_id", dict(INT, minimum=0, maximum=ID_MAX), "Composition id.", True)],
        [("/api/forms", {"comp_id": ["2"]})], []),
    "/api/banis": ("Nitnem", "The Nitnem / Gutka bani registry.", [], [("/api/banis", {})], []),
    "/api/bani/{key}": ("Nitnem", "One bani's lines (SGGS lines by pointer, cited by Ang; labelled extra layer).", [
        p("key", {"type": "string", "pattern": "^[a-z0-9_]+$"}, "Bani key."),
        q("variant", STR, "Named variant; omit for the default form.")],
        [("/api/bani/japji", {})], ["404"]),
}

ERROR = {"type": "object", "required": ["error"], "properties": {"error": {"type": "string"}}}


# ----------------------------------------------------------------------------- schema inference
def _merge(a, b):
    if a == b:
        return a
    ta, tb = a.get("type"), b.get("type")
    if ta == tb == "object" and "properties" in a and "properties" in b:
        props = dict(a["properties"])
        for k, v in b["properties"].items():
            props[k] = _merge(props[k], v) if k in props else v
        req = sorted(set(a.get("required", [])) & set(b.get("required", [])))
        return {"type": "object", "properties": props, "required": req}
    if ta == tb == "object" and "additionalProperties" in a and "additionalProperties" in b:
        return {"type": "object", "additionalProperties": _merge(a["additionalProperties"], b["additionalProperties"])}
    if ta == tb == "array":
        return {"type": "array", "items": _merge(a.get("items", {}), b.get("items", {}))}
    if {ta, tb} == {"integer", "number"}:
        return {"type": "number"}
    variants = []
    for s in (a.get("anyOf") or [a]) + (b.get("anyOf") or [b]):
        if s and s not in variants:
            variants.append(s)
    return {"anyOf": sorted(variants, key=lambda s: json.dumps(s, sort_keys=True))} if len(variants) > 1 else variants[0]


def infer(v, depth=0):
    if v is None:
        return {"type": "null"}
    if isinstance(v, bool):
        return {"type": "boolean"}
    if isinstance(v, int):
        return {"type": "integer"}
    if isinstance(v, float):
        return {"type": "number"}
    if isinstance(v, str):
        return {"type": "string"}
    if depth >= 5:
        return {}
    if isinstance(v, (list, tuple)):
        items = {}
        for x in list(v)[:60]:
            s = infer(x, depth + 1)
            items = _merge(items, s) if items else s
        return {"type": "array", "items": items}
    if isinstance(v, dict):
        keys = list(v)
        data_keyed = len(keys) > 30 or any(not str(k).isascii() or str(k)[:1].isdigit() for k in keys)
        if data_keyed:   # a map keyed by data (raag names, ids): describe its values, not its keys
            vals = {}
            for x in list(v.values())[:60]:
                s = infer(x, depth + 1)
                vals = _merge(vals, s) if vals else s
            return {"type": "object", "additionalProperties": vals or {}}
        return {"type": "object", "properties": {str(k): infer(v[k], depth + 1) for k in keys},
                "required": sorted(str(k) for k in keys)}
    return {}


def response_schema(samples):
    schema = {}
    for path, qs in samples:
        if path == "/api/random":   # same payload as the route, but seeded so the spec is reproducible
            raw = serve.hukam_package(seed=qs["_seed"])
        else:
            raw = serve.api(path, qs)
        body = json.loads(json.dumps(raw, ensure_ascii=False))
        s = infer(body)
        schema = _merge(schema, s) if schema else s
    return schema


# ----------------------------------------------------------------------------- document
def build():
    paths = {}
    for route, (tag, summary, params, samples, errors) in ROUTES.items():
        responses = {
            "200": {"description": "OK", "content": {"application/json": {"schema": response_schema(samples)}}},
            "400": {"description": "Invalid request (bad or out-of-range parameter).",
                    "content": {"application/json": {"schema": {"$ref": "#/components/schemas/Error"}}}},
            "500": {"description": "Internal error (generic body; details are logged, never returned).",
                    "content": {"application/json": {"schema": {"$ref": "#/components/schemas/Error"}}}},
        }
        if "404" in errors:
            responses["404"] = {"description": "Not found.",
                                "content": {"application/json": {"schema": {"$ref": "#/components/schemas/Error"}}}}
        op_id = route.strip("/").replace("api/", "").replace("/", "_").replace("{", "").replace("}", "")
        paths[route] = {"get": {"operationId": op_id, "tags": [tag], "summary": summary,
                                "parameters": params, "responses": dict(sorted(responses.items()))}}
    return {
        "openapi": "3.1.0",
        "info": {
            "title": "Sri Guru Granth Sahib Ji — Knowledge Base API",
            "version": API_CONTRACT_VERSION,   # the API contract, not the app build (APP_VERSION)
            "description": ("Read-only API over the verbatim Sri Guru Granth Sahib Ji corpus (60,658 lines, 1,430 Angs). "
                            "Gurmukhi is served exactly as it appears in the source; English is a separate, labelled "
                            "translation layer. Every scripture citation is \"Sri Guru Granth Sahib Ji · Ang N\". "
                            "Generated by tools/gen_openapi.py; response schemas are inferred from real responses."),
        },
        "servers": [{"url": "/", "description": "Same origin as the web app (the gateway routes /api/*)."}],
        "security": [],   # public, read-only API: no authentication by design
        "tags": [
            {"name": "Meta", "description": "Build identity, corpus statistics and the integrity self-test."},
            {"name": "Scripture", "description": "Verbatim lines by Ang, composition, id, or a random complete unit."},
            {"name": "Search", "description": "Ranked search across Gurmukhi, romanised Gurmukhi and the English layer."},
            {"name": "Verify", "description": "Quotation verification against the verbatim corpus."},
            {"name": "Insights", "description": "Precomputed analytics: themes, authors, raags, Vaars, semantic neighbours."},
            {"name": "Knowledge", "description": "Attributed raag-timing claims and composition form metadata."},
            {"name": "Nitnem", "description": "The Nitnem / Gutka bani registry (SGGS lines by pointer, cited by Ang)."},
        ],
        "paths": paths,
        "components": {"schemas": {"Error": ERROR}},
    }


def render():
    return json.dumps(build(), ensure_ascii=False, indent=1) + "\n"


def main(argv):
    text = render()
    if "--check" in argv:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != text:
            print("contract/openapi.json is stale — run: python3 tools/gen_openapi.py")
            return 1
        print("contract/openapi.json is current")
        return 0
    OUT.write_text(text, encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)} ({len(ROUTES)} routes)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
