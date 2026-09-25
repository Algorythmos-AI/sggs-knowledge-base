// <sggs-quiz>: self-check questions. Pick an answer, learn why, move on; nothing leaves the page.
import { el } from './api';

type Answer = { text: string; right: boolean; why: string };
type Question = { q: string; answers: Answer[] };

export class SggsQuiz extends HTMLElement {
  connectedCallback() {
    const json = this.querySelector<HTMLScriptElement>('script.quiz__data');
    let qs: Question[] = [];
    try { qs = JSON.parse(json?.textContent || '[]'); } catch { qs = []; }
    if (!qs.length) return;
    const list = el('ol', { class: 'quiz' });
    let score = 0, answered = 0;
    const summary = el('p', { class: 'quiz__summary', role: 'status', 'aria-live': 'polite' }, [`${qs.length} questions — pick an answer to check yourself.`]);
    qs.forEach((q, qi) => {
      const item = el('li', { class: 'quiz__q' });
      const name = `quiz-${Math.random().toString(36).slice(2, 8)}-${qi}`;
      const fs = el('fieldset', { class: 'quiz__fs' });
      fs.append(el('legend', { class: 'quiz__legend' }, [q.q]));
      const why = el('p', { class: 'quiz__why', role: 'status', 'aria-live': 'polite' });
      let done = false;
      q.answers.forEach((a, ai) => {
        const id = `${name}-${ai}`;
        const input = el('input', { type: 'radio', name, id, value: String(ai) }) as HTMLInputElement;
        const label = el('label', { for: id, class: 'quiz__a' }, [a.text]);
        input.addEventListener('change', () => {
          if (done) return; done = true; answered++;
          if (a.right) { score++; label.classList.add('is-right'); why.textContent = `Right. ${a.why}`.trim(); }
          else { label.classList.add('is-wrong'); const r = q.answers.find((x) => x.right)!; why.textContent = `Not quite — ${r.text}. ${r.why}`.trim(); }
          fs.querySelectorAll('input').forEach((i) => { (i as HTMLInputElement).disabled = true; });
          fs.querySelectorAll('label').forEach((l, li) => { if (q.answers[li].right) l.classList.add('is-answer'); });
          summary.textContent = answered === qs.length ? `${score} of ${qs.length} right.` : `${answered} of ${qs.length} answered · ${score} right so far.`;
        });
        fs.append(el('div', { class: 'quiz__row' }, [input, label]));
      });
      item.append(fs, why); list.append(item);
    });
    this.replaceChildren(summary, list);
  }
}
