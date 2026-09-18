-- Rollback 002: drop the bani registry (order respects the FKs).
DROP TABLE IF EXISTS bani_lines;
DROP TABLE IF EXISTS extra_lines;
DROP TABLE IF EXISTS banis;
