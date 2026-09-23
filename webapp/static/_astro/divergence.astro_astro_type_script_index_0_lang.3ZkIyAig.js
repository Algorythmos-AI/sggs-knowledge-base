import{c as e,i as t,n,t as r}from"./core.HDWhTXCo.js";import{o as i,s as a,t as o}from"./pahar.CeUv8UWo.js";var s=e=>/^https?:\/\//i.test(e||``)?t(e):``;function c(e){return e.pahar?t(`${i(e.pahar)} (${a(e.pahar)})`):e.time_start?t(`${o(e.time_start)}–${o(e.time_end)}`):t(e.season||e.occasion||`—`)}e(async()=>{let e=r(`#divOut`);if(!e)return;let i=await n(`timing/divergence`);if(!i.available){e.innerHTML=`<div class="hint">The timing knowledge layer is not present in this database build.</div>`;return}if(!i.raags?.length){e.innerHTML=`<div class="hint">No divergent claims recorded.</div>`;return}let a=i.raags.map(e=>e.claims.map((n,r)=>`<tr class="${r===0?`rfirst`:``}">
      ${r===0?`<th scope="rowgroup" rowspan="${e.claims.length}" class="rcell">
        <a href="/reader?ang=${e.first_ang}&raag=${encodeURIComponent(e.raag)}" aria-label="Read raag ${t(e.roman)} from Ang ${e.first_ang}">
          <span class="gm" lang="pa">${t(e.raag)}</span><span class="tr">${t(e.roman)}</span></a></th>`:``}
      <td data-l="Claim"><span class="cbadge cb-${t(n.claim_type)}">${t(n.claim_type)}</span></td>
      <td data-l="When"><b>${c(n)}</b>${n.notes?`<div class="cnotes">${t(n.notes)}</div>`:``}</td>
      <td data-l="Tradition"><span class="tbadge tb-${t(n.tradition)}">${t(n.tradition===`hindustani`?`Hindustani`:`Gurmat Sangeet`)}</span></td>
      <td data-l="Confidence"><span class="conf conf-${t(n.confidence)}">${t(n.confidence)}</span></td>
      <td data-l="Source">${s(n.source_url)?`<a href="${s(n.source_url)}" rel="noopener" target="_blank">${t(n.source_name)}</a>`:t(n.source_name)}</td>
    </tr>`).join(``)).join(``);e.innerHTML=`<table class="claims-table div-table">
    <caption>${i.raags.length} raags with conflicting timing claims. Each row is one attributed claim; nothing is merged or adjudicated.</caption>
    <thead><tr><th scope="col">Raag</th><th scope="col">Claim</th><th scope="col">When</th>
      <th scope="col">Tradition</th><th scope="col">Confidence</th><th scope="col">Source</th></tr></thead>
    <tbody>${a}</tbody></table>
    <p class="cnotes divnote">${t(i.note||``)}</p>`})();