// Poster 13 — Angs 1–1430 as one bar: the opening banis, the 31 raags in order, the closing sections;
// the 22 Vaars marked; the voices. Every number is read from the pinned database (/api/meta,
// /api/analytics/vaars) — the spans are the raags and sections tables' first_ang..last_ang.
const V = { version: '1.3.9', date: '2026-09-25', commit: 'a5d8d5e0' };
// [seq, roman name, first Ang, last Ang, shabads]
const RAAGS = [
  [1, 'Sireeraag', 14, 93, 208], [2, 'Maajh', 94, 150, 177], [3, 'Gaurhee', 151, 346, 740], [4, 'Aasaa', 347, 488, 448], [5, 'Goojaree', 489, 526, 194],
  [6, 'Devagandhaaree', 527, 536, 47], [7, 'Bihaagarhaa', 537, 556, 79], [8, 'Vadahans', 557, 594, 119], [9, 'Sorath', 595, 659, 243], [10, 'Dhanaasaree', 660, 695, 105],
  [11, 'Jaitasaree', 696, 710, 75], [12, 'Todee', 711, 718, 33], [13, 'Bairaarhee', 719, 720, 7], [14, 'Tilang', 721, 727, 19], [15, 'Soohee', 728, 794, 207],
  [16, 'Bilaaval', 795, 858, 230], [17, 'Gond', 859, 875, 49], [18, 'Raamakalee', 876, 974, 270], [19, 'Nat', 975, 983, 25], [20, 'Maalee Gaurhaa', 984, 988, 15],
  [21, 'Maaroo', 989, 1106, 311], [22, 'Tukhaaree', 1107, 1117, 11], [23, 'Kedaaraa', 1118, 1124, 20], [24, 'Bhairau', 1125, 1167, 105], [25, 'Basant', 1168, 1196, 81],
  [26, 'Saarang', 1197, 1253, 282], [27, 'Malaar', 1254, 1293, 161], [28, 'Kaanarhaa', 1294, 1318, 115], [29, 'Kaliaan', 1319, 1327, 24], [30, 'Prabhaatee', 1328, 1351, 65], [31, 'Jaijaavantee', 1352, 1353, 4],
];
// the 22 Vaars: first Ang of each (raag, first, last)
const VAARS = [[83, 91], [137, 150], [300, 317], [318, 323], [462, 475], [508, 517], [517, 524], [548, 556], [585, 594], [642, 653], [705, 710], [785, 792], [849, 855], [947, 956], [957, 966], [966, 968], [1086, 1094], [1094, 1102], [1193, 1193], [1237, 1251], [1278, 1291], [1312, 1318]];
const X0 = 60, X1 = 1540, ANGS = 1430;
const ax = (ang) => X0 + ((ang - 1) / ANGS) * (X1 - X0);
const BAR_Y = 250, BAR_H = 70;

const nodes = [];
const edges = [];
// the opening (1–13) and closing (1353–1430) sections
nodes.push({ id: 'open', kind: 'actor', x: ax(1), y: BAR_Y, w: ax(14) - ax(1), h: BAR_H, lines: [''], title: 'Opening banis · Angs 1–13', step: 'step-02' });
nodes.push({ id: 'close', kind: 'store', x: ax(1354), y: BAR_Y, w: ax(1431) - ax(1354), h: BAR_H, lines: [''], title: 'After the raags · Angs 1353–1430', step: 'step-04' });
// the 31 raags, alternating fills for legibility
RAAGS.forEach(([seq, name, a, b]) => {
  nodes.push({ id: `r${seq}`, kind: seq % 2 ? 'box' : 'note', x: ax(a), y: BAR_Y, w: Math.max(2, ax(b + 1) - ax(a)), h: BAR_H, lines: [''], title: `${seq} · ${name} · Angs ${a}–${b}`, step: 'step-03' });
});
// callouts for the eight largest raags (by Ang span), staggered above the bar
const big = [...RAAGS].sort((p, q) => (q[3] - q[2]) - (p[3] - p[2])).slice(0, 8).sort((p, q) => p[2] - q[2]);
big.forEach(([seq, name, a, b, n], i) => {
  const cx = (ax(a) + ax(b + 1)) / 2, w = 190;
  const x = Math.min(X1 - w, Math.max(X0, cx - w / 2)), y = i % 2 ? 130 : 180;
  nodes.push({ id: `c${seq}`, kind: 'note', x, y, w, h: 42, lines: [{ text: `${name} ${a}–${b}`, size: 16 }], step: 'step-03' });
  edges.push({ from: `c${seq}`, to: `r${seq}`, step: 'step-03', width: 1.5, arrow: false });
});
// the Vaars as ticks under the bar
VAARS.forEach(([a, b], i) => {
  nodes.push({ id: `v${i + 1}`, kind: 'gate', x: ax(a), y: BAR_Y + BAR_H + 14, w: Math.max(3, ax(b + 1) - ax(a)), h: 12, lines: [''], title: `Vaar ${i + 1} · Angs ${a}–${b}`, step: 'step-05' });
});
export default {
  number: '13', slug: 'structure-of-the-granth',
  title: 'The structure of the Granth',
  subtitle: 'Angs 1 to 1430 as one bar — the opening banis, the thirty-one raags in their printed order, the closing sections; the twenty-two Vaars marked; the voices',
  description: 'Sri Guru Granth Sahib Ji opens with Japji Sahib, So Dar, So Purakh and Sohila on Angs 1–13, is ordered by thirty-one raags from Sireeraag on Ang 14 to Jaijaavantee on Ang 1353, and closes with the Sahaskriti saloks, Gatha, Phunhe, Chaubole, the Bhatts’ Swaiyye, the saloks beyond the Vaars, Guru Tegh Bahadur Ji’s saloks, Mundavani and Raagmala on Angs 1353–1430. Twenty-two Vaars sit inside the raags. Six Gurus, fifteen Bhagats, eleven Bhatts and three others wrote it; 60,658 lines in 4,527 compositions.',
  height: 940, verified: V,
  sources: ['webapp/sggs/reader.py', 'webapp/sggs/insights.py', 'docs/scripture/structure.md'],
  legend: ['actor', 'box', 'store', 'gate'],
  groups: [],
  nodes: [
    ...nodes,
    { id: 'ruler0', kind: 'note', x: X0, y: BAR_Y + BAR_H + 44, w: 90, h: 30, lines: [{ text: 'Ang 1', size: 16 }], step: 'step-01' },
    { id: 'ruler14', kind: 'note', x: ax(14) - 45, y: BAR_Y + BAR_H + 78, w: 90, h: 30, lines: [{ text: 'Ang 14', size: 16 }], step: 'step-01' },
    { id: 'ruler700', kind: 'note', x: ax(700) - 50, y: BAR_Y + BAR_H + 44, w: 100, h: 30, lines: [{ text: 'Ang 700', size: 16 }], step: 'step-01' },
    { id: 'ruler1353', kind: 'note', x: ax(1353) - 55, y: BAR_Y + BAR_H + 78, w: 110, h: 30, lines: [{ text: 'Ang 1353', size: 16 }], step: 'step-01' },
    { id: 'ruler1430', kind: 'note', x: X1 - 110, y: BAR_Y + BAR_H + 44, w: 110, h: 30, lines: [{ text: 'Ang 1430', size: 16 }], step: 'step-01' },
    { id: 'openlbl', kind: 'note', x: 60, y: 460, w: 460, h: 110, lines: ['Angs 1–13 · the opening', { text: 'Japji Sahib (1–8, 385 lines) · So Dar (8–10)', size: 16 }, { text: 'So Purakh (10–12) · Sohila (12–13)', size: 16 }, { text: 'the Mool Mantar opens Ang 1', size: 16 }], step: 'step-02' },
    { id: 'raaglbl', kind: 'note', x: 560, y: 460, w: 480, h: 110, lines: ['Angs 14–1353 · thirty-one raags', { text: 'Sireeraag first, Jaijaavantee last', size: 16 }, { text: 'a raag’s span: the longest run of Angs', size: 16 }, { text: 'where it is the majority', size: 16 }], step: 'step-03' },
    { id: 'closelbl', kind: 'note', x: 1080, y: 460, w: 480, h: 110, lines: ['Angs 1353–1430 · after the raags', { text: 'Sahaskriti · Gatha · Phunhe · Chaubole', size: 16 }, { text: 'Swaiyye (1385–1409) · saloks beyond the Vaars', size: 16 }, { text: 'Salok M9 · Mundavani · Raagmala', size: 16 }], step: 'step-04' },
    { id: 'vaarlbl', kind: 'note', x: 60, y: 610, w: 460, h: 90, lines: ['22 Vaars, marked under the bar', { text: 'pauris by one Guru (or Satta & Balwand),', size: 16 }, { text: 'saloks interleaved from several', size: 16 }], step: 'step-05' },
    { id: 'voices', kind: 'note', x: 560, y: 610, w: 1000, h: 90, lines: ['The voices · 29 attributed authors', { text: 'six Gurus (M1–M5, M9) · fifteen Bhagats (Kabir Ji, Namdev Ji, Ravidas Ji, Sheikh Farid Ji …)', size: 16 }, { text: 'eleven Bhatts · Satta & Balwand · Bhai Mardana — Japji carries no author line', size: 16 }], step: 'step-06' },
    { id: 'count', kind: 'note', x: 60, y: 740, w: 1500, h: 60, lines: [{ text: '60,658 lines · 4,527 compositions · 1,430 Angs · 31 raags · 13 named sections · 22 Vaars · 54 themes in the concept index — every number read from the pinned database', size: 16 }], step: 'step-06' },
  ],
  edges,
  steps: [
    { id: 'step-01', title: 'One bar, 1,430 Angs', caption: 'The whole scripture drawn to scale: every Ang is the same width, from Ang 1 at the left to Ang 1430 at the right. Hover a segment for its name and span. Every number on this poster comes from the pinned database, the same one the site and the app serve.', link: '/scripture/structure/' },
    { id: 'step-02', title: 'The opening: Angs 1–13', caption: 'The Granth opens with the Mool Mantar and Japji Sahib (Angs 1–8, 385 lines, no author line in the print), then So Dar, So Purakh and Sohila — the evening and night prayers — before the first raag begins on Ang 14.', link: '/scripture/what-sggs-is/' },
    { id: 'step-03', title: 'Thirty-one raags: Angs 14–1353', caption: 'From Ang 14 the hymns are arranged by raag, the musical mode they are sung in — Sireeraag first, Jaijaavantee last on Ang 1353. Inside a raag the compositions follow the Gurus in order, then the Bhagats. A raag’s span in the database is the longest run of Angs where it is the majority, so a liturgical mention elsewhere never drags a raag’s start. Gaurhee, Maaroo and Raamakalee are the largest.', link: '/scripture/structure/' },
    { id: 'step-04', title: 'After the raags: Angs 1353–1430', caption: 'The closing sections leave the raag framework: the Sahaskriti saloks, Gatha, Phunhe and Chaubole (Guru Arjan Dev Ji), the Bhatts’ Swaiyye in praise of the Gurus (1385–1409), the saloks beyond the Vaars, Guru Tegh Bahadur Ji’s saloks, Mundavani — the seal — and Raagmala. The database clears the raag column here and detects these sections from their headings.', link: '/scripture/bhatts-and-swaiyye/' },
    { id: 'step-05', title: 'The twenty-two Vaars', caption: 'Twenty-two Vaars sit inside the raags, marked under the bar: ballads of pauris by one author with saloks interleaved from several Gurus. The pipeline detects them by their title headers, and a Vaar’s pauris keep the Vaar’s author even where the interleaved saloks carry other ਮਃ headers.', link: '/scripture/vaars-saloks-pauris/' },
    { id: 'step-06', title: 'The voices, and the numbers', caption: 'Six Gurus, fifteen Bhagats, eleven Bhatts, Satta and Balwand, and Bhai Mardana: 29 attributed authors, with Japji carrying no author line. 60,658 lines in 4,527 compositions; 13 named sections outside the raags; 54 themes in the concept index. Every figure is read from the database — the structure page lists them all.', link: '/scripture/structure/' },
  ],
};
