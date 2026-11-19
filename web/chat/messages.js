// Chat messages: draws them. A reply and everything that comes of it (what the agent did, its plan, its
// words, the files it changed, the questions it asked, the rules it heard) is one turn: Bend-UI's .turn,
// rows of two columns (a mark, the text), so every line of text of a turn starts at the same place.
// While the agent works, its part of the turn shows what ASK.bend reads from the turn's file (the server's
// work/<turn>): its plan, its actions, what it does now. When it ends, that work folds into one line.
// After a reply that changed the project, the turn says what Bend answered: its check of the .bend files,
// and the page it bundled, with a button that opens it (engine/BUILD.bend).
// at: the open conversation's things: at.output(turn, n) (where an action's output is asked for),
// at.openFolder(), at.openFile(path), at.changed(files) (a reply changed these files), at.tag(file) (what
// is said of a file that isn't Bend, or "") and at.openPage() (what opens the project's page, or null).
import { markdown } from "../markdown.js";
import { codeBlock, highlight } from "bend-ui/syntax";
import { lessMotion, sleep, get, esc, icon } from "../where.js";

const DOTS = { busy: "dot dot--busy", ok: "dot dot--success", error: "dot dot--danger", none: "dot" };
const el = (html) => { const t = document.createElement("template"); t.innerHTML = html.trim(); return t.content.firstChild; };
// One row of a turn: what goes in its mark, what goes beside it. turn__row--sm: a line of work (small text).
const row = (mark, main, cls = "") => el(`<div class="turn__row ${cls}"><div class="turn__mark">${mark}</div><div class="turn__main">${main}</div></div>`);
const line = (kind, what, { meta = "", tone = "", mono = false } = {}) => `<div class="turn__line"><span class="tool__kind${tone ? " tool__kind--" + tone : ""}">${esc(kind)}</span><span class="tool__what${mono ? " mono" : ""}">${esc(what)}</span>${meta ? `<span class="tool__meta">${esc(meta)}</span>` : ""}</div>`;
// A row that opens: its summary is the row (spans: a <summary> takes no <div>), then what it shows.
const summary = (mark, main) => `<summary class="turn__row turn__row--sm"><span class="turn__mark">${mark}</span><span class="turn__main">${main.replace(/<(\/?)div/g, "<$1span")}</span></summary>`;
const STEPS = 50;   // at most this many steps for an answer to appear word by word (web/chat/messages.js write)
const plural = (n, word) => `${n} ${word}${n === 1 ? "" : "s"}`;

export function createMessages(list, page, at) {
  // The page follows the conversation down only while the person is at its end. Scrolling up to read lets
  // them stay where they are; coming back to the end (or speaking) follows again. Only what the person does
  // (wheel, touch, keys, the scroll bar) lets go: the page's own smooth scrolling passes through places
  // far from the end and must not.
  // held: a conversation opened again is being drawn; it is out of sight and nothing scrolls until it is whole.
  let follow = true, pressed = false, held = false;
  const atEnd = () => page.scrollHeight - page.scrollTop - page.clientHeight < 48;
  const scroll = () => { if (!held) page.scrollTo({ top: page.scrollHeight, behavior: lessMotion.matches ? "auto" : "smooth" }); };
  const down = () => { if (follow) scroll(); };
  const mineDown = () => { follow = true; scroll(); };
  const looked = () => requestAnimationFrame(() => { follow = atEnd(); });
  page.addEventListener("wheel", (e) => { if (e.deltaY < 0) follow = false; else looked(); }, { passive: true });
  page.addEventListener("touchmove", looked, { passive: true });
  page.addEventListener("keydown", (e) => { if (["ArrowUp", "ArrowDown", "PageUp", "PageDown", "Home", "End", " "].includes(e.key)) looked(); });
  page.addEventListener("pointerdown", () => { pressed = true; });
  addEventListener("pointerup", () => { if (pressed) { pressed = false; looked(); } });
  page.addEventListener("scroll", () => { if (pressed) follow = atEnd(); else if (atEnd()) follow = true; }, { passive: true });

  // Yours: a bubble at the right that fades in.
  // files: what the person pointed to with @, as tags after the text.
  // old: from a conversation opened again (it is just there, with no motion).
  function mine(text, files = [], old = false) {
    const m = document.createElement("div");
    m.className = old ? "msg msg--me" : "msg msg--me is-arriving";
    m.textContent = text;
    for (const f of files) { const t = document.createElement("span"); t.className = "tag tag--mono"; t.textContent = "@" + f; m.append(" ", t); }
    list.append(m); if (old) down(); else mineDown();   // the person spoke: the page follows again
  }

  // A turn: the agent's face, then its rows. It goes on until the person speaks again.
  function turn() {
    const m = el('<div class="msg msg--face"><div class="msg__face"><div></div></div><div class="turn"></div></div>');
    list.append(m); down();
    const box = m.lastChild;
    let rules = null;      // the group of rules being heard (it ends when something else comes)
    let part = null;       // the reply that runs now
    const put = (node) => { rules = null; box.append(node); down(); return node; };

    // ---------- A reply: one answer of the agent, with its work ----------
    function reply() {
      const work = el('<div class="turn"></div>');                               // its plan, its actions, what was allowed
      const now = row('<span class="dot dot--warning"></span>', '<div class="turn__line"><span class="working__verb">Reading</span><span class="tool__what">your project</span><span class="tool__meta">0s</span></div>', "turn__row--sm");
      const text = row("", "<div></div>"), words = text.querySelector(".turn__main > div");
      put(work); box.append(now);
      let plan = null, acts = null, count = 0, steps = 0, streamed = false, changes = [], head = "", held = false, ended = false;
      const t0 = Date.now(), verb = now.querySelector(".working__verb"), what = now.querySelector(".tool__what"), time = now.querySelector(".tool__meta");
      const tick = setInterval(() => { time.textContent = Math.round((Date.now() - t0) / 1000) + "s"; }, 1000);
      const say = () => { if (text.isConnected) return; if (now.isConnected) now.before(text); else box.append(text); };

      // The work so far, as ASK.bend wrote it: one line each, T (action), P (plan step), C (file), H (files' title), W (now).
      // turnId: the turn's id, so an action can show what it answered (at.output(turnId, n)) when opened.
      // Answers how much context the turn used (percent), or null.
      function draw(lines, turnId) {
        const rows = lines.split("\n").filter(Boolean).map((l) => l.split("\t"));
        const all = rows.filter((r) => r[0] === "T"), plans = rows.filter((r) => r[0] === "P"), doing = rows.find((r) => r[0] === "W");
        changes = rows.filter((r) => r[0] === "C"); head = (rows.find((r) => r[0] === "H") || [])[1] || "";
        // The plan always comes first, whichever arrived first.
        if (plans.length) {
          if (!plan) { plan = el('<div class="turn__group"></div>'); work.prepend(plan); }
          steps = plans.length;
          plans.forEach(([, status, label], i) => {
            let r = plan.children[i];
            if (!r) { r = row('<span class="plan__step"><span class="plan__node"><i class="node__core"></i></span></span>', '<span class="turn__step"></span>', "turn__row--sm"); r.querySelector(".plan__node").style.setProperty("--i", i); plan.append(r); }
            const node = r.querySelector(".plan__step"), step = r.querySelector(".turn__step"), was = node.classList.contains("is-now");
            step.textContent = label;
            for (const x of [node, step]) { x.classList.toggle("is-done", status === "done"); x.classList.toggle("is-now", status === "now"); }
            if (was && status === "done") { node.classList.add("is-pop"); setTimeout(() => node.classList.remove("is-pop"), 600); }
          });
        }
        for (const [, kind, tone, label] of all.slice(count)) {
          const n = count++;
          if (!acts) { acts = el('<div class="turn__group"></div>'); work.append(acts); }
          const d = el(`<details class="turn__more" data-action>${summary(icon("chevron-right", true), line(kind, label, { tone, mono: true }))}<pre class="turn__out"></pre></details>`);
          acts.append(d);
          d.addEventListener("toggle", async () => {
            const out = d.querySelector(".turn__out");
            if (!d.open || !out || out.textContent) return;
            let answer = ""; try { answer = await get(at.output(turnId, n)); } catch {}
            // An edit answers with what it changed: drawn as a diff code block, clipped when long.
            if (kind === "Edit" && answer) { out.replaceWith(el(codeBlock(answer, { lang: "diff", name: label, clip: true }))); return; }
            out.textContent = answer || "(no output)";
          });
        }
        // The detail comes when the action answers: an edit's lines, how many lines it answered, or that it didn't run.
        const drawn = work.querySelectorAll("details[data-action]");
        all.forEach(([, , , , detail], i) => {
          const d = drawn[i]; if (!d || !detail) return;
          let meta = d.querySelector("summary .tool__meta");
          if (!meta) { meta = document.createElement("span"); meta.className = "tool__meta"; d.querySelector("summary .turn__line").append(meta); }
          meta.textContent = detail;
        });
        if (doing && !streamed && !held) { verb.textContent = doing[1]; what.textContent = doing[2]; }
        down();
        const x = rows.find((r) => r[0] === "X");
        return x ? Number(x[1]) : null;
      }

      // Done: what it does now goes; its work folds into one line; the files changed close the reply.
      function finish(took) {
        if (ended) return; ended = true;
        clearInterval(tick); now.remove();
        if (count || steps) {
          const about = [took ? "for " + took : "", count ? plural(count, "action") : "", steps ? plural(steps, "step") : ""].filter(Boolean).join(" · ");
          const fold = el(`<details class="turn__more turn__more--flat">${summary(icon("chevron-right", true), line("Worked", about))}</details>`);
          work.replaceWith(fold); fold.append(work);
          // What the person allowed or refused stays in sight, after the fold.
          let after = fold;
          for (const r of [...work.querySelectorAll(":scope > .is-record")]) { after.after(r); after = r; }
        } else if (!work.children.length) work.remove();
        else work.replaceWith(...work.children);
        if (!changes.length) return;
        at.changed(changes.map(([, file, add, del]) => [file, Number(add), Number(del)]));
        const end = row('<span class="dot dot--success"></span>', `<div class="turn__line turn__line--wrap"><span class="turn__strong">${esc(head)}</span><button class="link link--icon turn__end" type="button">${icon("folder", true)}<span>Open folder</span></button></div>`, "turn__row--sm");
        const folder = end.querySelector(".turn__end");
        for (const [, file, add, del] of changes.slice(0, 3)) {
          const tag = at.tag(file);   // a file that isn't Bend: no law checks it
          const f = el(`<button class="link link--icon turn__file" type="button"><span class="mono">${esc(file)}</span>${Number(add) ? `<span class="changes__add">+${add}</span>` : ""}${Number(del) ? `<span class="changes__del">−${del}</span>` : ""}${tag ? `<span class="tag">${esc(tag)}</span>` : ""}</button>`);
          f.addEventListener("click", () => at.openFile(file)); folder.before(f);
        }
        if (changes.length > 3) folder.before(el(`<span class="tool__meta">and ${changes.length - 3} more</span>`));
        folder.addEventListener("click", () => at.openFolder());
        put(end);
      }
      // The answer, once whole: Markdown, drawn by Bend-UI's .prose.
      const prose = (s) => { if (!s.trim()) return; say(); words.className = "prose"; words.innerHTML = markdown(s); words.querySelectorAll("pre").forEach((pre) => highlight(pre, pre.dataset.lang || undefined)); };
      const took = () => { const s = Math.round((Date.now() - t0) / 1000); return s >= 60 ? `${Math.floor(s / 60)}m ${s % 60}s` : `${s}s`; };

      return (part = {
        work: draw,
        // The answer while it is written (Claude streams it): shown as it comes, no word motion.
        live(s) {
          if (!s.trim()) { text.remove(); return; }   // only its plan so far: no empty line of text, and it isn't writing yet
          streamed = true; say(); words.textContent = s;
          if (!held) { verb.textContent = "Writing"; what.textContent = ""; }
          down();
        },
        // The answer arrives whole from the CLI; its words appear one after another, each fading in. It is
        // already here, so the motion never makes the person wait: a long answer shows more words at each
        // step, and the whole takes about a second and a half at most (STEPS steps of 30ms).
        // shown(): false once the conversation left the page; the words stop there and nothing is finished.
        async write(answer, shown = () => true) {
          if (!streamed && answer.trim()) {
            say(); words.textContent = "";
            const all = answer.split(/(\s+)/).filter(Boolean), count = all.filter((w) => /\S/.test(w)).length;
            const each = Math.max(1, Math.ceil(count / STEPS));
            let n = 0;
            for (const w of all) {
              const s = document.createElement("span");
              if (/\S/.test(w)) s.className = "msg__word";
              s.textContent = w; words.append(s);
              if (/\S/.test(w) && !lessMotion.matches && ++n % each === 0) { down(); await sleep(30); if (!shown()) return; }
            }
          }
          prose(answer); finish(took()); part = null; down();
        },
        // From an old conversation, opened again: no motion, the answer and what it changed.
        restore(answer) { prose(answer); finish(""); part = null; },
        // It stopped, or failed: what it does now goes, and its work stays open (where it stopped is in sight).
        stop() { ended = true; clearInterval(tick); now.remove(); if (!work.children.length) work.remove(); part = null; },
        // A question waits for the person: the reply says so, instead of counting as if it worked.
        waiting(on) { held = on; verb.textContent = on ? "Waiting" : "Working"; what.textContent = on ? "for your answer" : ""; },
        record(node) { acts = null; work.append(node); down(); },
      });
    }

    // ---------- A rule the chat heard: its sentence, and what came of it ----------
    function rule(sentence) {
      let r = null;
      const show = () => {
        if (r) return;
        if (!rules) { const g = el('<div class="turn__group"></div>'); g.append(row("", '<span class="turn__label">Rules heard</span>', "turn__row--sm")); put(g); rules = g; }
        r = row('<span class="dot"></span>', `<span class="turn__text">${esc(sentence)}</span><span class="turn__note"></span>`, "turn__row--tight");
        rules.append(r); down();
      };
      return {
        answered: show,
        set(state, note) {
          show();
          r.querySelector(".dot").className = DOTS[state] || DOTS.none;
          const n = r.querySelector(".turn__note"); n.textContent = note; n.classList.toggle("turn__note--error", state === "error");
        },
      };
    }
    // ---------- What the person answered to a question (the mode it offered, an action it asked for) ----------
    // what: what was asked, in a few words ("Write index.html"), or nothing when the answer's own words
    // say it whole. One line stays in the turn as the record.
    function record(what) {
      let r = null;
      const show = (said, ok) => {
        const html = `<div class="turn__mark ${ok ? "turn__mark--success" : "turn__mark--warning"}">${icon(ok ? "check" : "x", true)}</div><div class="turn__main">${line(said, what, { tone: ok ? "" : "warning" })}</div>`;
        if (r) { r.innerHTML = html; return; }
        r = el(`<div class="turn__row turn__row--sm is-record">${html}</div>`);
        if (part) part.record(r); else put(r);
      };
      return { answered: (said, ok) => show(said, ok), set: (state, note) => show(note.replace(/\.$/, ""), state === "ok") };
    }
    // ---------- What Bend said of the project, after a reply changed it ----------
    // The check. ok: the files checked, then how many claims wait for a proof. error: the file, then
    // what Bend said, as it said it.
    function checked(state, text) {
      const [first = "", ...rest] = text.split("\n");
      if (state === "ok") {
        const open = Number(rest[0]) || 0;
        return put(row('<span class="dot dot--success"></span>', line("Bend checked", first, { mono: true, meta: open ? `no errors · ${open} without a proof` : "no errors" }), "turn__row--sm"));
      }
      put(row('<span class="dot dot--danger"></span>', `${line("Bend found an error in", first, { mono: true, tone: "warning" })}<pre class="turn__out turn__out--error">${esc(rest.join("\n"))}</pre>`, "turn__row--sm"));
    }
    // The page. ok: its file. warn: why it is not as it should be (it imports no Bend). error: the file,
    // then what Bend said. A page that was bundled opens in a tab of its own.
    function bundled(state, text) {
      const [first = "", ...rest] = text.split("\n"), open = state === "error" ? null : at.openPage();
      const button = open ? `<button class="link link--icon turn__end" type="button">${icon("external-link", true)}<span>Open the page</span></button>` : "";
      const main = state === "ok" ? `<div class="turn__line turn__line--wrap"><span class="tool__kind">Bend bundled</span><span class="tool__what mono">${esc(first)}</span>${button}</div>`
        : state === "warn" ? `<div class="turn__line turn__line--wrap"><span class="turn__text">${esc(text)}</span>${button}</div>`
        : `${line("Bend could not bundle", first, { mono: true, tone: "warning" })}<pre class="turn__out turn__out--error">${esc(rest.join("\n"))}</pre>`;
      const r = put(row(`<span class="dot ${state === "ok" ? "dot--success" : state === "warn" ? "dot--warning" : "dot--danger"}"></span>`, main, "turn__row--sm"));
      if (open) r.querySelector(".turn__end").addEventListener("click", open);
    }
    // The reply stopped or failed: the turn says why, after what it had done.
    const fail = (why, again) => put(failure(why, again, (r) => r.remove()));
    return { el: m, slot: m.firstChild.firstChild, reply, rule, record, checked, bundled, fail };
  }

  // Why something couldn't be done, and Try again when there is something to try (gone: what to take away then).
  function failure(why, again, gone) {
    const r = row('<span class="dot"></span>', `<div class="turn__line turn__line--wrap"><span class="turn__text">${esc(why)}</span>${again ? '<button class="btn btn--sm turn__end" type="button">Try again</button>' : ""}</div>`);
    if (again) r.querySelector(".btn").addEventListener("click", () => { gone(r); again(); });
    return r;
  }
  // The same, outside any turn (a message that could not be sent, a command that could not run).
  function failed(why, again) {
    const m = el('<div class="msg msg--face"><div class="msg__face"></div><div class="turn"></div></div>');
    m.lastChild.append(failure(why, again, () => m.remove())); list.append(m); down();
  }

  // A command the person ran themselves (!): the command, and what it printed.
  function ran(command, code, output) {
    const m = el('<div class="msg msg--face"><div class="msg__face"></div><div class="turn"></div></div>');
    const ok = code === "0";
    m.lastChild.append(row(`<span class="dot ${ok ? "dot--success" : "dot--danger"}"></span>`, `${line("You ran", command, { mono: true })}<pre class="turn__out${ok ? "" : " turn__out--error"}">${esc(output || "(no output)")}</pre>`, "turn__row--sm"));
    list.append(m); down();
  }

  return { mine, turn, failed, ran, clear: () => { list.replaceChildren(); follow = true; },
    // A conversation opened again: drawn out of sight (hold(true)), then shown whole at its end, where it
    // was left, with no motion (hold(false)).
    hold(on) {
      held = on; list.hidden = on;
      if (!on) { follow = true; page.scrollTo({ top: page.scrollHeight, behavior: "auto" }); }
    },
  };
}
