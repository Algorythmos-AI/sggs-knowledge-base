// Poster 06 — roman_norm, the one fold that must be byte-identical in three repositories.
const V = { version: '1.3.9', date: '2026-09-25', commit: '7a343c62' };
export default {
  number: '06', slug: 'the-fold-in-three-places',
  title: 'The fold in three places',
  subtitle: 'roman_norm turns many spellings into one key — and it lives in three repositories that 24,719 golden vectors hold byte-identical',
  description: 'Seekers spell the same word many ways. roman_norm folds a Roman word in five steps — letter substitutions, digraphs, voicing pairs, the y glide, vowels dropped and doubles collapsed — into a key such as vhgr. The data repository applies it when it builds the translit_norm column; the platform applies it at query time in search and verification; the iOS app carries a Swift port. The contract file golden_roman_norm.ndjson records 24,719 input and output pairs generated from the platform, and every repository asserts against it.',
  height: 960, verified: V,
  sources: ['webapp/romannorm.py', 'contract/golden_roman_norm.ndjson', 'tools/gen_golden_vectors.py', 'contract/_meta.json'],
  legend: ['box', 'store', 'pin', 'good'],
  groups: [
    { label: 'One fold, five steps (webapp/romannorm.py)', x: 40, y: 150, w: 700, h: 560 },
    { label: 'Three homes, one contract', x: 790, y: 150, w: 770, h: 560 },
  ],
  nodes: [
    { id: 'in', kind: 'box', x: 60, y: 200, w: 660, h: 70, lines: ['Many spellings, one word', { text: 'waheguru · vaahiguroo · wahegurooh → the same key', size: 16 }], step: 'step-01' },
    { id: 's1', kind: 'box', x: 60, y: 290, w: 320, h: 80, lines: ['1 · substitute letters', { text: 'w→v · z→j · q→k · x→k', size: 16, mono: true }], step: 'step-02' },
    { id: 's2', kind: 'box', x: 400, y: 290, w: 320, h: 80, lines: ['2 · digraphs', { text: 'sh chh ch kh gh jh th dh bh ph rh', size: 16 }, { text: '→ their first letter · f → p', size: 16 }], step: 'step-02' },
    { id: 's3', kind: 'box', x: 60, y: 390, w: 320, h: 80, lines: ['3 · voicing pairs', { text: 'b→v · k→g · t→d · p→v', size: 16, mono: true }], step: 'step-02' },
    { id: 's4', kind: 'box', x: 400, y: 390, w: 320, h: 80, lines: ['4 · the y glide', { text: 'leading y → j · medial y dropped', size: 16 }, { text: 'gyan ~ giaan', size: 16 }], step: 'step-02' },
    { id: 's5', kind: 'box', x: 60, y: 490, w: 660, h: 80, lines: ['5 · vowels and doubles', { text: 'a leading vowel stays; other vowels are dropped; doubled letters collapse', size: 16 }], step: 'step-02' },
    { id: 'out', kind: 'good', x: 60, y: 600, w: 660, h: 80, lines: ['vhgr · jsd · krsn · gn', { text: 'the key the index and the query both use', size: 16 }], step: 'step-02' },
    { id: 'h1', kind: 'box', x: 810, y: 200, w: 730, h: 90, lines: ['Home 1 · sggs-data — build time', { text: 'pipeline/sggs_pipeline.py:roman_norm', size: 16, mono: true }, { text: 'builds lines.translit_norm in the database', size: 16 }], step: 'step-03' },
    { id: 'h2', kind: 'box', x: 810, y: 310, w: 730, h: 90, lines: ['Home 2 · sggs-platform — query time', { text: 'webapp/romannorm.py', size: 16, mono: true }, { text: 'search tier 11 · the verification engine', size: 16 }], step: 'step-04' },
    { id: 'h3', kind: 'box', x: 810, y: 420, w: 730, h: 90, lines: ['Home 3 · gurbani-soul-ios — the port', { text: 'GurbaniSearchKit/RomanNorm.swift', size: 16, mono: true }, { text: 'search and verification on the device', size: 16 }], step: 'step-05' },
    { id: 'pin', kind: 'pin', x: 810, y: 540, w: 730, h: 70, lines: [{ text: 'contract/golden_roman_norm.ndjson', mono: true }, { text: '24,719 input → output pairs, generated from home 2', size: 16 }], step: 'step-05' },
    { id: 'gate', kind: 'good', x: 810, y: 630, w: 730, h: 60, lines: [{ text: 'CI: make contract here · vendor.lock.json sha256 in the app · byte-parity tests', size: 16 }], step: 'step-05' },
    { id: 'why', kind: 'box', x: 40, y: 740, w: 1520, h: 70, lines: ['If the query-time fold ever differs from the fold that built the index, search and verification break silently — no error, just missing lines'], step: 'step-01' },
  ],
  edges: [
    { from: 'in', to: 's1', step: 'step-02' }, { from: 's1', to: 's2', step: 'step-02' }, { from: 's2', to: 's3', step: 'step-02', via: [[560, 380], [220, 380]] },
    { from: 's3', to: 's4', step: 'step-02' }, { from: 's4', to: 's5', step: 'step-02', via: [[560, 480], [390, 480]] }, { from: 's5', to: 'out', step: 'step-02' },
    { from: 'h1', to: 'pin', dashed: true, step: 'step-05', via: [[1555, 245], [1555, 575]] }, { from: 'h2', to: 'pin', dashed: true, label: 'generates', step: 'step-05', via: [[795, 355], [795, 575]], dx: -50 },
    { from: 'h3', to: 'pin', dashed: true, step: 'step-05' }, { from: 'pin', to: 'gate', step: 'step-05' },
  ],
  steps: [
    { id: 'step-01', title: 'The problem', caption: 'Seekers type a Gurmukhi word in Roman letters the way they hear it: waheguru, vaahiguroo, wahegurooh. A search that demanded one spelling would miss most of them. The fold makes every spelling of a word land on one key — and it must be exactly the same fold wherever it runs, or the query key will not match the index key and lines silently go missing.', link: '/search/the-roman-fold/' },
    { id: 'step-02', title: 'Five steps to one key', caption: 'Lower-case each word. Substitute w→v, z→j, q→k, x→k. Reduce the digraphs (sh, chh, ch, kh, gh, jh, th, dh, bh, ph, rh) to their first letter and f to p. Merge the voicing pairs b→v, k→g, t→d, p→v. Turn a leading y into j and drop a medial y. Keep a leading vowel, drop every other vowel, collapse doubled letters. waheguru becomes vhgr; yashoda and jasodaa become jsd; gyan and giaan become gn.', link: '/search/the-roman-fold/' },
    { id: 'step-03', title: 'Home 1: the data repository, at build time', caption: 'sggs-data’s pipeline applies roman_norm to every line’s transliteration and stores the result in the translit_norm column of the lines table. That column is what the fold tier and the verification engine search.', link: '/data/line-record/' },
    { id: 'step-04', title: 'Home 2: the platform, at query time', caption: 'webapp/romannorm.py is the one copy in this repository: serve.py re-exports it and verify.py imports it (verify cannot import serve, which imports verify). Search tier 11 folds the query with it; the verification engine folds a Roman claim with it before scoring.', link: '/search/verification-engine/' },
    { id: 'step-05', title: 'Home 3, and the contract that binds all three', caption: 'The iOS app carries a Swift port, RomanNorm.swift. tools/gen_golden_vectors.py drives the platform’s function and records 24,719 input and output pairs in contract/golden_roman_norm.ndjson; make contract fails here if the file drifts, the app pins the file by sha256 in vendor.lock.json and runs byte-parity tests, and the data repository’s copy is held to the same vectors. Three copies, one truth.', link: '/search/harnesses-and-golden-vectors/' },
  ],
};
