// After a build: every Mermaid fence must have become an inline SVG figure. A leftover
// <pre class="mermaid">, a `language-mermaid` code block or a Mermaid error SVG fails the check.
import { readFileSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';

const dist = process.argv[2] ?? 'dist';
let pages = 0, diagrams = 0, bad = [];
const walk = (d) => {
  for (const n of readdirSync(d)) {
    const p = path.join(d, n);
    if (statSync(p).isDirectory()) walk(p);
    else if (n.endsWith('.html')) {
      pages++;
      const html = readFileSync(p, 'utf8');
      diagrams += (html.match(/data-diagram="mermaid"/g) ?? []).length;
      if (/class="mermaid"|language-mermaid|Syntax error in text|mermaid version/i.test(html)) bad.push(p);
    }
  }
};
walk(dist);
if (bad.length) {
  console.error(`check-mermaid: ${bad.length} page(s) still carry an unrendered or failed diagram:\n  ` + bad.join('\n  '));
  process.exit(1);
}
console.log(`check-mermaid: ${diagrams} diagram(s) rendered across ${pages} page(s), none left as code`);
