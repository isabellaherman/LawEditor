// The AI and its model: two Bend-UI dropdowns under the composer. Picking the AI asks the server for its
// models (GET /api/models/<ai>: the server asks that AI's CLI; MODELS.bend reads the answer).
// The list's states come from CHAT.bend.
import C from "../../CHAT.bend";

const AIS = [["claude", "Claude"], ["codex", "Codex"]];
const esc = (s) => s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
const item = ([id, name], on) =>
  `<button class="menu__item" role="menuitemradio" aria-checked="${on}" data-id="${esc(id)}"><span>${esc(name)}</span><svg class="icon icon--sm menu__check"><use href="#i-check"/></svg></button>`;

async function fetchModels(ai) {
  try {
    const res = await fetch("/api/models/" + ai);
    if (!res.ok) return [];
    return (await res.text()).split("\n").filter(Boolean).map((l) => l.split("\t"));
  } catch { return []; }
}

export function createModels(aiDd, modelDd, first) {
  const label = (dd) => dd.querySelector("[aria-haspopup] span");
  const button = (dd) => dd.querySelector("[aria-haspopup]");
  let ai = AIS.some(([id]) => id === first) ? first : "claude", model = "";

  aiDd.querySelector(".menu").innerHTML = AIS.map((a) => item(a, a[0] === ai)).join("");
  label(aiDd).textContent = AIS.find(([id]) => id === ai)[1];
  aiDd.addEventListener("pick", (e) => { ai = e.detail.dataset.id; label(aiDd).textContent = e.detail.textContent.trim(); load(); });
  modelDd.addEventListener("pick", (e) => { model = e.detail.dataset.id; label(modelDd).textContent = e.detail.textContent.trim(); });

  async function load() {
    const asked = ai;
    let state = C.loading();
    const show = () => { button(modelDd).disabled = !C.can_pick(state); };
    label(modelDd).textContent = "Loading…"; show();
    const list = await fetchModels(asked);
    if (asked !== ai) return;                     // the AI changed while this list loaded
    state = list.length ? C.ready() : C.empty();
    model = list.length ? list[0][0] : "";
    modelDd.querySelector(".menu").innerHTML = list.map((m, i) => item(m, i === 0)).join("");
    label(modelDd).textContent = list.length ? list[0][1] : "Default";
    show();
  }
  load();
  return { get: () => ({ ai, model }) };
}
