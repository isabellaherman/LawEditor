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

  // A rule the chat heard (HEAR.bend), under its reply: the sentence as a document block, and the person's answer.
  // answers: [{ label, value, kind }], kind is a Bend-UI button ("btn--primary", "btn--ghost" or "").
  // The same card asks before the chat acts (ASK.bend): then preview is what would change, and dot is "dot dot--warn".
  function proposal(sentence, answers, preview = "", dot = "dot") {
    const m = document.createElement("div");
    m.className = "msg msg--face";
    m.innerHTML = '<div class="msg__face"></div><div><div class="block"><div class="block__slot"><span class="dot"></span></div><div class="block__text"></div></div><div class="actions"></div></div>';
    const block = m.querySelector(".block"), actions = m.querySelector(".actions");
    block.querySelector(".block__text").textContent = sentence;
    block.querySelector(".dot").className = dot;
    if (preview) { const p = document.createElement("pre"); p.className = "block__out is-preview"; p.textContent = preview; block.append(p); }
    list.append(m); down();
    return {
      // Waits for a click; the buttons go away.
      ask: () => new Promise((done) => {
        for (const a of answers) {
          const b = document.createElement("button");
          b.className = ("btn btn--sm " + a.kind).trim(); b.type = "button"; b.textContent = a.label;
          b.addEventListener("click", () => { actions.remove(); done(a.value); });
          actions.append(b);
        }
        down();
      }),
      // What happened to it: the block's dot, and a note under the sentence.
      set(dot, note) {
        actions.remove();
        block.querySelector(".dot").className = dot;
        let out = block.querySelector(".block__out:not(.is-preview)");
        if (!out) { out = document.createElement("pre"); out.className = "block__out"; block.append(out); }
        out.textContent = note; down();
      },
    };
  }

  return { mine, theirs, proposal };
}
