import{g as d,$ as l,a as c,e as a}from"./core.C9TdTPZP.js";import{p,a as h,f as r}from"./pahar.-uWCi5co.js";function g(t){return t.pahar?`${p(t.pahar)} (${h(t.pahar)})`:t.time_start?`${r(t.time_start)}–${r(t.time_end)}`:a(t.season||t.occasion||"—")}d(async()=>{const t=l("#divOut");if(!t)return;const s=await c("timing/divergence");if(!s.available){t.innerHTML='<div class="hint">The timing knowledge layer is not present in this database build.</div>';return}if(!s.raags?.length){t.innerHTML='<div class="hint">No divergent claims recorded.</div>';return}const o=s.raags.map(n=>n.claims.map((e,i)=>`<tr class="${i===0?"rfirst":""}">
      ${i===0?`<th scope="rowgroup" rowspan="${n.claims.length}" class="rcell">
        <a href="/reader?ang=${n.first_ang}&raag=${encodeURIComponent(n.raag)}" aria-label="Read raag ${a(n.roman)} from Ang ${n.first_ang}">
          <span class="gm" lang="pa">${a(n.raag)}</span><span class="tr">${a(n.roman)}</span></a></th>`:""}
      <td data-l="Claim"><span class="cbadge cb-${a(e.claim_type)}">${a(e.claim_type)}</span></td>
      <td data-l="When"><b>${g(e)}</b>${e.notes?`<div class="cnotes">${a(e.notes)}</div>`:""}</td>
      <td data-l="Tradition"><span class="tbadge tb-${a(e.tradition)}">${a(e.tradition==="hindustani"?"Hindustani":"Gurmat Sangeet")}</span></td>
      <td data-l="Confidence"><span class="conf conf-${a(e.confidence)}">${a(e.confidence)}</span></td>
      <td data-l="Source">${e.source_url?`<a href="${a(e.source_url)}" rel="noopener" target="_blank">${a(e.source_name)}</a>`:a(e.source_name)}</td>
    </tr>`).join("")).join("");t.innerHTML=`<table class="claims-table div-table">
    <caption>${s.raags.length} raags with conflicting timing claims. Each row is one attributed claim; nothing is merged or adjudicated.</caption>
    <thead><tr><th scope="col">Raag</th><th scope="col">Claim</th><th scope="col">When</th>
      <th scope="col">Tradition</th><th scope="col">Confidence</th><th scope="col">Source</th></tr></thead>
    <tbody>${o}</tbody></table>
    <p class="cnotes divnote">${a(s.note||"")}</p>`})();
