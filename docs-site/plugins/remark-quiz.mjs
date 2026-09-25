// A self-check quiz: `<!-- sggs:quiz -->` followed by a ```quiz fence. Each question is a `Q:` line,
// its answers are list items; the right one ends with ✓ and an optional " — explanation".
// On GitHub the fence reads as plain text (the question, the answers, the tick); on the site the
// fence becomes the interactive <sggs-quiz> with the questions embedded as JSON. No backend.
import { visit } from 'unist-util-visit';

export function parseQuiz(text, where = 'page') {
  const qs = [];
  let cur = null;
  for (const raw of text.split('\n')) {
    const line = raw.trim();
    if (!line) continue;
    if (/^Q:\s*/.test(line)) { cur = { q: line.replace(/^Q:\s*/, ''), answers: [] }; qs.push(cur); continue; }
    const m = /^[-*]\s+(.*)$/.exec(line);
    if (!m || !cur) throw new Error(`${where}: quiz line not understood: "${line}" (Q: … or - answer [✓ — why])`);
    const body = m[1];
    const right = /✓/.test(body);
    const [text_, why = ''] = body.replace(/✓/g, '').split(/\s+—\s+/, 2);
    cur.answers.push({ text: text_.trim(), right, why: why.trim() });
  }
  for (const q of qs) {
    if (q.answers.length < 2) throw new Error(`${where}: quiz question "${q.q}" needs at least two answers`);
    if (q.answers.filter((a) => a.right).length !== 1) throw new Error(`${where}: quiz question "${q.q}" needs exactly one ✓ answer`);
  }
  if (!qs.length) throw new Error(`${where}: quiz has no Q: lines`);
  return qs;
}

export function remarkQuiz() {
  return (tree, file) => {
    visit(tree, 'html', (node, index, parent) => {
      if (!/^<sggs-quiz\b[^>]*>\s*<\/sggs-quiz>$/.test(node.value.trim())) return;
      const next = parent.children[index + 1];
      if (!next || next.type !== 'code' || next.lang !== 'quiz') throw new Error(`${file.path ?? 'page'}: sggs:quiz must be followed by a \`\`\`quiz fence`);
      const qs = parseQuiz(next.value, file.path ?? 'page');
      node.value = `<sggs-quiz><script type="application/json" class="quiz__data">${JSON.stringify(qs).replace(/</g, '\\u003c')}</script></sggs-quiz>`;
      parent.children.splice(index + 1, 1);
      return index + 1;
    });
  };
}
