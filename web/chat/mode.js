// The chat's mode: a Bend-UI dropdown under the composer. The modes, their names, which one the chat
// starts in and which can be picked are POLICY.bend (HARNESS.md); this draws them and keeps the pick.
// A mode that asks needs an AI that can ask: picking Codex turns it off and goes back to the start mode.
import P from "../../POLICY.bend";

export function createMode(dd, aiDd, firstAi) {
  const label = dd.querySelector("[aria-haspopup] span");
  let mode = Number(P.chat_mode_index()), codex = firstAi === "codex";
  const items = [];
  for (let i = 0; i < Number(P.mode_count()); i++) {
    const b = document.createElement("button");
    b.className = "menu__item"; b.type = "button"; b.dataset.mode = i;
    b.setAttribute("role", "menuitemradio");
    b.innerHTML = '<span></span><svg class="icon icon--sm menu__check"><use href="#i-check"/></svg>';
    b.querySelector("span").textContent = P.mode_name(i);
    items.push(b);
  }
  dd.querySelector(".menu").append(...items);
  function draw() {
    items.forEach((b, i) => { b.disabled = !P.mode_can_pick(i, codex); b.setAttribute("aria-checked", i === mode); });
    label.textContent = P.mode_name(mode);
  }
  dd.addEventListener("pick", (e) => { mode = Number(e.detail.dataset.mode); draw(); });
  aiDd.addEventListener("pick", (e) => {
    codex = e.detail.dataset.id === "codex";
    if (!P.mode_can_pick(mode, codex)) mode = Number(P.chat_mode_index());
    draw();
  });
  draw();
  // set: the offer's Switch (OFFER.bend) moves the picker, as if the person had picked it.
  return { get: () => mode, set(i) { if (P.mode_can_pick(i, codex)) { mode = Number(i); draw(); } } };
}
