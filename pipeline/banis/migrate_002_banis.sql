-- Migration 002: Nitnem / Gutka bani registry. ADDITIVE ONLY — three NEW tables
-- and two indexes; build_banis.py enforces this with a whitelist before executing.
--
-- Design (ADR-0006):
--   * A bani is an ORDERED LIST of pointers. For Sri Guru Granth Sahib Ji text the
--     pointer is `lines.id` — the rendered text is always OUR verbatim, reconciled
--     corpus. The registry only says WHICH lines, in WHAT order.
--   * Text that is not in Sri Guru Granth Sahib Ji (Sri Dasam Granth banis, Ardaas)
--     lives in `extra_lines`, a SEPARATE, labelled layer. It is never mixed into
--     `lines`, never indexed by FTS, never cited as an Ang, and carries no English.
--   * Rehras Sahib differs by tradition: rows share `key` and differ by `variant`.

CREATE TABLE banis (
  bani_id INTEGER PRIMARY KEY,
  key TEXT NOT NULL,                              -- stable API/deep-link key, ^[a-z0-9_]{1,32}$
  variant TEXT NOT NULL DEFAULT '',               -- '' | 'sgpc' | 'taksal' | 'kirtan'
  is_default INTEGER NOT NULL DEFAULT 1 CHECK (is_default IN (0,1)),
  title_gm TEXT NOT NULL,
  title_en TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN
    ('nitnem_morning','nitnem_evening','nitnem_night','popular','ceremony')),
  order_no INTEGER NOT NULL,
  n_lines INTEGER NOT NULL,
  n_groups INTEGER NOT NULL,
  has_extra INTEGER NOT NULL CHECK (has_extra IN (0,1)),  -- 1 = contains non-SGGS text
  estimated_minutes INTEGER,
  description_en TEXT,
  source_label TEXT NOT NULL,                     -- human-readable provenance
  UNIQUE (key, variant)
);

CREATE TABLE extra_lines (
  extra_id INTEGER PRIMARY KEY,
  source TEXT NOT NULL CHECK (source IN ('dasam','ardaas')),
  panna INTEGER,                                  -- Sri Dasam Granth page; NULL for Ardaas
  gurmukhi TEXT NOT NULL,
  translit TEXT NOT NULL,                         -- reading aid, not text
  is_header INTEGER NOT NULL DEFAULT 0 CHECK (is_header IN (0,1)),
  shabados_line_id TEXT NOT NULL UNIQUE,          -- provenance back to the source dataset
  review_status TEXT NOT NULL DEFAULT 'unreviewed'
    CHECK (review_status IN ('unreviewed','reviewed'))
);

CREATE TABLE bani_lines (
  bani_id INTEGER NOT NULL REFERENCES banis(bani_id),
  seq INTEGER NOT NULL,                           -- 1-based reading order, the ONLY line identity
  line_group INTEGER NOT NULL,                    -- liturgical section (pauri / part), 1-based
  line_id INTEGER REFERENCES lines(id),           -- SGGS pointer (verbatim corpus) …
  extra_id INTEGER REFERENCES extra_lines(extra_id), -- … or non-SGGS pointer, never both
  PRIMARY KEY (bani_id, seq),
  CHECK ((line_id IS NULL) <> (extra_id IS NULL))
);
CREATE INDEX ix_bani_lines_line ON bani_lines (line_id);
CREATE INDEX ix_bani_lines_extra ON bani_lines (extra_id);
