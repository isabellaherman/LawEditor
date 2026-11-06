// LawEditor: the Chat tab. Its logic is CHAT.bend; this file reads input, talks to the server and draws.
// It only adds a view: main.js keeps the other views.

import C from "../CHAT.bend";

const $ = (id) => document.getElementById(id);
const chat = $("chat"), ask = $("ask"), send = $("send"), composer = $("composer");
const page = document.querySelector(".page");
const said = [];   // [{ who, text }], oldest first
let answering = false;

function msg(who, text) {
  const m = document.createElement("div");
  m.className = who === C.person() ? "msg msg--me" : "msg";
  m.textContent = text;
  chat.append(m);
  page.scrollTop = page.scrollHeight;
  return m;
}

// The conversation as the agent reads it (AGENT.md, "Chat").
const conversation = () => said.map((m) => (m.who === C.person() ? "Person: " : "Agent: ") + m.text).join("\n");

// The AI picked in the agent (main.js keeps it).
function activeAi() { try { return localStorage.getItem("laweditor.ai"); } catch { return null; } }

async function reply() {
  const ai = activeAi();
  if (!ai) return "Pick an AI in the agent first.";
  try {
    const res = await fetch("/api/chat/" + ai, { method: "POST", body: conversation() });
    const text = await res.text();
    const nl = text.indexOf("\n");
    return text.slice(nl + 1).trim() || "The agent didn't answer.";
  } catch {
    return "The LawEditor server isn't running.";
  }
}

const sync = () => { send.disabled = !C.can_send(answering, ask.value.trim().length); };
ask.addEventListener("input", sync);
ask.addEventListener("keydown", (e) => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); composer.requestSubmit(); } });
composer.addEventListener("submit", async (e) => {
  e.preventDefault();
  const text = ask.value.trim();
  if (!C.can_send(answering, text.length)) return;
  ask.value = "";
  said.push({ who: C.person(), text }); msg(C.person(), text);
  answering = true; sync();
  const answer = await reply();
  said.push({ who: C.agent(), text: answer }); msg(C.agent(), answer);
  answering = false; sync();
});
sync();

// The tab: main.js hides its own views when Chat is picked; this shows Chat and its composer.
document.querySelectorAll("#side [data-view]").forEach((b) => b.addEventListener("click", () => {
  const on = b.dataset.view === "chat";
  $("view-chat").hidden = !on;
  composer.hidden = !on;
  if (on) ask.focus();
}));
