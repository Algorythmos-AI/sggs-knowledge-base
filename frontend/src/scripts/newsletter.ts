// newsletter.ts — progressive enhancement for the env-gated launch-notice form (Newsletter.astro).
//
// Wired by landing.ts init() and guarded by the presence of `form.newsletter`, so it is inert on
// every page that does not render the form (i.e. every page in this build, where the env var is
// unset and the form is absent). It NEVER runs unless the form exists.
//
// Behaviour:
//  * Honeypot: if `hp_name` is non-empty, a bot filled it — prevent the submit, blank the action so
//    nothing is ever sent, and do nothing else.
//  * Otherwise: preventDefault and POST only the `email` field to the form's action with
//    { mode: 'no-cors' } (Buttondown accepts the opaque cross-origin POST). Show a confirmation on
//    resolve, and an offline/error hint on reject or when the browser is offline.
//  * With JS disabled the native POST still works (Buttondown shows its own confirmation page).
//
// Returns a teardown so landing.ts can detach the listener across view-transition swaps.
export function wireNewsletter(): (() => void) | void {
  const form = document.querySelector<HTMLFormElement>("form.newsletter");
  if (!form) return;

  const status = form.querySelector<HTMLElement>("[data-nl-status]");
  const action = form.getAttribute("action") || "";

  const say = (msg: string) => {
    if (status) status.textContent = msg;
  };

  const onSubmit = (e: SubmitEvent) => {
    const hp = form.querySelector<HTMLInputElement>('input[name="hp_name"]');
    if (hp && hp.value.trim() !== "") {
      // Bot: swallow the submit and make sure the native fallback can't fire either.
      e.preventDefault();
      form.setAttribute("action", "");
      return;
    }

    const email = form.querySelector<HTMLInputElement>('input[name="email"]');
    const value = (email?.value || "").trim();
    if (!value) return; // let native required-validation handle the empty case

    e.preventDefault();

    if (typeof navigator !== "undefined" && navigator.onLine === false) {
      say("You appear to be offline. Try again later, or write to support@gurbanisoul.com.");
      return;
    }

    // Only the email field is ever sent.
    const body = new URLSearchParams({ email: value });
    say("Sending…");
    fetch(action, { method: "POST", mode: "no-cors", body })
      .then(() => {
        say("Check your inbox to confirm — we sent one email.");
        form.reset();
      })
      .catch(() => {
        say("You appear to be offline. Try again later, or write to support@gurbanisoul.com.");
      });
  };

  form.addEventListener("submit", onSubmit);
  return () => form.removeEventListener("submit", onSubmit);
}
