// The chat's start (Bend-UI .chat__start): while the chat is empty (CHAT.bend: is_start), the agent's big face
// and the composer sit in the middle. The first message sends the composer back under the page with a glide
// (a fade, with no travel, when the person asks for less motion) and hands the face's place to the first reply.
import { mountAgent } from "bend-ui/agent";

const lessMotion = matchMedia("(prefers-reduced-motion: reduce)");
const token = (name) => getComputedStyle(document.documentElement).getPropertyValue(name).trim();
const ms = (name) => { const v = token(name); return v.endsWith("ms") ? parseFloat(v) : parseFloat(v) * 1000; };

export function createStart(page, form) {
  const home = form.parentElement, after = form.nextSibling;   // where the composer lives once the chat has begun
  const start = document.createElement("div");
  start.className = "chat__start";
  start.innerHTML = "<div><div></div></div>";
  page.prepend(start);
  start.append(form);
  const face = mountAgent(start.firstChild.firstChild, { size: "lg", items: [] });

  return {
    show(visible) { start.hidden = !visible; },
    // Leaves the start; answers where the face was, for it to fly to the first reply (none with less motion).
    async leave() {
      const from = form.getBoundingClientRect(), faceAt = face.face.getBoundingClientRect();
      const fade = { duration: ms("--duration-enter") / 2, easing: token("--ease") };
      if (lessMotion.matches) await start.animate([{ opacity: 1 }, { opacity: 0 }], fade).finished;
      home.insertBefore(form, after);
      start.remove(); face.destroy();
      form.querySelector("textarea").focus();              // moving it took the caret away
      if (lessMotion.matches) { form.animate([{ opacity: 0 }, { opacity: 1 }], fade); return null; }
      const to = form.getBoundingClientRect();
      form.animate([{ transform: `translateY(${from.top - to.top}px)` }, { transform: "none" }],
        { duration: ms("--duration-connect"), easing: token("--ease") });
      return faceAt;
    },
  };
}
