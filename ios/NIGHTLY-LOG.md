# SGGS iOS — Nightly Build Log

## 2026-06-26 22:13 — disk crisis resolved
- Disk was 100% full (ENOSPC, could not spawn commands). Reclaimed ~23G (uv/npm/Xcode caches). Now 8.7Gi free.
- Resuming Phase 0 preflight.

## 22:19 — Phase A: passage_search
- Ported serve.py passage_search (fts_shabad + NSRegularExpression span over ASCII translit_norm + bubble).
- golden_search +4 vectors (1 resolves passage-match, 17 ids). Un-skipped passage in test.
- swift test: all 4 suites GREEN. Whole search waterfall now ported.
