// <sggs-status>: what production is serving right now — version, commit, build date, dataset
// build and the health checks — from /api/health, the same endpoint the deploy pipeline and the
// uptime probe read. Text is built with DOM APIs (no innerHTML of API data).
import { api, el } from './api';

type Health = {
  version?: string; commit?: string; built?: string; db_version?: string; ok?: boolean;
  checks?: Record<string, boolean>;
};

export class SggsStatus extends HTMLElement {
  connectedCallback() {
    this.render(null, true);
    api<Health>('/api/health').then((h) => this.render(h, false));
  }

  private render(h: Health | null, pending: boolean) {
    const chip = (text: string, state?: 'ok' | 'bad') =>
      el('span', { class: `chip${state ? ` chip--${state}` : ''}` }, [el('span', { class: 'chip__dot', 'aria-hidden': 'true' }), text]);
    const row = el('div', { class: `status${pending ? ' status--pending' : ''}`, role: 'status', 'aria-live': 'polite' });
    row.append(el('span', { class: 'status__label' }, ['Production, live:']));
    if (pending) {
      row.append(chip('checking /api/health…'));
    } else if (!h) {
      row.append(chip('live status unavailable right now', 'bad'));
    } else {
      const checks = Object.entries(h.checks ?? {});
      const passing = checks.filter(([, v]) => v === true).length;
      row.append(chip(`v${h.version ?? '?'}`));
      if (h.commit && h.commit !== 'unknown') row.append(chip(`commit ${h.commit.slice(0, 7)}`));
      if (h.built) row.append(chip(`built ${h.built}`));
      if (h.db_version) row.append(chip(`dataset ${h.db_version}`));
      row.append(chip(`${passing}/${checks.length} health checks`, h.ok && passing === checks.length ? 'ok' : 'bad'));
    }
    this.replaceChildren(row);
  }
}
