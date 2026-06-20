/* ============================================================================
   saroop.ts — optional, DISPLAY-ONLY "traditional saroop" rendering toggle.
   ----------------------------------------------------------------------------
   The bundled Sant Lipi font renders the traditional tucked addha/half-yayya
   only when the text run carries its Variation-Selector markup. This module
   injects that markup into the *rendered* Gurmukhi glyphs ONLY. It never mutates
   the stored corpus, the DB, the API payloads, full-text search, or the explicit
   "Copy verse" action (which copies from the data model, not the DOM). A copy
   interceptor strips the selectors from any text the user selects, so the
   clipboard always carries verbatim Unicode. Default OFF; opt-in via the header
   toggle (ਯ), persisted in localStorage. Scripture bytes are never touched.

   Transform rule (Sant Lipi spec): a subjoined-ya run  ੍ਯ  — single, and the
   source-faithful doubled  ੍ਯ੍ਯ  — becomes  VS1 + ਯ  (one tucked addha-yayya).
   A yayya immediately followed by a sihari ਿ is LEFT PLAIN (Sant Lipi cannot
   shape that combination). Pairin haha/rara/vava, ੴ and all else are untouched.
   ============================================================================ */

const VIRAMA = 0x0a4d, YA = 0x0a2f, VS1 = 0xfe00, SIHARI = 0x0a3f;
const VS_LO = 0xfe00, VS_HI = 0xfe0f;                 // Variation Selectors 1–16
const KEY = 'sggs_saroop';
const SUBJOINED_YA = '੍ਯ';                            // ੍ + ਯ

/** Collapse subjoined-ya runs to Sant Lipi's half-yayya markup. Pure; display only. */
export function toTraditional(s: string): string {
  if (s.indexOf(SUBJOINED_YA) === -1) return s;               // fast path: nothing to do
  const cp = Array.from(s, c => c.codePointAt(0) as number);
  const n = cp.length; const out: string[] = []; let i = 0;
  while (i < n) {
    if (cp[i] === VIRAMA && i + 1 < n && cp[i + 1] === YA) {
      let j = i;                                              // consume the whole (virama+ya)+ run
      while (j + 1 < n && cp[j] === VIRAMA && cp[j + 1] === YA) j += 2;
      if (j < n && cp[j] === SIHARI) {                        // sihari-on-yayya → unsupported, leave plain
        for (let k = i; k < j; k++) out.push(String.fromCodePoint(cp[k]));
      } else {
        out.push(String.fromCodePoint(VS1), String.fromCodePoint(YA));
      }
      i = j;
    } else { out.push(String.fromCodePoint(cp[i])); i++; }
  }
  return out.join('');
}

const isVS = (c: number) => c >= VS_LO && c <= VS_HI;
const hasVS = (s: string) => { for (let k = 0; k < s.length; k++) if (isVS(s.charCodeAt(k))) return true; return false; };
const stripVS = (s: string) => { let o = ''; for (const ch of s) if (!isVS(ch.codePointAt(0) as number)) o += ch; return o; };

// Default ON — the Granth shows the traditional saroop unless the reader turns it off.
let ON = true;
try { if (localStorage.getItem(KEY) === '0') ON = false; } catch {}

const orig = new WeakMap<Text, string>();                     // text node → verbatim original
let busy = false;                                             // re-entrancy guard for the observer

function gmRoots(root: ParentNode | HTMLElement): HTMLElement[] {
  const list: HTMLElement[] = [];
  const el = root as HTMLElement;
  if (el.matches && el.matches('.gm')) list.push(el);
  if ((root as ParentNode).querySelectorAll)
    (root as ParentNode).querySelectorAll<HTMLElement>('.gm').forEach(e => list.push(e));
  return list;
}

/** Transform (on) or restore (off) the text nodes inside every .gm under root. */
function paint(root: ParentNode | HTMLElement, on: boolean): void {
  for (const el of gmRoots(root)) {
    const tw = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
    let node: Node | null;
    while ((node = tw.nextNode())) {
      const tn = node as Text;
      let base = orig.get(tn);
      if (base === undefined) { base = tn.nodeValue || ''; orig.set(tn, base); }
      const next = on ? toTraditional(base) : base;
      if (tn.nodeValue !== next) tn.nodeValue = next;
    }
  }
}

/** Reconstruct verbatim Unicode for a selection: a wholly-selected transformed .gm text
    node is restored byte-for-byte from its stored original; partial selections at least
    drop the display-only selectors. Keeps copied sacred text verbatim. */
function verbatimSelection(sel: Selection): string {
  const parts: string[] = [];
  for (let i = 0; i < sel.rangeCount; i++) {
    const range = sel.getRangeAt(i);
    const anc = range.commonAncestorContainer;
    const nodes: Text[] = [];
    if (anc.nodeType === 3) nodes.push(anc as Text);
    else {
      const tw = document.createTreeWalker(anc, NodeFilter.SHOW_TEXT);
      let n: Node | null;
      while ((n = tw.nextNode())) if (range.intersectsNode(n)) nodes.push(n as Text);
    }
    for (const node of nodes) {
      const v = node.nodeValue || '';
      const a = node === range.startContainer ? range.startOffset : 0;
      const b = node === range.endContainer ? range.endOffset : v.length;
      const base = orig.get(node);
      parts.push(base !== undefined && a === 0 && b === v.length ? base : stripVS(v.slice(a, b)));
    }
  }
  return parts.join('');
}

function reflect(): void {
  document.documentElement.classList.toggle('saroop-on', ON);
  const b = document.getElementById('saroopBtn');
  if (b) { b.classList.toggle('on', ON); b.setAttribute('aria-pressed', ON ? 'true' : 'false'); }
  busy = true; paint(document, ON); busy = false;
}
function setSaroop(on: boolean): void {
  ON = on;
  try { localStorage.setItem(KEY, on ? '1' : '0'); } catch {}   // record the reader's explicit choice
  reflect();
}

function init(): void {
  const b = document.getElementById('saroopBtn');
  if (b) b.addEventListener('click', () => setSaroop(!ON));
  reflect();   // apply the initial (default-on) saroop state without persisting until the reader chooses

  // Re-apply to scripture rendered after load (search results, reader pages, trail, modal…).
  const target = document.getElementById('main') || document.body;
  const mo = new MutationObserver(muts => {
    if (!ON || busy) return;
    busy = true;
    for (const m of muts)
      for (const added of Array.from(m.addedNodes))
        if (added.nodeType === 1) paint(added as HTMLElement, true);
    busy = false;
  });
  mo.observe(target, { childList: true, subtree: true });

  // Clipboard safety: any copied scripture comes out as verbatim Unicode — the display-only
  // selectors are removed and wholly-selected verses are restored byte-for-byte from the original.
  document.addEventListener('copy', e => {
    if (!ON) return;
    const sel = document.getSelection();
    if (!sel || sel.isCollapsed || !sel.rangeCount || !hasVS(sel.toString())) return;
    (e as ClipboardEvent).clipboardData?.setData('text/plain', verbatimSelection(sel));
    e.preventDefault();
  });
}

if (document.readyState !== 'loading') init();
else document.addEventListener('DOMContentLoaded', init);
