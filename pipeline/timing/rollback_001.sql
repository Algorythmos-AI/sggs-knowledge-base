-- Rollback for migration 001: drops ONLY the timing-layer tables.
-- No pre-existing table is named anywhere in this file; apply_migration.py
-- whitelist-checks that every statement is a DROP of a timing-layer table
-- (or the bookkeeping DELETE below) before executing.

DROP TABLE IF EXISTS shabd_poetic_genre;
DROP TABLE IF EXISTS shabd_structural_form;
DROP TABLE IF EXISTS shabd_musical_markers;
DROP TABLE IF EXISTS shabd_raag_map;
DROP TABLE IF EXISTS raag_timing_claims;
DROP TABLE IF EXISTS timing_sources;
DROP TABLE IF EXISTS timing_migrations;
