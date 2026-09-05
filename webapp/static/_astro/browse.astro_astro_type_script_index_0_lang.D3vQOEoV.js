import{$ as o,b as r,g as m,m as v,e}from"./core.DsxD4iDU.js";let l=null,g=null;const f=[{gm:"ਸੁਖਮਨੀ ਸਾਹਿਬ",roman:"Sukhmani Sahib",ang:262,where:"Raag Gauri"},{gm:"ਆਸਾ ਕੀ ਵਾਰ",roman:"Asa Ki Vaar",ang:462,where:"Raag Asa"},{gm:"ਅਨੰਦੁ ਸਾਹਿਬ",roman:"Anand Sahib",ang:917,where:"Raag Ramkali"},{gm:"ਬਾਵਨ ਅਖਰੀ",roman:"Bavan Akhri",ang:250,where:"Raag Gauri"},{gm:"ਸਿਧ ਗੋਸਟਿ",roman:"Sidh Gosht",ang:938,where:"Raag Ramkali"},{gm:"ਓਅੰਕਾਰੁ",roman:"Dakhni Oankaar",ang:929,where:"Raag Ramkali"}],d={ਚਉਬੋਲੇ:[{name:"ਚਉਬੋਲੇ",first_ang:1363,last_ang:1364,n_lines:24},{name:"ਸਲੋਕ ਭਗਤ ਕਬੀਰ ਜੀ",first_ang:1364,last_ang:1377,n_lines:494},{name:"ਸਲੋਕ ਭਗਤ ਫਰੀਦ ਜੀ",first_ang:1377,last_ang:1384,n_lines:298}]};function u(n){const a=[];for(const t of n)d[t.name]?a.push(...d[t.name]):a.push(t);return a}const b=m(async()=>{const n=await v();l=n,o("#quickOut").innerHTML=f.map(a=>`
    <div class="tile" data-ang="${a.ang}" role="button" tabindex="0" aria-label="${e(a.roman)} — open Ang ${a.ang}">
      <div class="n gm">${e(a.gm)}</div>
      <div class="r">${e(a.roman)}</div>
      <div class="s">Ang ${a.ang} · ${e(a.where)}</div>
    </div>`).join(""),o("#raagsOut").innerHTML=n.raags.map((a,t)=>`
    <div class="tile" data-raag="${t}" role="button" tabindex="0">
      <div class="seq">RAAG ${a.seq||""}</div>
      <div class="n gm">${e(a.name)}</div>
      <div class="r">${e(a.roman||"")}</div>
      <div class="s">Angs ${a.first_ang}–${a.last_ang} · ${a.n_shabads??"—"} compositions · ${a.n_lines} lines</div>
    </div>`).join(""),g=u(n.sections),o("#sectionsOut").innerHTML=g.map((a,t)=>`
    <div class="tile" data-section="${t}" role="button" tabindex="0">
      <div class="n gm">${e(a.name)}</div>
      <div class="s">Angs ${a.first_ang}–${a.last_ang} · ${a.n_lines} lines</div>
    </div>`).join("")});function i(n){const a={major:"tab-major",raags:"tab-raags",sections:"tab-sections"};for(const t in a){const s=o("#"+a[t]);s&&(s.style.display=t===n?"":"none")}document.querySelectorAll("#raagTabs span").forEach(t=>{const s=t.dataset.tab===n;t.classList.toggle("on",s),t.setAttribute("aria-selected",String(s)),t.setAttribute("tabindex",s?"0":"-1")})}document.querySelectorAll("#raagTabs span").forEach(n=>{n.onclick=()=>i(n.dataset.tab),n.onkeydown=a=>{if(a.key==="Enter"||a.key===" ")a.preventDefault(),i(n.dataset.tab);else if(a.key==="ArrowRight"||a.key==="ArrowDown"){a.preventDefault();const t=n.nextElementSibling||n.parentElement.firstElementChild;t.focus(),i(t.dataset.tab)}else if(a.key==="ArrowLeft"||a.key==="ArrowUp"){a.preventDefault();const t=n.previousElementSibling||n.parentElement.lastElementChild;t.focus(),i(t.dataset.tab)}}});function c(n){if(n.dataset.raag!==void 0){const a=l.raags[+n.dataset.raag];r(a.first_ang,a.name)}else n.dataset.ang!==void 0?r(+n.dataset.ang):n.dataset.section!==void 0&&r((g||l.sections)[+n.dataset.section].first_ang)}document.addEventListener("click",n=>{const a=n.target.closest(".tile[data-raag],.tile[data-section],.tile[data-ang]");a&&c(a)});document.addEventListener("keydown",n=>{(n.key==="Enter"||n.key===" ")&&n.target.classList?.contains("tile")&&(n.preventDefault(),c(n.target))});i("major");b();
