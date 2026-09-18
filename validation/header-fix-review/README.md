# Header-detector fix (v1.1.4) — scholar review pack

Generated 2026-09-18 from `db/sggs.sqlite` before (`883f6f80…`) vs after (`f8135f62…`) the rebuild.
The Gurmukhi of every one of the 60,658 lines is byte-identical; only metadata columns moved.

- `demoted-headers.tsv` — the 233 lines whose `is_header` went 1 → 0 (verses the old detector
  had taken for headings). **Please confirm none of these is a real heading.**
- `all-changed-lines.tsv` — every line whose `is_header`, `comp_id`, `line_no`, `author`,
  `raag`, `section`, `comp_type` or `ghar` changed, with before/after values.

Points needing a scholar's eye:
1. Author changes (232 lines): Baba Sundar → M4/M5 on Angs 240/776/784 (the name matched the
   adjective ਸੁੰਦਰੁ in Guru-authored shabads; no heading in the print names Baba Sundar, so
   he now has no lines — the Sadd at Ang 923 is still carried under its ਰਾਮਕਲੀ ਸਦੁ heading
   as M3, a known mislabel to fix separately); Namdev/Kabir → M5 on Angs 1192/1376; stale
   Vaar-author on Angs 1279 (M1→M3) and 1416–17 (Kabir→M3).
2. Malar Ki Vaar now has 28 pauris / 58 saloks (was 27/56 — a false ਪਟੀ header cut it short).
3. Weak-signal labels kept as headers on purpose: 'ਸੋਲਹ ਅਸਟਪਦੀਆ ਗੁਆਰੇਰੀ ਗਉੜੀ ਕੀਆ ॥' (Ang 228),
   'ਗਉੜੀ ਮਾਲਾ ੫ ॥' (216), 'ਗਉੜੀ ਭੀ ਸੋਰਠਿ ਭੀ ॥' (330), 'ਮਹਲੇ ਪਹਿਲੇ ਸਤਾਰਹ ਅਸਟਪਦੀਆ ॥' (64).
4. Ang 485 id 21936 'ਆਸਾ ਬਾਣੀ ਸ੍ਰੀ ਨਾਮਦੇਉ ਜੀ ਕੀ ਏਕ ਅਨੇਕ ਬਿਆਪਕ …' is a heading and a verse fused
   in one print line — left as a header, unchanged.
