// Debug (to remove later): LawEditor's own LAWS.bend, exactly as the file is, and the output of
// `bend PROOF.bend`, run by the server each time this opens. Nothing here is typed by hand.
import { highlight } from "bend-ui/syntax";

const $ = (id) => document.getElementById(id);
const side = $("side");

async function load() {
  $("debug-laws").textContent = "Loading…"; $("debug-check").textContent = "Running bend PROOF.bend…"; $("debug-when").textContent = "";
  try { $("debug-laws").textContent = await (await fetch("/api/debug/LAWS.bend")).text(); highlight($("debug-laws").parentElement); } catch { $("debug-laws").textContent = "The LawEditor server isn't running."; }
  try { $("debug-check").textContent = await (await fetch("/api/debug/check")).text(); $("debug-when").textContent = "run at " + new Date().toLocaleTimeString(); } catch { $("debug-check").textContent = "The LawEditor server isn't running."; }
}

// The side bar: main.js and chat.js hide their views for anything but Laws and Chat; this shows Debug.
side.querySelectorAll("[data-view]").forEach((b) => b.addEventListener("click", () => {
  const on = b.dataset.view === "debug";
  $("view-debug").hidden = !on;
  if (!on) return;
  document.querySelector(".window__dock").hidden = true;   // no agent face here
  document.querySelector(".toolbar__dock").hidden = true;
  load();
}));
