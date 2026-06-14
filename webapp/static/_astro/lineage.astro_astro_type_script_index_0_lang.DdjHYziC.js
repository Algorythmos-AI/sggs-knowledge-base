import{$ as p,a as m,e as a}from"./core.BqXgFkHn.js";const $={guru:"Guru",bhagat:"Bhagat",bhatt:"Bhatt",gursikh:"Gursikh"};async function b(){const n=p("#timeline");if(!n)return;let o,r;try{[o,r]=await Promise.all([fetch("/contributors.json").then(s=>s.json()),m("meta")])}catch{n.innerHTML='<div class="hint">Could not load the contributor data.</div>';return}const l={};(r.authors||[]).forEach(s=>{l[s.name]=s});const d=(o.contributors||[]).map(s=>({...s,first_ang:l[s.name]?.first_ang,last_ang:l[s.name]?.last_ang,n_lines:l[s.name]?.n_lines})).sort((s,t)=>s.born-t.born),c=Math.max(1,...d.map(s=>s.n_lines||0)),h=s=>Math.round(100*Math.sqrt((s||0)/c));n.innerHTML=d.map((s,t)=>{const i=(s.circa?"c.":"")+s.born,u=s.n_lines?`${s.n_lines.toLocaleString()} lines · Angs ${s.first_ang}–${s.last_ang}`:"in the corpus";return`<button class="tl-node kind-${s.kind}" data-i="${t}" type="button" aria-label="${a(s.roman)} — details">
        <span class="tl-dot"></span>
        <span class="tl-year">${a(i)}</span>
        <span class="tl-card">
          <span class="tl-row"><span class="tl-name">${a(s.roman)}</span><span class="tl-kind">${$[s.kind]||s.kind}${s.seq?" · M"+s.seq:""}</span></span>
          <span class="tl-era">${a(s.era)} · ${a(s.region)}</span>
          <span class="tl-bar"><i style="width:${h(s.n_lines||0)}%"></i></span>
          <span class="tl-lines">${a(u)}</span>
        </span>
      </button>`}).join("");const e=p("#tlFilter");e&&e.querySelectorAll("span").forEach(s=>{s.onclick=()=>{e.querySelectorAll("span").forEach(i=>i.classList.toggle("on",i===s));const t=s.dataset.k;n.querySelectorAll(".tl-node").forEach(i=>{i.style.display=t==="all"||i.classList.contains("kind-"+t)?"":"none"})}}),n.querySelectorAll(".tl-node").forEach(s=>{s.onclick=()=>g(d[+s.dataset.i])})}async function g(n){const o=p("#ptitle"),r=p("#pbody");o&&(o.textContent=n.roman);const l=n.died?`${n.circa?"c.":""}${n.born}–${n.died}`:`${n.circa?"c.":""}${n.born}`,d=n.n_lines?`${n.n_lines.toLocaleString()} lines · Angs ${n.first_ang}–${n.last_ang}`:"—";r&&(r.innerHTML=`
    <div class="ld-chips">
      <span class="ld-chip kind-${n.kind}">${$[n.kind]||n.kind}${n.seq?" · M"+n.seq:""}</span>
      <span class="ld-chip">${a(l)}</span>
      <span class="ld-chip">${a(n.region)}</span>
      <span class="ld-chip">${a(n.tradition)}</span>
    </div>
    <p class="ld-blurb">${a(n.blurb)}</p>
    <div class="ld-span">In the Granth: <b>${a(d)}</b></div>
    <div id="ldTerms" class="ld-terms"></div>
    <div class="endnav" style="margin-top:16px"><span></span>
      ${n.first_ang?`<button onclick="goReader(${n.first_ang})">Read their first composition (Ang ${n.first_ang}) →</button>`:""}</div>`),window.openPanel?.();try{const c=await m("analytics/author?author="+encodeURIComponent(n.name)),h=(c.distinctive_terms||[]).slice(0,10).map(t=>a(t.term)),e=c.stylometry||{},s=p("#ldTerms");s&&h.length&&e.is_reliable!==0?s.innerHTML=`<div class="ld-h">Distinctive words <span class="ld-note">(keyness vs. corpus · English)</span></div>
        <div class="ld-termwrap">${h.map(t=>`<span class="ld-term">${t}</span>`).join("")}</div>`:s&&e.is_reliable===0&&(s.innerHTML='<div class="ld-note">Stylometry withheld — sample too small to be reliable.</div>')}catch{}}b();
