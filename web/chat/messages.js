// Chat messages: draws them. The agent's reply goes through CHAT.bend's phases: reading, writing, done.
import C from "../../CHAT.bend";

const lessMotion = matchMedia("(prefers-reduced-motion: reduce)");
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

export function createMessages(list, page) {
  const down = () => page.scrollTo({ top: page.scrollHeight, behavior: lessMotion.matches ? "auto" : "smooth" });

  // Yours: a bubble at the right that fades in.
  function mine(text) {
    const m = document.createElement("div");
    m.className = "msg msg--me is-arriving";
    m.textContent = text;
    list.append(m); down();
  }

  // The agent's: its face, then what it is doing, then its words.
  function theirs() {
    const m = document.createElement("div");
    m.className = "msg msg--face";
    m.innerHTML = '<div class="msg__face"><div></div></div><div><span class="thread__reading">Reading your project…</span></div>';
    list.append(m); down();
    const body = m.lastChild;
    let phase = C.reading();
    return {
      el: m, slot: m.firstChild.firstChild,
      // The answer arrives whole from the CLI; its words appear one after another, each fading in.
      async write(text) {
        phase = C.writing(); body.textContent = "";
        for (const w of text.split(/(\s+)/).filter(Boolean)) {
          const s = document.createElement("span");
          if (/\S/.test(w)) s.className = "msg__word";
          s.textContent = w; body.append(s);
          if (/\S/.test(w) && !lessMotion.matches) { down(); await sleep(30); }
        }
        phase = C.done(); down();
      },
      phase: () => phase,
    };
  }

  return { mine, theirs };
}
