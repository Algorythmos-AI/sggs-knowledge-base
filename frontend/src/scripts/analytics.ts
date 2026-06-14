// analytics.ts — the Insights dashboard (/analytics).
// D3 force-directed theme co-occurrence network + Chart.js author theme-fingerprint radar.
// All data comes from the existing offline analytics endpoints; nothing is computed client-side.
import * as d3 from 'd3';
import Chart from 'chart.js/auto';
import { $, esc, api, meta } from './core';

const titleCase = (k: string) => k.split('_').map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
const cssVar = (n: string) => getComputedStyle(document.documentElement).getPropertyValue(n).trim();

/* ============================ D3 theme network ============================ */
async function themeNetwork() {
  const host = $('#network'); if (!host) return;
  const [m, net] = await Promise.all([meta(), api('themes/network?limit=420')]);
  const size: Record<string, number> = {};
  const desc: Record<string, string> = {};
  (m.concepts || []).forEach((c: any) => { size[c.concept] = c.n_lines || 0; desc[c.concept] = c.description || ''; });

  const edgesAll = (net.edges || []).map((e: any) => ({ source: e.source, target: e.target, ppmi: +e.ppmi, sc: +e.shabad_count }));
  const ppmiMax = d3.max(edgesAll, (d: any) => d.ppmi) || 1;
  const sizeMax = d3.max(Object.values(size)) || 1;

  const accent = cssVar('--accent') || '#ff9933';
  const gold = cssVar('--gold') || '#ffd24a';
  const ink = cssVar('--ink') || '#eef1f8';
  const soft = cssVar('--soft') || '#93a0bd';
  const rNode = (c: string) => 7 + 30 * Math.sqrt((size[c] || 1) / sizeMax);
  const edgeColor = d3.scaleLinear<string>().domain([0, ppmiMax]).range(['#7c5cff55', accent]);

  const W = host.clientWidth || 800, H = 560;
  host.innerHTML = '';
  const svg = d3.select(host).append('svg')
    .attr('viewBox', `0 0 ${W} ${H}`).attr('width', '100%').attr('height', H)
    .style('cursor', 'grab');
  const g = svg.append('g');
  svg.call(d3.zoom<SVGSVGElement, unknown>().scaleExtent([0.3, 4]).on('zoom', (ev) => g.attr('transform', ev.transform)) as any);

  let edges = edgesAll.slice();
  const nodeSet = new Set<string>();
  const build = (minPpmi: number) => {
    edges = edgesAll.filter((e: any) => e.ppmi >= minPpmi);
    nodeSet.clear(); edges.forEach((e: any) => { nodeSet.add(e.source); nodeSet.add(e.target); });
    return Array.from(nodeSet).map((id) => ({ id }));
  };
  let nodes = build(0);

  const tip = d3.select(host).append('div').attr('class', 'viz-tip').style('opacity', 0);
  const linkSel = g.append('g').attr('class', 'links');
  const nodeSel = g.append('g').attr('class', 'nodes');
  const labelSel = g.append('g').attr('class', 'labels');

  const sim = d3.forceSimulation<any>(nodes)
    .force('link', d3.forceLink<any, any>(edges).id((d: any) => d.id).distance((d: any) => 60 + (1 - d.ppmi / ppmiMax) * 90).strength(0.25))
    .force('charge', d3.forceManyBody().strength(-260))
    .force('center', d3.forceCenter(W / 2, H / 2))
    .force('collide', d3.forceCollide<any>().radius((d: any) => rNode(d.id) + 4));

  function render() {
    const link = linkSel.selectAll('line').data(edges, (d: any) => d.source.id + '>' + d.target.id);
    link.exit().remove();
    link.enter().append('line').attr('stroke-linecap', 'round')
      .merge(link as any)
      .attr('stroke', (d: any) => edgeColor(d.ppmi))
      .attr('stroke-width', (d: any) => 0.6 + 2.6 * (d.ppmi / ppmiMax))
      .attr('stroke-opacity', 0.55);

    const node = nodeSel.selectAll('circle').data(nodes, (d: any) => d.id);
    node.exit().remove();
    const nEnter = node.enter().append('circle')
      .attr('r', (d: any) => rNode(d.id))
      .attr('fill', (d: any) => d3.interpolateRgb('#5b6cff', accent)(Math.sqrt((size[d.id] || 1) / sizeMax)))
      .attr('stroke', gold).attr('stroke-width', 1).attr('stroke-opacity', 0.5)
      .style('cursor', 'pointer')
      .on('mouseover', (ev: any, d: any) => {
        tip.html(`<b>${esc(titleCase(d.id))}</b><br><span>${(size[d.id] || 0).toLocaleString()} lines</span><br>${esc(desc[d.id] || '')}`)
          .style('opacity', 1);
        d3.select(ev.currentTarget).attr('stroke-opacity', 1).attr('stroke-width', 2.5);
      })
      .on('mousemove', (ev: any) => {
        const r = host.getBoundingClientRect();
        tip.style('left', (ev.clientX - r.left + 14) + 'px').style('top', (ev.clientY - r.top + 12) + 'px');
      })
      .on('mouseout', (ev: any) => { tip.style('opacity', 0); d3.select(ev.currentTarget).attr('stroke-opacity', 0.5).attr('stroke-width', 1); })
      .on('click', (_ev: any, d: any) => { location.href = '/?q=' + encodeURIComponent(d.id) + '&mode=theme'; })
      .call(d3.drag<any, any>()
        .on('start', (ev, d: any) => { if (!ev.active) sim.alphaTarget(0.3).restart(); d.fx = d.x; d.fy = d.y; })
        .on('drag', (ev, d: any) => { d.fx = ev.x; d.fy = ev.y; })
        .on('end', (ev, d: any) => { if (!ev.active) sim.alphaTarget(0); d.fx = null; d.fy = null; }) as any);
    nEnter.append('title').text((d: any) => titleCase(d.id));

    const label = labelSel.selectAll('text').data(nodes.filter((d: any) => rNode(d.id) > 15), (d: any) => d.id);
    label.exit().remove();
    label.enter().append('text').text((d: any) => titleCase(d.id))
      .attr('font-size', 11).attr('font-weight', 600).attr('fill', ink)
      .attr('text-anchor', 'middle').attr('pointer-events', 'none')
      .attr('paint-order', 'stroke').attr('stroke', cssVar('--bg')).attr('stroke-width', 3);

    sim.nodes(nodes); (sim.force('link') as any).links(edges); sim.alpha(0.8).restart();
  }
  sim.on('tick', () => {
    linkSel.selectAll('line')
      .attr('x1', (d: any) => d.source.x).attr('y1', (d: any) => d.source.y)
      .attr('x2', (d: any) => d.target.x).attr('y2', (d: any) => d.target.y);
    nodeSel.selectAll('circle').attr('cx', (d: any) => d.x).attr('cy', (d: any) => d.y);
    labelSel.selectAll('text').attr('x', (d: any) => d.x).attr('y', (d: any) => d.y - rNode((d as any).id) - 4);
  });
  render();

  const slider = $('#ppmiRange') as HTMLInputElement | null;
  const out = $('#ppmiVal');
  if (slider) slider.oninput = () => {
    const v = +slider.value; if (out) out.textContent = v.toFixed(1);
    nodes = build(v); render();
  };
}

/* ============================ Chart.js author radar ============================ */
let radar: Chart | null = null;
async function authorRadar() {
  const selA = $('#authA') as HTMLSelectElement | null;
  const selB = $('#authB') as HTMLSelectElement | null;
  const canvas = $('#radar') as HTMLCanvasElement | null;
  if (!selA || !selB || !canvas) return;

  const list = await api('analytics/author');
  const authors = (list.authors || []).filter((a: any) => a.is_reliable !== 0);
  const opts = (sel: HTMLSelectElement, withNone: boolean) => {
    sel.innerHTML = (withNone ? '<option value="">— compare (optional) —</option>' : '') +
      authors.map((a: any) => `<option value="${esc(a.author)}">${esc(a.author)}</option>`).join('');
  };
  opts(selA, false); opts(selB, true);
  selA.value = authors[0]?.author || '';

  const fpMap = async (author: string) => {
    if (!author) return null;
    const d = await api('analytics/author?full=1&author=' + encodeURIComponent(author));
    const m: Record<string, number> = {};
    (d.theme_fingerprint || []).forEach((f: any) => { m[f.concept] = +f.lift; });
    return m;
  };

  async function draw() {
    const a = selA.value, b = selB.value;
    const mapA = await fpMap(a); if (!mapA) return;
    const mapB = b ? await fpMap(b) : null;
    // axes = author A's 9 most distinctive themes (lift desc)
    const axes = Object.entries(mapA).sort((x, y) => y[1] - x[1]).slice(0, 9).map(([k]) => k);
    const accent = cssVar('--accent') || '#ff9933';
    const blue = '#5b8cff';
    const grid = cssVar('--line-strong') || 'rgba(255,255,255,.13)';
    const ink = cssVar('--ink'), soft = cssVar('--soft');
    const ds = [{
      label: a, data: axes.map((c) => +(mapA[c] || 0).toFixed(2)),
      borderColor: accent, backgroundColor: accent + '33', pointBackgroundColor: accent, borderWidth: 2,
    }];
    if (mapB) ds.push({
      label: b, data: axes.map((c) => +(mapB[c] || 0).toFixed(2)),
      borderColor: blue, backgroundColor: blue + '2e', pointBackgroundColor: blue, borderWidth: 2,
    });
    const cfg: any = {
      type: 'radar',
      data: { labels: axes.map(titleCase), datasets: ds },
      options: {
        responsive: true, maintainAspectRatio: false,
        scales: { r: {
          beginAtZero: true, suggestedMin: 0, suggestedMax: 2.5,
          angleLines: { color: grid }, grid: { color: grid },
          pointLabels: { color: ink, font: { size: 12, weight: '600' } },
          ticks: { color: soft, backdropColor: 'transparent', showLabelBackdrop: false, stepSize: 0.5 },
        } },
        plugins: { legend: { labels: { color: ink, usePointStyle: true } },
          tooltip: { callbacks: { label: (c: any) => `${c.dataset.label}: lift ${c.formattedValue}×` } } },
      },
    };
    if (radar) { radar.data = cfg.data; radar.options = cfg.options; radar.update(); }
    else radar = new Chart(canvas, cfg);
    const note = $('#radarNote');
    if (note) note.textContent = `Theme emphasis as lift vs. the corpus baseline (1.0× = average). Axes are ${a}'s most distinctive themes.`;
  }
  selA.onchange = draw; selB.onchange = draw;
  draw();
}

themeNetwork();
authorRadar();
