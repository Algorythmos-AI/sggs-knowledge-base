// Shared pieces of the search, verify and Ang widgets: a verbatim line with its citation, and the
// walkthrough hand-off that lights a poster step.
import { el } from './api';

export type ApiLine = { id: number; ang: number; gurmukhi: string; translit?: string; en?: string | null; author?: string | null; raag?: string | null; comp_id?: number };

/** A result line: verbatim Gurmukhi (lang="pa"), the citation, the transliteration and the English layer, labelled. */
export function lineCard(l: ApiLine, extra: (Node | string)[] = []) {
  const card = el('li', { class: 'line' });
  card.append(
    el('p', { class: 'line__gm', lang: 'pa' }, [l.gurmukhi]),
    el('p', { class: 'line__cite' }, [`Sri Guru Granth Sahib Ji · Ang ${l.ang}`, ...(l.author ? [` · ${l.author}`] : []), ...(l.raag ? [` · ${l.raag}`] : []), ...extra]),
  );
  if (l.translit) card.append(el('p', { class: 'line__tr' }, [l.translit]));
  if (l.en) card.append(el('p', { class: 'line__en' }, [el('span', { class: 'line__label' }, ['English (translation): ']), l.en]));
  return card;
}

/** Light a step on the walkthrough of this poster, if it is on the page. */
export function lightStep(poster: string, stepId: string | null) {
  const wt = document.querySelector<HTMLElement & { goTo?: (id: string) => void; show?: (i: number) => void }>(`sggs-walkthrough[data-poster="${poster}"]`);
  if (!wt) return;
  if (stepId && wt.goTo) wt.goTo(stepId);
  else if (wt.show) wt.show(-1);
}

export const chip = (text: string, cls = '') => el('span', { class: `chip ${cls}`.trim() }, [text]);
