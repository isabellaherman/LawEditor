// LawEditor: the Chat tab. Its logic is CHAT.bend; each part in web/chat/ draws itself; this file wires them
// and talks to the server. It only adds a view: main.js keeps the other views.
import C from "../CHAT.bend";
import H from "../HEAR.bend";
import E from "../EDITOR.bend";
import A from "../ASK.bend";
import P from "../POLICY.bend";
import { createMessages } from "./chat/messages.js";
import { createFace } from "./chat/face.js";
import { createModels } from "./chat/models.js";
import { createComposer } from "./chat/composer.js";
import { createMode } from "./chat/mode.js";
import { markdown } from "./markdown.js";
import { highlight } from "bend-ui/syntax";
import { createStart } from "./chat/start.js";

const $ = (id) => document.getElementById(id);
const said = [];   // [{ who, text }], oldest first

const messages = createMessages($("chat"), document.querySelector(".page"));
const face = createFace();
const [aiDd, modelDd] = document.querySelectorAll("#composer .composer__bar .dropdown");
let saved = null; try { saved = localStorage.getItem("laweditor.ai"); } catch {}
const models = createModels(aiDd, modelDd, saved);
const chatMode = createMode($("mode"), aiDd, models.get().ai);   // what the chat may do (POLICY.bend, HARNESS.md)

// The conversation as the agent reads it (AGENT.md, "Chat").
const conversation = () => said.map((m) => (m.who === C.person() ? "Person: " : "Agent: ") + m.text).join("\n");

async function post(path, body) {
  try { return await (await fetch(path, { method: "POST", body })).text(); }
  catch { return "error\nThe LawEditor server isn't running."; }
}
const textOf = (res) => res.slice(res.indexOf("\n") + 1).trim() || "The agent didn't answer.";

// Ask before changes (POLICY.bend, ASK.bend): what the chat may not do yet comes back as a question.
// The person answers on a card; the server resumes the same session with what they allowed.
// "Always allow" keeps that action allowed for the rest of this session (this page, until it reloads).
const always = [];   // Claude rules the person allowed for the session, like Edit(//…/GDD.md)
const ASK_ANSWERS = [
  { label: "Don't allow", value: A.dont(), kind: "btn--ghost" },
  { label: "Always allow", value: A.always(), kind: "" },
  { label: "Allow", value: A.allow(), kind: "btn--primary" },
];
async function askFirst(model, reply) {
  let res = await post(`/api/ask/${model}`, always.join("\t") + "\n" + conversation());
  while (res.startsWith("ask\n")) {
    const [, session, grant, question, ...preview] = res.split("\n");
    reply.el.remove();   // the card takes the reply's place; the answer comes after it
    composer.hold(true);
    const card = messages.proposal(question, ASK_ANSWERS, preview.join("\n").trim(), "dot dot--warn");
    const choice = await card.ask();
    const allowed = A.allows(choice);
    if (A.keeps(choice) && !always.includes(grant)) always.push(grant);
    card.set(allowed ? "dot dot--ok" : "dot", allowed ? (A.keeps(choice) ? "Allowed for this session." : "Allowed.") : "Not allowed.");
    composer.hold(false);
    reply = messages.theirs(); face.to(reply.slot); face.lookAt(reply.el);
    const grants = allowed && !always.includes(grant) ? [...always, grant] : always;
    res = await post(`/api/allow/${model}`, session + "\n" + (allowed ? "yes" : "no") + "\n" + grants.join("\t"));
  }
  return { reply, answer: textOf(res) };
}

async function ask(reply) {
  const { ai, model } = models.get();
  if (P.mode_asks_at(chatMode.get())) return askFirst(model, reply);
  return { reply, answer: textOf(await post(`/api/chat/${ai}/${model}`, conversation())) };
}

const start = createStart(document.querySelector(".page"), $("composer"));
let started = false;

const composer = createComposer($("composer"), async (text) => {
  const from = C.is_start(said.length) ? await start.leave() : undefined;
  if (from !== undefined) { started = true; show(); }
  said.push({ who: C.person(), text }); messages.mine(text);
  const first = messages.theirs();
  face.to(first.slot, from ?? undefined); face.lookAt(first.el);
  const { reply, answer } = await ask(first);
  said.push({ who: C.agent(), text: answer });
  await reply.write(H.words(answer));
  face.lookAt(null);
  hear(answer);   // not awaited: the person can keep talking while a proposal waits
});

// The skill (HEAR.md) asked the chat to end its reply with LAW: "<sentence>" lines.
// HEAR.bend reads them and decides: ask (every session starts so), or, after "Always add", add.
// An added sentence goes to the document, and the law agent writes its law (main.js, "laweditor:add").
let mode = H.start();
const heard = [];   // sentences proposed this session, so none is asked twice
const ANSWERS = [
  { label: "Don't add", value: H.dont(), kind: "btn--ghost" },
  { label: "Always add", value: H.always(), kind: "" },
  { label: "Add", value: H.add(), kind: "btn--primary" },
];
const DOT = { [E.empty()]: "dot", [E.busy()]: "dot dot--busy", [E.ok()]: "dot dot--ok", [E.error()]: "dot dot--error" };
let queue = Promise.resolve(), writing = Promise.resolve();
function hear(answer) {
  const n = H.count(answer);
  if (!n) return;
  composer.hold(true);   // CHAT.bend: while a question waits, the talk stops (question_stops_the_talk)
  queue = queue.then(async () => {
    let gdd = ""; try { gdd = await (await fetch("/api/file/GDD.md")).text(); } catch {}
    // First every question, right under the reply; then the laws, so the person isn't held while the agent works.
    const added = [];
    for (let i = 0; i < n; i++) {
      const sentence = H.proposal(answer, i);
      if (!H.is_new(sentence, gdd + "\n" + heard.join("\n"))) continue;
      heard.push(sentence);
      const card = messages.proposal(sentence, ANSWERS);
      const choice = H.must_ask(mode) ? await card.ask() : H.add();
      mode = H.mode_after(mode, choice);
      if (!H.adds(choice)) { card.set("dot", "Not added."); continue; }
      card.set(DOT[E.busy()], "Added to the document. Writing its law…");
      added.push({ sentence, card });
    }
    composer.hold(false);
    // The laws, one at a time, on their own line: a later question doesn't wait for them.
    for (const { sentence, card } of added) writing = writing.then(async () => {
      const { state, out } = await new Promise((done) =>
        document.dispatchEvent(new CustomEvent("laweditor:add", { detail: { sentence, done } })));
      card.set(DOT[state], out);
    });
  });
}

// Chat opens first. Its selector shows the conversation or its context (CHAT.md, what the chat is told).
// main.js hides its own views when Chat is picked; this shows Chat. In Chat the face lives beside the
// replies, so the big agent (and its toolbar dock) step aside.
let chatView = "chat", inChat = true;
function show() {
  start.show(inChat && chatView === "chat" && !started);
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
fetch("/api/file/HARNESS.md").then((r) => r.text()).then((md) => { $("harness-md").textContent = md || "HARNESS.md not found"; }).catch(() => {});
fetch("/api/file/HEAR.md").then((r) => r.text()).then((md) => { $("hear-md").innerHTML = markdown(md || "# HEAR.md not found"); }).catch(() => {});
fetch("/api/file/CHAT.md").then((r) => r.text()).then((md) => { $("chat-md").innerHTML = markdown(md || "# CHAT.md not found"); $("chat-md").querySelectorAll("pre").forEach(highlight); }).catch(() => {});
show();
