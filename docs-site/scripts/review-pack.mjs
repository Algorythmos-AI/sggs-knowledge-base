// The G3 review pack: the pages a Granthi or scholar must read before the scripture banners come
// down — Scripture 101, the glossary's scripture and script sections, the contributors to the
// Granth — as ONE printable PDF with a sign-off sheet. Built from the site as it renders (the cited
// lines are the byte-verified ones), light theme, interactive controls removed.
//   npm run build && node scripts/review-pack.mjs      → review-pack/G3-review-pack-<date>-<sha7>.pdf
import { spawn, execSync } from 'node:child_process';
import { mkdirSync } from 'node:fs';
import { chromium } from 'playwright';

const PAGES = [
  ['/scripture/', null],
  ['/scripture/what-sggs-is/', null],
  ['/scripture/structure/', null],
  ['/scripture/vaars-saloks-pauris/', null],
  ['/scripture/bhatts-and-swaiyye/', null],
  ['/scripture/gurmukhi-and-unicode/', null],
  ['/scripture/transliteration-and-the-fold/', null],
  ['/scripture/answer-protocol-for-engineers/', null],
  ['/glossary/', 'The data'],            // the scripture and script sections only: stop at this heading
  ['/reference/contributors/', null],
];
const port = 4361;
const base = `http://127.0.0.1:${port}`;
let sha = process.env.PUBLIC_DOCS_COMMIT;
try { sha ??= execSync('git rev-parse HEAD').toString().trim(); } catch { sha ??= 'unknown'; }
const date = new Date().toISOString().slice(0, 10);

const server = spawn('node', ['scripts/serve-dist.mjs', String(port)], { stdio: 'ignore' });
try {
  for (let i = 0; i < 60; i++) { try { if ((await fetch(base + '/')).ok) break; } catch { /* starting */ } await new Promise((r) => setTimeout(r, 300)); }
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.addInitScript(() => { try { localStorage.setItem('starlight-theme', 'light'); } catch { /* private */ } });
  await page.route('**/api/**', (r) => (r.request().resourceType() === 'document' ? r.fallback() : r.fulfill({ status: 503, body: '{}' })));
  const sections = [];
  for (const [path, stopAt] of PAGES) {
    const res = await page.goto(base + path, { waitUntil: 'networkidle' });
    if (res?.status() !== 200) throw new Error(`review pack: ${path} answered ${res?.status()} — build the site first`);
    sections.push(await page.evaluate(([p, stop]) => {
      const main = document.querySelector('.sl-markdown-content').cloneNode(true);
      if (stop) {                                   // cut at the first h2 whose text starts with `stop`
        const h = [...main.querySelectorAll('h2')].find((x) => x.textContent.trim().startsWith(stop));
        if (h) { let n = h.closest('.sl-heading-wrapper') ?? h; while (n) { const next = n.nextSibling; n.remove(); n = next; } }
      }
      main.querySelectorAll('.wt__bar, .wt__caption, .wt__list, .quiz button, button, .sl-anchor-link, dialog').forEach((e) => e.remove());
      return { path: p, title: document.querySelector('h1').textContent.trim(), html: main.innerHTML };
    }, [path, stopAt]));
  }
  const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;');
  const signoff = `<section class="rp-sign"><h1>Sign-off (gate G3)</h1>
    <p>For each page: approved as written, or the changes needed. Explanation is labelled as explanation; every
    quoted line is verbatim and cited <em>Sri Guru Granth Sahib Ji · Ang N</em>. Nothing in this pack alters the text.</p>
    <table><thead><tr><th>Page</th><th>Approved</th><th>Changes needed / notes</th></tr></thead><tbody>
    ${sections.map((s) => `<tr><td>${esc(s.title)}<br><small>docs.gurbanisoul.com${esc(s.path)}</small></td><td></td><td></td></tr>`).join('')}
    </tbody></table>
    <p class="rp-lines">Reviewer ____________________________ &nbsp; Role ____________________ &nbsp; Date ____________</p>
    <p class="rp-lines">Signature ____________________________</p></section>`;
  const cover = `<section class="rp-cover"><h1>Engineering wiki — scholar review pack (gate G3)</h1>
    <p>Sri Guru Granth Sahib Ji — Knowledge Base · docs.gurbanisoul.com</p>
    <p>Built ${date} from commit <code>${sha.slice(0, 7)}</code>. ${sections.length} pages, in reading order, then a sign-off sheet.</p>
    <ol>${sections.map((s) => `<li>${esc(s.title)}</li>`).join('')}</ol></section>`;
  const body = cover + sections.map((s) => `<article class="rp-page"><p class="rp-path">docs.gurbanisoul.com${esc(s.path)}</p><h1>${esc(s.title)}</h1><div class="sl-markdown-content">${s.html}</div></article>`).join('') + signoff;
  await page.goto(base + '/404.html', { waitUntil: 'networkidle' });   // any page: it carries the site's CSS and fonts
  await page.evaluate(([html]) => {
    document.body.innerHTML = `<main class="rp">${html}</main>`;
    const st = document.createElement('style');
    st.textContent = `body{background:#fff} .rp{max-width:46rem;margin:0 auto;padding:0 1rem;color:#201a12}
      .rp-cover,.rp-page,.rp-sign{break-after:page} .rp-path{font-size:.8rem;color:#6b6156;margin:0 0 .25rem}
      .rp h1{font-family:var(--sgs-font-serif);margin:.5rem 0 1rem} .rp-sign table{width:100%;border-collapse:collapse}
      .rp-sign td,.rp-sign th{border:1px solid #9a9084;padding:.6rem;vertical-align:top;height:3.2rem}
      .rp-lines{margin-top:2.5rem} .diagram .mmd--dark{display:none!important} .diagram .mmd--light{display:block!important}
      .poster__canvas{border:1px solid #d9d0c2} figure{break-inside:avoid}`;
    document.head.append(st);
  }, [body]);
  mkdirSync('review-pack', { recursive: true });
  const out = `review-pack/G3-review-pack-${date}-${sha.slice(0, 7)}.pdf`;
  await page.pdf({ path: out, format: 'A4', printBackground: true, margin: { top: '18mm', bottom: '18mm', left: '14mm', right: '14mm' },
    displayHeaderFooter: true, headerTemplate: '<span></span>',
    footerTemplate: `<div style="font-size:8px;width:100%;text-align:center;color:#6b6156">G3 review pack · ${sha.slice(0, 7)} · page <span class="pageNumber"></span> of <span class="totalPages"></span></div>` });
  await browser.close();
  console.log(`review-pack: ${sections.length} pages → docs-site/${out}`);
} finally {
  server.kill();
}
