-- Migration 001: raag-timing knowledge layer + bani-forms metadata.
-- ADDITIVE ONLY. Every statement is CREATE TABLE / CREATE INDEX on a NEW
-- table; apply_migration.py enforces this with a whitelist before executing.
-- Raag timing is modeled as ATTRIBUTED CLAIMS, never facts: divergent
-- traditions coexist as rows, each citing a source.
--
-- Raag key: raags(name) is the table's TEXT (Gurmukhi) PRIMARY KEY — the DB
-- has no integer raag id, and existing tables are never ALTERed.

CREATE TABLE timing_sources (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,          -- e.g. 'SikhRoots', 'Sikh Philosophy Network chart'
  tradition TEXT NOT NULL CHECK (tradition IN ('gurmat_sangeet','hindustani')),
  url TEXT,
  notes TEXT
);

CREATE TABLE raag_timing_claims (
  id INTEGER PRIMARY KEY,
  raag_name TEXT NOT NULL REFERENCES raags(name),
  claim_type TEXT NOT NULL CHECK (claim_type IN ('primary','variant','seasonal','ceremonial')),
  pahar INTEGER CHECK (pahar BETWEEN 1 AND 8),  -- 1 = 6-9 AM ... 8 = 3-6 AM; NULL for seasonal/ceremonial
  time_start TEXT,                              -- 'HH:MM' fixed-clock rendering
  time_end TEXT,
  season TEXT,                                  -- e.g. 'Chet-Vaisakh (spring)'
  occasion TEXT,                                -- e.g. 'Anand Karaj', 'Rehras/So Dar'
  source_id INTEGER NOT NULL REFERENCES timing_sources(id),
  confidence TEXT NOT NULL CHECK (confidence IN ('consistent','majority','disputed')),
  notes TEXT
);

-- SQLite UNIQUE treats NULLs as distinct; COALESCE makes INSERT OR IGNORE
-- idempotent for claims with NULL pahar/occasion (seasonal, ceremonial).
CREATE UNIQUE INDEX ux_timing_claim ON raag_timing_claims (
  raag_name, claim_type, source_id, COALESCE(pahar, 0), COALESCE(occasion, '')
);
CREATE INDEX ix_timing_claims_raag ON raag_timing_claims (raag_name);

-- Derived, materialized shabd->raag junction (source: read-only SELECTs over
-- lines grouped by comp_id; comp_id is not unique in lines so no formal FK —
-- integrity is enforced by the derivation script + guard test).
CREATE TABLE shabd_raag_map (
  comp_id INTEGER PRIMARY KEY,
  raag_name TEXT REFERENCES raags(name),        -- NULL for pre/post-raag sections
  first_ang INTEGER,
  first_line_id INTEGER
);
CREATE INDEX ix_shabd_raag ON shabd_raag_map (raag_name);

-- Bani composition forms: three independent, cross-cutting dimensions keyed
-- by comp_id. Populated ONLY from headings already present in the verified
-- text; unknown labels stay NULL with the raw label kept in source_label.
CREATE TABLE shabd_musical_markers (
  comp_id INTEGER PRIMARY KEY,
  ghar INTEGER CHECK (ghar BETWEEN 1 AND 17),
  partaal INTEGER NOT NULL DEFAULT 0 CHECK (partaal IN (0,1)),
  has_rahao INTEGER NOT NULL DEFAULT 0 CHECK (has_rahao IN (0,1)),
  has_rahao_dooja INTEGER NOT NULL DEFAULT 0 CHECK (has_rahao_dooja IN (0,1)),
  dhunni TEXT,                                  -- Vaar dhunni header, verbatim
  jati TEXT,                                    -- e.g. 'dakhni' when the heading states it
  source_label TEXT                             -- raw heading/comp_type evidence
);

CREATE TABLE shabd_structural_form (
  comp_id INTEGER PRIMARY KEY,
  form TEXT CHECK (form IN ('pada','ashtpadi','solahe','chhant','vaar','pauri','salok')),
  pada_count INTEGER,
  source_label TEXT
);

-- No 'lavan' genre: the word never appears in a heading, only in verse text,
-- and forms are derived from headings alone. Lavan lives as the ceremonial
-- timing claim (Soohee -> Anand Karaj).
CREATE TABLE shabd_poetic_genre (
  comp_id INTEGER PRIMARY KEY,
  genre TEXT CHECK (genre IN (
    'barah_maha','patti','bavan_akhri','thitti','ruti','din_raini','pahare',
    'alahunian','ghorian','karhale','vanjara','kuchaji','suchaji','gunvanti',
    'sadd','anjulian','birhare','gatha','funhe','chaubole','savaiye','dakhne',
    'mundavani')),
  source_label TEXT
);

CREATE TABLE timing_migrations (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  applied_at TEXT NOT NULL,
  baseline_verified INTEGER NOT NULL CHECK (baseline_verified IN (0,1))
);
