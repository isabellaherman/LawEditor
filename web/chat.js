// LawEditor: the Chat tab. Its logic is CHAT.bend; each part in web/chat/ draws itself; this file wires them
// and talks to the server. It only adds a view: main.js keeps the other views.
import C from "../CHAT.bend";
import { createMessages } from "./chat/messages.js";
import { createFace } from "./chat/face.js";
import { createModels } from "./chat/models.js";
import { createComposer } from "./chat/composer.js";
import { markdown } from "./markdown.js";

const $ = (id) => document.getElementById(id);
const said = [];   // [{ who, text }], oldest first

const messages = createMessages($("chat"), document.querySelector(".page"));
const face = createFace();
const [aiDd, modelDd] = document.querySelectorAll("#composer .composer__bar .dropdown");
let saved = null; try { saved = localStorage.getItem("laweditor.ai"); } catch {}
const models = createModels(aiDd, modelDd, saved);

// The conversation as the agent reads it (AGENT.md, "Chat").
const conversation = () => said.map((m) => (m.who === C.person() ? "Person: " : "Agent: ") + m.text).join("\n");

async function ask() {
  const { ai, model } = models.get();
  try {
    const res = await fetch(`/api/chat/${ai}/${model}`, { method: "POST", body: conversation() });
    const text = await res.text();
    return text.slice(text.indexOf("\n") + 1).trim() || "The agent didn't answer.";
  } catch { return "The LawEditor server isn't running."; }
}

const composer = createComposer($("composer"), async (text) => {
  said.push({ who: C.person(), text }); messages.mine(text);
  const reply = messages.theirs();
  face.to(reply.slot); face.lookAt(reply.el);
  const answer = await ask();
  said.push({ who: C.agent(), text: answer });
  await reply.write(answer);
  face.lookAt(null);
});

// Chat opens first. Its selector shows the conversation or its context (CHAT.md, what the chat is told).
// main.js hides its own views when Chat is picked; this shows Chat. In Chat the face lives beside the
// replies, so the big agent (and its toolbar dock) step aside.
let chatView = "chat", inChat = true;
function show() {
  $("view-chat").hidden = !(inChat && chatView === "chat");
  $("composer").hidden = !(inChat && chatView === "chat");
  $("view-chat-context").hidden = !(inChat && chatView === "context");
  document.querySelectorAll(".chat-only").forEach((x) => x.hidden = !inChat);
  document.querySelector(".window__dock").hidden = inChat;
  document.querySelector(".toolbar__dock").hidden = inChat;
}
$("chat-view").addEventListener("change", (e) => { chatView = e.detail.dataset.view; show(); if (chatView === "chat") composer.focus(); });
document.querySelectorAll("#side [data-view]").forEach((b) => b.addEventListener("click", () => {
  inChat = b.dataset.view === "chat"; show();
  if (inChat && chatView === "chat") composer.focus();
}));
fetch("/api/file/CHAT.md").then((r) => r.text()).then((md) => { $("chat-md").innerHTML = markdown(md || "# CHAT.md not found"); }).catch(() => {});
show();
