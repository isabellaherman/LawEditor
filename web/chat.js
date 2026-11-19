// LawEditor: the Chat. The conversation lives in the server (engine/TURN.bend): this file sends what the
// person writes and answers, reads the conversation's events (harness/EVENTS.bend) and draws them, each
// part in web/chat/. It conducts nothing: the terminal reads the same events and shows the same talk.
import C from "../harness/CHAT.bend";
import H from "../harness/HEAR.bend";
import P from "../harness/POLICY.bend";
import O from "../harness/OFFER.bend";
import G from "../harness/GATE.bend";
import A from "../harness/ASK.bend";
import Ev from "../harness/EVENTS.bend";
import { announce } from "bend-ui";
import { codeBlock } from "bend-ui/syntax";
import { mountDiagram } from "bend-ui/diagram";
import { highlight } from "bend-ui/syntax";
import { createMessages } from "./chat/messages.js";
import { createFace } from "./chat/face.js";
import { createModels } from "./chat/models.js";
import { createComposer } from "./chat/composer.js";
import { createMode } from "./chat/mode.js";
import { createStart } from "./chat/start.js";
import { createPlace } from "./chat/place.js";
import { createList } from "./chat/list.js";
import { markdown } from "./markdown.js";
import { where, key, project, conversation, go, fresh, get, post, sleep, fields, inParts, esc } from "./where.js";

const $ = (id) => document.getElementById(id);
const page = document.querySelector(".page");

// Where the projects' pages are served (the server's pages door: another address than the app's own), or
// "" when that door couldn't open.
let pages = ""; get("/api/pages").then((url) => { pages = url.trim(); }).catch(() => {});
const messages = createMessages($("chat"), page, {
  output: (turn, n) => conversation(`output/${turn}/${n}`),
  openFolder: () => post(project("open")),
  openFile: (path) => document.dispatchEvent(new CustomEvent("laweditor:file", { detail: path })),
  changed: (files) => document.dispatchEvent(new CustomEvent("laweditor:changes", { detail: files })),
  // A file that isn't Bend says so beside its name (POLICY.bend: the layers); "" for a .bend file.
  tag: (file) => P.tag_of(A.extension(file)),
  // The project's page, as Bend last bundled it, in the frame beside the chat (web/preview.js; null: there is
  // nowhere to open it).
  openPage: () => (pages ? () => document.dispatchEvent(new CustomEvent("laweditor:preview")) : null),
});
const face = createFace();
const [aiDd, modelDd] = document.querySelectorAll("#composer .composer__bar .dropdown:not(#place):not(#mode)");
let saved = null; try { saved = localStorage.getItem("laweditor.ai"); } catch {}
const models = createModels(aiDd, modelDd, saved);
const chatMode = createMode($("mode"), aiDd, models.get().ai, () => conversation("allowed"));   // POLICY.bend, HARNESS.md
const place = createPlace($("place"), $("place-name"));

// What the person reads: the reply without its LAW:, MODE:, PLAN: and PROJECT: lines (each module hides its own).
const shown = (text) => inParts((part) => O.words(H.words(A.plan_words(C.project_words(part)))), text);
// The AI, its model and the mode, as the server reads them at the head of what is sent.
const settings = () => { const { ai, model } = models.get(); return `${ai}\t${model}\t${chatMode.get()}`; };

// ---------- The conversation on the page ----------
// seen: how many of the conversation's events were read and drawn. What goes on now (a turn runs, a question
// waits, the project's name) is asked to the server, which reads it from the conversation with EVENTS.bend.
let seen = 0, reader = 0, started = false;
let now = { running: "", asking: "", project: "" };
let reply = null, turn = "", streamed = "";       // the reply being drawn, its turn, its text so far
let ui = null;                                    // the turn on the page: a reply and what comes of it, until the person speaks
const asked = new Map();                          // turn -> its work, asked for ahead (read)
const cards = new Map();                          // question -> what the turn keeps of it (a rule's row, an answer's line)
let mineShown = 0;                                // messages of the person already drawn when they were sent

const meter = $("context");
function context(percent) {
  if (percent == null) return;
  meter.hidden = false;
  meter.querySelector(".meter__bar > span").style.width = Math.min(100, percent) + "%";
  meter.querySelector(".meter__value").textContent = percent + "%";
}
async function sync() {
  const me = reader;
  let text = ""; try { text = await get(conversation("now")); } catch {}
  if (me !== reader) return;
  const [running = "", asking = "", name = ""] = text.replace(/\n$/, "").split("\t");
  now = { running, asking, project: name };
  composer.set(!!running, !!asking);
}

const uiTurn = () => (ui ||= messages.turn());
function newReply() {
  const t = uiTurn();
  reply = t.reply();
  face.to(t.slot); face.lookAt(t.el);
  return reply;
}
const again = async () => { const r = await post(conversation("again"), settings()); if (!r.startsWith("ok")) sync(); };

// The answers of each kind of question, with the word the server reads (EVENTS.bend, GATE.bend, engine/TURN.bend).
const ANSWERS = {
  law: [{ label: "Don't add", value: Ev.dont_word() }, { label: "Always add", value: Ev.always_word() }, { label: "Add", value: Ev.add_word(), main: true }],
  mode: [{ label: "Stay", value: "stay" }, { label: "Switch", value: "switch", main: true }],
  gate: [{ label: "Don't allow", value: G.deny_word() }, { label: "Allow for this session", value: G.session_word() }, { label: "Allow", value: G.allow_word(), main: true }],
};
const kindOf = (q) => (Ev.is_law(q) ? "law" : Ev.is_mode(q) ? "mode" : "gate");

// A question: what it asks goes to the message box's place (composer.ask), where the person answers; the
// turn keeps the record (a rule's row with what came of it, or one line saying what was answered).
function question(q, text, open) {
  const kind = kindOf(q), t = uiTurn();
  let card, ask;
  if (kind === "law") {
    card = t.rule(text);
    ask = { title: "Add this rule to the document?", body: `<span class="turn__text">${esc(text)}</span>` };
  } else if (kind === "mode") {
    const [title, ...why] = text.split("\n");
    card = t.record("");   // its note says it whole ("Switched to Ask before changes.")
    ask = { title, body: why.length ? `<span class="turn__note">${esc(why.join("\n"))}</span>` : "" };
  } else {
    // GATE.question(): the question; then the language and name of what would change, and what is said of
    // a file that isn't Bend; then what would change.
    const [title, meta = "", ...preview] = text.split("\n"), [lang, name, note = ""] = meta.split("\t");
    const code = preview.join("\n").replace(/\n+$/, "");
    card = t.record(G.action_of(title));
    ask = { title, body: (note ? `<span class="turn__note">${esc(note)}</span>` : "") + (code ? codeBlock(code, { lang, name, clip: true }) : "") };
  }
  cards.set(q, card);
  if (!open) return;
  reply?.waiting(true);
  if (kind === "gate") watch();   // the action it asks about shows in the turn at once
  announce("The chat asks: " + text.split("\n")[0]);   // said to who can't see the question arrive
  composer.ask(q, { ...ask, answers: ANSWERS[kind] }).then((word) => post(conversation(`answer/${q}`), word));
  requestAnimationFrame(() => page.scrollTo({ top: page.scrollHeight }));   // the question took room: the turn's last rows stay in sight
}

// One event. old: it is read from a conversation opened again (no motion, nothing waits).
// later: the events that come after it in the same reading.
async function draw(line, old, later) {
  const parts = fields(line), kind = parts[0], f = (n) => parts[n + 1] || "";
  const kindIs = (k) => (l) => l.startsWith(k + "\t");
  if (kind === "me") { ui = null; if (mineShown > 0) mineShown--; else messages.mine(f(0), [], old); }
  if (kind === "turn") { turn = f(0); streamed = ""; newReply(); }
  if (kind === "reply") {
    const r = reply || newReply(), text = shown(f(1)), me = reader;
    try { context(r.work(await (asked.get(f(0)) || get(conversation(`work/${f(0)}`))), f(0))); } catch {}   // its actions and every file changed
    asked.delete(f(0));
    if (me !== reader) return;   // the person opened another conversation meanwhile: this one is no longer on the page
    if (old) r.restore(text); else await r.write(text, () => me === reader);
    if (me !== reader) return;
    face.lookAt(null); reply = null; turn = "";
  }
  if (kind === "fail" || kind === "stopped") {
    reply?.stop(); reply = null; turn = ""; face.lookAt(null);
    if (!later.some(kindIs("turn"))) uiTurn().fail(kind === "fail" ? f(1) : "You stopped the reply.", again);
  }
  if (kind === "ask") question(f(0), f(1), !later.some((l) => kindIs("answer")(l) && fields(l)[1] === f(0)));
  if (kind === "answer") {
    const q = f(0), k = kindOf(q);
    composer.answered(q);
    // Until the engine's note comes, the record says what was answered, in the gate's own words.
    if (k === "gate") cards.get(q)?.answered(G.note(f(1)).replace(/\.$/, ""), !!G.lets_run(f(1)));
    else if (k === "mode") cards.get(q)?.answered(f(1) === "switch" ? "Switched" : "Stayed", f(1) === "switch");
    else cards.get(q)?.answered();
    if (k === "mode" && f(1) === "switch") chatMode.set(O.mode_after(O.switch()));
    if (k === "gate") { if (G.keeps(f(1))) chatMode.allowed(); reply?.waiting(false); }
  }
  if (kind === "note") {
    cards.get(f(0))?.set(f(1), f(2));
    if (!old && Ev.is_law(f(0)) && f(1) !== "busy") document.dispatchEvent(new CustomEvent("laweditor:changed"));
  }
  if (kind === "project") { go(f(0)); place.lock(f(1)); list.refresh(); }
  // What Bend said of the project after the reply changed it (engine/BUILD.bend).
  if (kind === "check") uiTurn().checked(f(1), f(2));
  if (kind === "page") { uiTurn().bundled(f(1), f(2)); if (!old) document.dispatchEvent(new CustomEvent("laweditor:page")); }   // the frame shows the new one
  if (kind === "ran") { ui = null; messages.ran(f(0), f(1), f(2)); }
}

// Reads the events the page hasn't seen and draws them, in order.
async function read(old = false) {
  const me = reader;
  let text = ""; try { text = await get(conversation(`events/${seen}`)); } catch { return; }
  if (me !== reader) return;
  const lines = text.split("\n").filter(Boolean);
  // Every reply's work is asked for at once, before any is drawn: drawn in order, they don't wait in a row.
  for (const l of lines) if (l.startsWith("reply\t")) { const t = fields(l)[1]; if (!asked.has(t)) asked.set(t, get(conversation(`work/${t}`)).catch(() => "")); }
  for (const [i, line] of lines.entries()) {
    seen++;
    try { await draw(line, old, lines.slice(i + 1)); } catch (e) { console.error("An event could not be drawn:", e); }   // one event never stops the reading
    if (me !== reader) return;
  }
  if (lines.length) { await sync(); folderOn(); if (!old) list.refresh(); }
}
// While the chat answers: its work so far (ASK.bend reads the turn's file), and its words as it writes them.
async function watch() {
  if (!turn || !reply) return;
  const t = turn, r = reply;
  try { const w = await get(conversation(`work/${t}`)); if (reply === r) context(r.work(w, t)); } catch {}
  try { const text = await get(conversation(`progress/${t}`)); if (reply === r && text.trim() && text !== streamed) { streamed = text; r.live(shown(text)); } } catch {}
}
// The page keeps reading: fast while something goes on, slowly while nothing does.
async function follow() {
  const me = ++reader;
  while (me === reader) {
    await read();
    if (me !== reader) return;
    await watch();
    await sleep(now.running || now.asking ? 300 : 1200);
  }
}

// ---------- Starting, sending, opening ----------
let chatView = "chat", inChat = true;   // which view shows (Views, below)
let start = createStart(page, $("composer"));

async function leaveStart() {
  if (started) return undefined;
  const from = await start.leave(); started = true; show();
  return from;
}

const composer = createComposer($("composer"), {
  files: async () => { try { return (await get(project("files"))).split("\n").filter(Boolean); } catch { return []; } },
  onStop: () => post(conversation("stop")),
  onCommand: command,
  async onSend(text, files) {
    await leaveStart();
    if (!seen) {                                   // the first message: the conversation takes its place
      const g = place.chosen();
      if (g) go(g.key);
      place.lock(g ? g.name : "");
    }
    // A message that starts with ! is a command the person runs themselves, in the project's folder.
    if (text.startsWith("!")) {
      const r = await post(conversation("run"), settings() + "\n" + text.slice(1));
      if (!r.startsWith("ok")) { messages.failed(r === "readonly" ? "Only read runs no command. Pick another mode under the message box to run it." : r === "busy" ? "The chat is still answering, or a question waits for your answer." : "The LawEditor server isn't running, or this project isn't there anymore."); }
      await read(); sync(); list.refresh(); return;
    }
    ui = null; messages.mine(text, files); mineShown++;
    document.dispatchEvent(new CustomEvent("laweditor:sent"));   // a comment's pin stays where it points
    const r = await post(conversation("say"), settings() + "\n" + text + C.with_files("", files.join(", ")));   // CHAT.bend writes what comes after the text
    if (!r.startsWith("ok")) { mineShown--; messages.failed(r === "busy" ? "The chat is still answering, or a question waits for your answer." : "The LawEditor server isn't running, or this project isn't there anymore.", again); sync(); return; }
    list.refresh();
  },
});

// The person pointed at a part of the page (web/preview.js): the message starts with what it points at.
document.addEventListener("laweditor:point", (e) => { if (!inChat) toChat(); composer.write(e.detail); });

// Commands typed with / (CHAT.bend's commands).
function command(name) {
  if (name === "/clear") newConversation();   // a new conversation; the others stay in the list
  if (name === "/laws") document.querySelector('#side [data-view="doc"]').click();
  if (name === "/context") document.querySelector('#chat-view [data-view="context"]')?.click();
}

function reset() {
  messages.hold(false);
  reader++; seen = 0; now = { running: "", asking: "", project: "" }; ui = null; composer.answered(); reply = null; turn = ""; streamed = ""; mineShown = 0;
  cards.clear(); asked.clear(); messages.clear(); meter.hidden = true;
}
const toChat = () => document.querySelector('#side [data-view="chat"]').click();

// A new conversation: the start again, with nothing to pick. The one that was open goes on by itself.
function newConversation(into) {
  reset(); fresh();
  if (started) { started = false; start = createStart(page, $("composer")); }
  place.open(); if (into) place.choose(into.key, into.name);
  composer.set(false, false);
  toChat(); show(); list.refresh(); follow(); composer.focus();
}
// An old conversation opens whole: what was said, what each reply did, the questions and their answers.
async function openConversation(k, id) {
  if (id === where.conv && seen) { toChat(); return; }   // back to it from Laws
  reset(); go(k, id);
  messages.hold(true);   // drawn out of sight, then shown at once at its end: no climbing down from the top
  try { await leaveStart(); toChat(); await read(true); } finally { if (where.conv === id) messages.hold(false); }   // another one opened meanwhile: it shows itself
  place.lock(now.project || (rows.get(id) || ""));
  list.refresh(); follow();
}

// The side bar's list. A conversation that got its project (its folder was named) is followed there.
const rows = new Map();   // conversation -> its project's name, as the list last said
const list = createList($("history"), {
  current: () => (inChat ? where.conv : ""),   // in Laws, Laws is the place: no conversation is marked too
  onOpen: openConversation,
  onMoved(k, name) { rows.set(where.conv, name); if (k !== key()) go(k); if (name && seen) place.lock(name); },
  onGone: () => newConversation(),
});
$("new-conversation").addEventListener("click", () => newConversation());
// The project's folder, always in the same place on the bar (as the page is, beside it): on while the
// conversation has a folder of its own, which it gets with its first message.
const folderBtn = $("open-folder");
const folderOn = () => { folderBtn.disabled = !(where.key || seen); };
folderBtn.addEventListener("click", () => post(project("open")));
document.addEventListener("laweditor:where", folderOn);
// Another part of the page asks for a conversation (the compact view's line of state).
document.addEventListener("laweditor:open", (e) => openConversation(e.detail.key, e.detail.conv));

// ---------- Views ----------
// Chat opens first. Its selector shows the conversation or its context (what the chat is told).
// main.js hides its own views when Chat is picked; this shows Chat. In Chat the face lives beside the
// replies, so the big agent (and its toolbar dock) step aside.
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
  inChat = b.dataset.view === "chat"; show(); list.refresh();
  if (inChat && chatView === "chat") composer.focus();
}));
// Chat › Context: the offer flow, drawn from OFFER.flow() by Bend-UI's diagram (the code is the source).
{
  const items = (l) => { const out = []; while (l.$ === "Con") { out.push(l.head); l = l.tail; } return out; };
  const TONE = { Person: "", Skill: "accent", System: "success" };
  const steps = items(O.flow());
  mountDiagram($("offer-flow"), {
    nodes: steps.map((s) => ({ label: s.name, tone: TONE[s.who.$], tag: s.writes ? "writes a file" : "" })),
    edges: steps.flatMap((s, i) => items(s.next).map((g) => ({ from: i, to: Number(g.to), label: g.label }))),
  });
}
const told = async (name, el, md) => {
  let text = ""; try { text = await get(`/api/told/${name}`); } catch {}
  if (md) { el.innerHTML = markdown(text || `# ${name} not found`); el.querySelectorAll("pre").forEach((pre) => highlight(pre)); }
  else el.textContent = text || `${name} not found`;
};
told("HARNESS.md", $("harness-md")); told("HEAR.md", $("hear-md"), true); told("CHAT.md", $("chat-md"), true);
show(); follow();
