// landing.ts — the gurbanisoul.com landing's one client controller. A single idempotent init()
// runs on first load AND after every view-transition swap (astro:page-load); teardown() releases
// its observers/timers on astro:before-swap so nothing leaks across navigations. It NEVER imports
// core.ts (the Knowledge Base's DOM/API layer) — only the self-contained theme + pahar helpers.
import { initTheme, applyTheme } from "./theme";
import { paharFixed, paharLabel, paharRange } from "./pahar.js";

type Theme = "light" | "dark" | "system";

let observers: IntersectionObserver[] = [];
let cleanups: Array<() => void> = [];
let tick: number | undefined;

const motionOK = () =>
  typeof matchMedia === "function" && matchMedia("(prefers-reduced-motion: no-preference)").matches;

/** Mobile <dialog> menu: open/close, aria-expanded sync, Esc, focus restore, body scroll lock. */
function wireMobileMenu() {
  const burger = document.querySelector<HTMLButtonElement>(".burger");
  const dialog = document.getElementById("mobileMenu") as HTMLDialogElement | null;
  if (!burger || !dialog || typeof dialog.showModal !== "function") return;
  const close = document.querySelector<HTMLButtonElement>(".mm-close");

  const open = () => {
    dialog.showModal();
    burger.setAttribute("aria-expanded", "true");
    document.body.style.overflow = "hidden";
  };
  const shut = () => {
    if (dialog.open) dialog.close();
  };
  const onOpen = () => open();
  const onClose = () => shut();
  const onDialogClose = () => {
    burger.setAttribute("aria-expanded", "false");
    document.body.style.overflow = "";
    burger.focus();
  };
  // A link tap inside the menu should dismiss it (in-page anchors don't navigate away).
  const onLinkClick = (e: Event) => {
    if ((e.target as HTMLElement).closest("a")) shut();
  };

  burger.addEventListener("click", onOpen);
  close?.addEventListener("click", onClose);
  dialog.addEventListener("close", onDialogClose);
  dialog.addEventListener("click", onLinkClick);
  cleanups.push(() => {
    burger.removeEventListener("click", onOpen);
    close?.removeEventListener("click", onClose);
    dialog.removeEventListener("close", onDialogClose);
    dialog.removeEventListener("click", onLinkClick);
    shut();
    document.body.style.overflow = "";
  });
}

/** Frost the nav once the page has scrolled past a 1px sentinel at the very top. */
function wireNavScrolled() {
  const nav = document.getElementById("mnav");
  if (!nav) return;
  const sentinel = document.createElement("div");
  sentinel.style.cssText = "position:absolute;top:0;left:0;height:1px;width:1px;pointer-events:none";
  document.body.prepend(sentinel);
  const io = new IntersectionObserver(
    ([e]) => nav.classList.toggle("scrolled", !e.isIntersecting),
    { threshold: 0 }
  );
  io.observe(sentinel);
  observers.push(io);
  cleanups.push(() => sentinel.remove());
}

/** aria-current on the primary nav anchor whose section is in the reading band. */
function wireScrollSpy() {
  const anchors = new Map<string, HTMLAnchorElement>();
  document.querySelectorAll<HTMLAnchorElement>('.mnav-links a[href^="#"]').forEach((a) => {
    anchors.set(a.getAttribute("href")!.slice(1), a);
  });
  const sections = [...anchors.keys()]
    .map((id) => document.getElementById(id))
    .filter((el): el is HTMLElement => !!el);
  if (!sections.length) return;
  const io = new IntersectionObserver(
    (entries) => {
      for (const en of entries) {
        if (!en.isIntersecting) continue;
        anchors.forEach((a) => a.removeAttribute("aria-current"));
        anchors.get(en.target.id)?.setAttribute("aria-current", "true");
      }
    },
    { rootMargin: "-40% 0px -55% 0px", threshold: 0 }
  );
  sections.forEach((s) => io.observe(s));
  observers.push(io);
}

/** Reveal-on-scroll — only when motion is allowed; otherwise content stays visible (CSS default). */
function wireReveal() {
  const els = document.querySelectorAll<HTMLElement>(".reveal");
  if (!els.length || !motionOK()) return;
  document.documentElement.classList.add("js-motion");
  const io = new IntersectionObserver(
    (entries, obs) => {
      for (const en of entries) {
        if (en.isIntersecting) {
          en.target.classList.add("in");
          obs.unobserve(en.target);
        }
      }
    },
    { rootMargin: "0px 0px -10% 0px", threshold: 0.05 }
  );
  els.forEach((el) => io.observe(el));
  observers.push(io);
  cleanups.push(() => document.documentElement.classList.remove("js-motion"));
}

/** Live raag clock: mark the current pahar on the arc, rotate the hand, caption it, reveal its li. */
function wireRaagClock() {
  const svg = document.querySelector(".raag-arc");
  const caption = document.querySelector<HTMLElement>("[data-raag-now]");
  const lis = document.querySelectorAll<HTMLElement>("li[data-pahar]");
  if (!svg && !caption && !lis.length) return;

  const render = () => {
    const p = paharFixed(new Date());
    svg?.querySelectorAll(".seg").forEach((s) => {
      s.classList.toggle("now", Number((s as HTMLElement).dataset.pahar) === p);
    });
    const hand = document.getElementById("arcHand");
    if (hand) hand.style.transform = `rotate(${(p - 1) * 45 + 22.5}deg)`;
    if (caption) caption.textContent = `It is the ${paharLabel(p)} — ${paharRange(p)}.`;
    lis.forEach((li) => {
      li.hidden = Number(li.dataset.pahar) !== p;
    });
  };
  render();
  tick = window.setInterval(render, 60_000);
  cleanups.push(() => {
    if (tick) window.clearInterval(tick);
    tick = undefined;
  });
}

function teardown() {
  observers.forEach((o) => o.disconnect());
  observers = [];
  cleanups.forEach((fn) => fn());
  cleanups = [];
}

function init() {
  teardown(); // idempotent — a re-run (page-load after a swap) starts from a clean slate
  initTheme();
  wireMobileMenu();
  wireNavScrolled();
  wireScrollSpy();
  wireReveal();
  wireRaagClock();
}

// Forward legacy /?q= bookmarks to /search after a client-side swap lands on `/`.
function forwardLegacyQuery() {
  try {
    const p = new URLSearchParams(location.search);
    if (p.has("q") && location.pathname === "/") location.replace("/search" + location.search);
  } catch {}
}
// Re-assert the resolved theme after a swap (the fresh document starts from the pre-paint value).
function reapplyTheme() {
  try {
    const t = (localStorage.getItem("theme") as Theme) || "system";
    applyTheme(t);
  } catch {
    applyTheme("system");
  }
}

document.addEventListener("astro:page-load", init);
document.addEventListener("astro:before-swap", teardown);
document.addEventListener("astro:after-swap", () => {
  reapplyTheme();
  forwardLegacyQuery();
});
