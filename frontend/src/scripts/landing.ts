// landing.ts — the gurbanisoul.com landing's one client controller. A single idempotent init()
// runs on first load AND after every view-transition swap (astro:page-load); teardown() releases
// its observers/timers on astro:before-swap so nothing leaks across navigations. It NEVER imports
// core.ts (the Knowledge Base's DOM/API layer) — only the self-contained theme + pahar helpers.
import { initTheme, applyTheme, setDefaultTheme } from "./theme";
import { paharFixed, paharLabel, paharRange } from "./pahar.js";
import { wireNewsletter } from "./newsletter";

type Theme = "light" | "dark" | "system";

// gurbanisoul.com is LIGHT-FIRST: with no stored choice the marketing pages render light whatever
// the OS appearance (the Knowledge Base keeps its 'system' default — it never loads this module).
// Must run before initTheme(); the pre-paint script in Marketing.astro uses the same default.
const MARKETING_DEFAULT: Theme = "light";
setDefaultTheme(MARKETING_DEFAULT);

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

/** aria-current="page" on the primary/mobile nav link whose route matches the current pathname.
    The server renders this correctly per page; this re-asserts it after each ClientRouter swap. */
function wireNavActive() {
  const here = (location.pathname || "/").replace(/\/+$/, "") || "/";
  document.querySelectorAll<HTMLAnchorElement>(".mnav-links a[href], #mobileMenu a[href]").forEach((a) => {
    const href = a.getAttribute("href") || "";
    if (!href.startsWith("/") || href.startsWith("//")) return; // route links only
    const route = href.replace(/\/+$/, "") || "/";
    if (route === here) a.setAttribute("aria-current", "page");
    else a.removeAttribute("aria-current");
  });
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
  // /watch's eight-pahar timeline cells (data-p, deliberately NOT data-pahar: they are never hidden).
  const cells = document.querySelectorAll<HTMLElement>(".pcell[data-p]");
  if (!svg && !caption && !lis.length && !cells.length) return;

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
    cells.forEach((c) => {
      if (Number(c.dataset.p) === p) c.setAttribute("data-now", "");
      else c.removeAttribute("data-now");
    });
  };
  render();
  tick = window.setInterval(render, 60_000);
  cleanups.push(() => {
    if (tick) window.clearInterval(tick);
    tick = undefined;
  });
}

/** Legal pages (LegalPage.astro): mark the contents-rail link of the section being read with
    aria-current. No-op when the page has no `.legal` article. */
function wireTocActive() {
  const sections = Array.from(document.querySelectorAll<HTMLElement>(".legal section[id]"));
  const links = Array.from(document.querySelectorAll<HTMLAnchorElement>(".legal-toc a[href^='#']"));
  if (!sections.length || !links.length || typeof IntersectionObserver !== "function") return;
  const visible = new Set<string>();
  const mark = (id: string) => {
    links.forEach((a) => {
      if (a.getAttribute("href") === `#${id}`) a.setAttribute("aria-current", "true");
      else a.removeAttribute("aria-current");
    });
  };
  const io = new IntersectionObserver(
    (entries) => {
      for (const en of entries) {
        const id = (en.target as HTMLElement).id;
        if (en.isIntersecting) visible.add(id);
        else visible.delete(id);
      }
      // The first section (in document order) inside the reading band wins; if none is in the
      // band (between two long sections) the previous mark is kept.
      const first = sections.find((s) => visible.has(s.id));
      if (first) mark(first.id);
    },
    { rootMargin: "-92px 0px -55% 0px", threshold: 0 }
  );
  sections.forEach((s) => io.observe(s));
  observers.push(io);
  cleanups.push(() => links.forEach((a) => a.removeAttribute("aria-current")));
}

/** Hero phone drift: the floating hero device lags the scroll by at most 12px (passive listener,
    one rAF per frame). Motion-safe only; uses the individual `translate` property so it composes
    with the device's own rotate() transform. Torn down on astro:before-swap. */
function wireHeroDrift() {
  const device = document.querySelector<HTMLElement>(".hero-device .device");
  const hero = device?.closest<HTMLElement>(".hero") ?? null;
  if (!device || !hero || !motionOK()) return;
  const MAX = 12;
  let frame = 0;
  const update = () => {
    frame = 0;
    const h = hero.offsetHeight || 1;
    const p = Math.min(Math.max(window.scrollY / h, 0), 1);
    device.style.translate = `0 ${(p * MAX).toFixed(2)}px`;
  };
  const onScroll = () => {
    if (!frame) frame = requestAnimationFrame(update);
  };
  window.addEventListener("scroll", onScroll, { passive: true });
  update();
  cleanups.push(() => {
    window.removeEventListener("scroll", onScroll);
    if (frame) cancelAnimationFrame(frame);
    frame = 0;
    device.style.translate = "";
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
  wireNavActive();
  wireReveal();
  wireRaagClock();
  wireTocActive();
  wireHeroDrift();
  const nl = wireNewsletter(); // no-op when the env-gated form is absent (this build)
  if (nl) cleanups.push(nl);
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
    const t = (localStorage.getItem("theme") as Theme) || MARKETING_DEFAULT;
    applyTheme(t);
  } catch {
    applyTheme(MARKETING_DEFAULT);
  }
}

document.addEventListener("astro:page-load", init);
document.addEventListener("astro:before-swap", teardown);
document.addEventListener("astro:after-swap", () => {
  reapplyTheme();
  forwardLegacyQuery();
});
