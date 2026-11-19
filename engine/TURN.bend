# LawEditor's engine: a conversation's turn. The person writes; the chat answers; the engine has Bend
# check what the chat changed (BUILD.bend), asks what has to be asked (a law it heard, the mode it offers,
# an action that needs a yes), writes the laws, and keeps every step as an event (harness/EVENTS.bend). A window only sends what the person wrote or
# answered, and draws the events: the page and the terminal show the same conversation.
#
# The rules of each step are in harness/ (HEAR, OFFER, GATE, POLICY, CHAT); this file runs them in order.

import Base
import ./SYS.bend as Sys
import ./PLACES.bend as Places
import ./PROJECTS.bend as Proj
import ./LAW.bend as Law
import ./BUILD.bend as Build
import ../harness/EVENTS.bend as Ev
import ../harness/POLICY.bend as Policy
import ../harness/ASK.bend as Ask
import ../harness/GATE.bend as Gate
import ../harness/CHAT.bend as Chat
import ../harness/HEAR.bend as Hear
import ../harness/OFFER.bend as Offer

# ---------- A conversation, while the engine works on it ----------
# key and dir: its project and that project's folder. ai, model, mode: what the person picked under the
# message box (mode is POLICY.bend's index).
type Talk is Data:
  Talk{cx: Sys.Ctx, key: String, dir: String, conv: String, ai: String, model: String, mode: U32}

def cx(w: Talk) -> Sys.Ctx:
  match w:
    case Talk{cx, key, dir, conv, ai, model, mode}:
      cx

def key(w: Talk) -> String:
  match w:
    case Talk{cx, key, dir, conv, ai, model, mode}:
      key

def dir(w: Talk) -> String:
  match w:
    case Talk{cx, key, dir, conv, ai, model, mode}:
      dir

def conv(w: Talk) -> String:
  match w:
    case Talk{cx, key, dir, conv, ai, model, mode}:
      conv

def ai(w: Talk) -> String:
  match w:
    case Talk{cx, key, dir, conv, ai, model, mode}:
      ai

def model(w: Talk) -> String:
  match w:
    case Talk{cx, key, dir, conv, ai, model, mode}:
      model

def mode(w: Talk) -> U32:
  match w:
    case Talk{cx, key, dir, conv, ai, model, mode}:
      mode

def is_codex(w: Talk) -> Bool:
  String.eq(ai(w), "codex")

# Does this turn ask before it acts? Its mode asks, and its AI can ask (POLICY.bend).
def asks(+w: Talk) -> Bool:
  (Policy.mode_asks_at(mode(w)) && Policy.can_ask(is_codex(w)))

def moved(w: Talk, key2: String, dir2: String) -> Talk:
  match w:
    case Talk{cx, key, dir, conv, ai, model, mode}:
      Talk{cx, key2, dir2, conv, ai, model, mode}

def in_mode(w: Talk, mode2: U32) -> Talk:
  match w:
    case Talk{cx, key, dir, conv, ai, model, mode}:
      Talk{cx, key, dir, conv, ai, model, mode2}

def log_of(+w: Talk) -> IO(String):
  Sys.read_file(Places.log(dir(w), conv(w)))

def emit(+w: Talk, line: String) -> IO(Unit):
  Sys.append_file(Places.log(dir(w), conv(w)), line)

def state(+w: Talk, s: String) -> IO(Unit):
  Sys.write_file(Places.state(dir(w), conv(w)), s)

# ---------- A question ----------

# The engine asks, and waits for the person as long as it takes: the answer comes in a file
# (POST /api/c/…/answer/<question>). The conversation shows as asking meanwhile.
def ask(+w: Talk, +q: String, text: String) -> IO(String):
  do IO<String>:
    Sys.write_file(Places.answer(dir(w), conv(w), q), "")
    emit(w, Ev.event("ask", [q, text]))
    state(w, Ev.waiting())
    +said : String <- Sys.wait(4294967295n, Places.answer(dir(w), conv(w), q), "")
    emit(w, Ev.event("answer", [q, said]))
    state(w, Ev.working())
    return said

# ---------- The chat's command line (POLICY.bend) ----------

# Without a model: the CLI's own default.
def with_model(has: Bool, flag: String, model: String, rest: List<String>) -> List<String>:
  match has:
    case True{}:
      flag <> model <> rest
    case False{}:
      rest

def codex_args(+model: String, prompt: String) -> List<String>:
  "exec" <> with_model(Bool.not(String.is_empty(model)), "-m", model, ["--skip-git-repo-check", "--sandbox", Policy.codex_sandbox(Policy.chat()), prompt])

def claude_args(+model: String, prompt: String) -> List<String>:
  "-p" <> prompt <> Policy.claude_isolation() <> with_model(Bool.not(String.is_empty(model)), "--model", model,
    ["--allowedTools", Policy.claude_tools(Policy.chat()), "--output-format", "stream-json", "--verbose", "--include-partial-messages"])

# Where Claude finds the interphone: this server, at this project, conversation and turn.
def mcp_config(+w: Talk, +turn: String) -> String:
  "{\"mcpServers\":{\"laweditor\":{\"type\":\"http\",\"url\":\"http://" ++ Sys.address(cx(w)) ++ "/mcp/" ++ Places.safe(key(w)) ++ "/" ++ Places.safe(conv(w)) ++ "/" ++ Places.safe(turn) ++ "\"}}}"

# The chat that asks: before an action that isn't on its list, Claude asks the interphone and waits.
# LAWS.bend stays denied twice: Claude's own list (Policy.never) and the gate's first rule.
def asking_args(+w: Talk, +turn: String, prompt: String) -> List<String>:
  "-p" <> prompt <> Sys.with_each(Policy.claude_isolation_asking(), with_model(Bool.not(String.is_empty(model(w))), "--model", model(w),
    "--allowedTools" <> Policy.claude_tools(Policy.chat()) <> "--disallowedTools" <> Sys.with_each(Policy.never(),
    ["--permission-prompts", "host", "--permission-prompt-tool", "mcp__laweditor__approve", "--mcp-config", mcp_config(w, turn),
     "--output-format", "stream-json", "--verbose", "--include-partial-messages"])))

# How long Claude waits for the interphone's answer, in ms: a week. Left to itself it gives up after about
# a minute ("The operation timed out"), tries the action again and asks again, and nothing gets written
# for a person who takes their time to read what would change.
def patience() -> String:
  "MCP_TOOL_TIMEOUT=604800000"

# Codex answers all at once; Claude writes its answer to the turn's file as it goes, and a turn that asks
# has no time limit: while the person hasn't answered, Claude waits, and so does this.
def run_ai.at(codex: Bool, asks: Bool, +w: Talk, +turn: String, prompt: String) -> IO(U32 & String):
  match codex asks:
    case True{} _:
      Sys.run_in_quiet(dir(w), "codex", codex_args(model(w), prompt), 600000)
    case False{} True{}:
      Sys.run_to(dir(w), Places.turn(dir(w), turn), "env", patience() <> "claude" <> asking_args(w, turn, prompt), 4294967295)
    case False{} False{}:
      Sys.run_to(dir(w), Places.turn(dir(w), turn), "claude", claude_args(model(w), prompt), 600000)

def run_ai(+w: Talk, +turn: String, prompt: String) -> IO(U32 & String):
  run_ai.at(is_codex(w), asks(w), w, turn, prompt)

def mode_told(asks: Bool) -> String:
  match asks:
    case True{}:
      Policy.mode_section(Policy.Mode.AskBeforeChanges{})
    case False{}:
      Policy.mode_section(Policy.chat_mode())

# What the chat is told: CHAT.md, its mode, its skill (HEAR.md), then the conversation so far.
def prompt(+w: Talk, rules: String, skill: String, +log: String, extra: String) -> String:
  rules ++ "\n\n" ++ mode_told(asks(w)) ++ "\n\n" ++ skill ++ "\n\n## Chat\n\n" ++ Chat.with_project(Ev.talk(log), Ev.project(log)) ++ extra

# ---------- A project is born ----------

def promoted.at(none: Bool, +w: Talk, +key2: String, +name: String) -> IO(Talk):
  match none:
    case True{}:
      IO.pure(Talk, w)
    case False{}:
      do IO<Talk>:
        emit(moved(w, key2, key2), Ev.event("project", [key2, name]))
        return moved(w, key2, key2)

def promoted.try(draft: Bool, +w: Talk, +log: String) -> IO(Talk):
  match draft:
    case False{}:
      IO.pure(Talk, w)
    case True{}:
      do IO<Talk>:
        +key2 : String <- Proj.promote(key(w), Ev.name_or_title(log))
        promoted.at(String.is_empty(key2), w, key2, Ev.name_or_title(log))

# A conversation with no project becomes one once it has a rule or a file: named by the chat (its
# PROJECT: line), or by the person's first message. Its folder takes the name, so the talk goes on from there.
def promoted(+w: Talk) -> IO(Talk):
  do IO<Talk>:
    +log : String <- log_of(w)
    promoted.try((String.eq(key(w), conv(w)) && String.is_empty(Ev.project(log))), w, log)

# ---------- Bend checks what the turn changed (BUILD.bend) ----------

# One run's event, when it had something to say. Answers whether it failed.
def built.said(ran: Bool, +w: Talk, +kind: String, +turn: String, +out: String) -> IO(Bool):
  match ran:
    case False{}:
      IO.pure(Bool, False{})
    case True{}:
      do IO<Bool>:
        emit(w, Ev.event(kind, [turn, Build.state(out), Build.text(out)]))
        return Build.failed(out)

# The page is bundled only when the check found no error: with one, the bundle would say it again.
def built.page(broke: Bool, +w: Talk, +turn: String) -> IO(Bool):
  match broke:
    case True{}:
      IO.pure(Bool, True{})
    case False{}:
      do IO<Bool>:
        +out : String <- Build.page(dir(w), Sys.told(cx(w), "web"))
        built.said(Build.ran(out), w, "page", turn, out)

def built.at(acted: Bool, +w: Talk, +turn: String) -> IO(Bool):
  match acted:
    case False{}:
      IO.pure(Bool, False{})
    case True{}:
      do IO<Bool>:
        placed : String <- Build.web(dir(w), Sys.told(cx(w), "web"))
        +out : String <- Build.check(dir(w))
        +broke : Bool <- built.said(Build.ran(out), w, "check", turn, out)
        built.page(broke, w, turn)

# After a reply that acted on the project (ASK.acted: an edit, a new file, a command that ran), Bend
# checks its .bend files and bundles its page. Answers whether Bend found an error: the chat then gets
# another turn to fix it (step, below).
def built(+w: Talk, +turn: String) -> IO(Bool):
  do IO<Bool>:
    out : String <- Sys.read_file(Places.turn(dir(w), turn))
    built.at(Ask.acted(out), w, turn)

# ---------- The laws it heard (HEAR.bend) ----------

def law_question(+turn: String, +i: Nat) -> String:
  "law-" ++ turn ++ "-" ++ Nat.show(i)

# The sentence goes to the end of RULES.md, on a line of its own.
def add_sentence(+w: Talk, sentence: String) -> IO(String):
  Sys.sh("f=\"$0/RULES.md\"; [ -s \"$f\" ] && [ -n \"$(tail -c 1 \"$f\")\" ] && echo >> \"$f\"; printf '%s\\n' \"$1\" >> \"$f\"", [dir(w), sentence], 5000)

def hear.said(adds: Bool, +w: Talk, +q: String, sentence: String) -> IO(Unit):
  match adds:
    case True{}:
      do IO<Unit>:
        done : String <- add_sentence(w, sentence)
        emit(w, Ev.event("note", [q, "busy", "Added to the document. Writing its law…"]))
    case False{}:
      emit(w, Ev.event("note", [q, "none", "Not added."]))

# A new sentence is asked (every conversation starts so), or, after Always add, added without asking.
def hear.new(is_new: Bool, must_ask: Bool, +w: Talk, +q: String, +sentence: String) -> IO(Unit):
  match is_new must_ask:
    case False{} _:
      IO.pure(Unit, Unit{})
    case True{} True{}:
      do IO<Unit>:
        +said : String <- ask(w, q, sentence)
        hear.said(Hear.adds(Ev.hear_answer(said)), w, q, sentence)
    case True{} False{}:
      do IO<Unit>:
        emit(w, Ev.event("ask", [q, sentence]))
        emit(w, Ev.event("answer", [q, Ev.add_word()]))
        hear.said(True{}, w, q, sentence)

def hear.one(+w: Talk, +q: String, +sentence: String) -> IO(Unit):
  do IO<Unit>:
    rules : String <- Sys.read_file(dir(w) ++ "/RULES.md")
    +log : String <- log_of(w)
    hear.new(Hear.is_new(sentence, rules ++ "\n" ++ Ev.heard(log)), Hear.must_ask(Ev.hear_mode(log)), w, q, sentence)

# Every sentence the reply proposes (its LAW: lines), one question at a time, in order.
def hear(n: Nat, +i: Nat, +w: Talk, +turn: String, +answer: String) -> IO(Unit):
  match n:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+m:
      do IO<Unit>:
        hear.one(w, law_question(turn, i), Hear.proposal(answer, i))
        hear(m, 1n+i, w, turn, answer)

def law_note(good: Bool, text: String) -> List<&2, String>:
  match good:
    case True{}:
      ["ok", "In the document. Its law compiles: Bend checked it."]
    case False{}:
      ["error", text]

def laws.write(added: Bool, +w: Talk, +q: String, sentence: String) -> IO(Unit):
  match added:
    case False{}:
      IO.pure(Unit, Unit{})
    case True{}:
      do IO<Unit>:
        +r : String <- Law.write(cx(w), dir(w), ai(w), sentence)
        emit(w, Ev.event("note", q <> law_note(Law.good(r), Law.text(r))))

def laws.one(+w: Talk, +q: String, sentence: String) -> IO(Unit):
  do IO<Unit>:
    +log : String <- log_of(w)
    laws.write(String.eq(Ev.noted(log, q), "busy"), w, q, sentence)

# The laws of the sentences just added, one at a time, after every question: the person isn't held while
# the law agent works.
def laws(n: Nat, +i: Nat, +w: Talk, +turn: String, +answer: String) -> IO(Unit):
  match n:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+m:
      do IO<Unit>:
        laws.one(w, law_question(turn, i), Hear.proposal(answer, i))
        laws(m, 1n+i, w, turn, answer)

# ---------- The mode it offers (OFFER.bend) ----------

def switch_word() -> String: "switch"
def stay_word() -> String: "stay"

def offer.said(+switches: Bool, +w: Talk, +q: String) -> IO(Bool):
  do IO<Bool>:
    emit(w, Ev.event("note", [q, Sys.pick(switches, "ok", "none"), Sys.pick(switches, "Switched to Ask before changes.", "Stayed in Only read.")]))
    return switches

def offer.at(offers: Bool, +w: Talk, +q: String) -> IO(Bool):
  match offers:
    case False{}:
      IO.pure(Bool, False{})
    case True{}:
      do IO<Bool>:
        +said : String <- ask(w, q, "Switch to Ask before changes?\nSo the chat can build it. It asks before each change.")
        offer.said(String.eq(said, switch_word()), w, q)

# In a mode that doesn't ask, a MODE: line becomes Switch / Stay. Only an AI that can ask is offered it.
def offer(+w: Talk, +turn: String, answer: String) -> IO(Bool):
  offer.at((Offer.offers(answer) && Bool.not(asks(w)) && Policy.can_ask(is_codex(w))), w, "mode-" ++ turn)

# ---------- One turn ----------
# What comes after a turn: go on with another (the person switched the mode: the chat builds what it
# offered; or Bend found an error in what the chat wrote: the chat reads it in the talk and fixes it), or stop.
type Step is Data:
  Step{again: Bool, talk: Talk, extra: String}

def step(switched: Bool, broke: Bool, +w: Talk) -> Step:
  match switched broke:
    case True{} _:
      Step{True{}, in_mode(w, Policy.mode_index(Policy.Mode.AskBeforeChanges{})), "\n" ++ Offer.told()}
    case False{} True{}:
      Step{True{}, w, ""}
    case False{} False{}:
      Step{False{}, w, ""}

# The chat answered. In order: its project, if this made one; Bend's check of what it changed; the laws
# it heard; the mode it offers; then the laws are written, without holding the talk.
def replied(+w: Talk, +turn: String, +answer: String) -> IO(Step):
  do IO<Step>:
    emit(w, Ev.event("reply", [turn, answer]))
    +w2 : Talk <- promoted(w)
    +broke : Bool <- built(w2, turn)
    hear(Hear.count(answer), 0n, w2, turn, answer)
    +w3 : Talk <- promoted(w2)
    +switched : Bool <- offer(w3, turn, answer)
    IO.spawn(Unit, laws(Hear.count(answer), 0n, w3, turn, answer))
    return step(switched, broke, w3)

def answer_of.at(codex: Bool, +out: String) -> String:
  match codex:
    case True{}:
      out
    case False{}:
      Ask.result_or(out)

def answer_of(+w: Talk, +out: String) -> String:
  Sys.pick(String.is_empty(String.trim(answer_of.at(is_codex(w), out))), "The agent didn't answer.", String.trim(answer_of.at(is_codex(w), out)))

def ended.at(stopped: Bool, cant: Bool, +w: Talk, +turn: String, +out: String) -> IO(Step):
  match stopped cant:
    case True{} _:
      do IO<Step>:
        emit(w, Ev.event("stopped", [turn]))
        return Step{False{}, w, ""}
    case False{} True{}:
      do IO<Step>:
        emit(w, Ev.event("fail", [turn, "Could not start the agent: " ++ out]))
        return Step{False{}, w, ""}
    case False{} False{}:
      replied(w, turn, answer_of(w, out))

def ended(+w: Talk, +turn: String, agent: U32 & String, +stopped: String) -> IO(Step):
  (+code, +out) = agent
  ended.at(Bool.not(String.is_empty(stopped)), U32.is_eq(code, 127), w, turn, out)

# The law agent may add a definition to the project's code (AGENT.md), and so may the chat: a turn waits
# while a law is being written (EVENTS.writing), up to the law agent's own time limit and a little more.
def calm(fuel: Nat, busy: Bool, +w: Talk) -> IO(Unit):
  match fuel busy:
    case 0n _:
      IO.pure(Unit, Unit{})
    case 1n+f False{}:
      IO.pure(Unit, Unit{})
    case 1n+f True{}:
      do IO<Unit>:
        IO.sleep(300)
        +log : String <- log_of(w)
        calm(f, Ev.writing(log), w)

# Bend's guide, as the installed bend prints it, where the chat can read it without asking (PLACES.guide).
# Bend's guide, and how a page is written in Bend (harness/web/WEB.md, with Web.bend), where the chat reads them.
def guide(+w: Talk) -> IO(String):
  do IO<String>:
    placed : String <- Build.web(dir(w), Sys.told(cx(w), "web"))
    Sys.sh("bend guide > \"$0\" 2>/dev/null; true", [Places.guide(dir(w))], 20000)

def one(+w: Talk, extra: String) -> IO(Step):
  do IO<Step>:
    +turn : String <- Sys.new_id()
    emit(w, Ev.event("turn", [turn, ai(w), model(w), U32.show(mode(w))]))
    state(w, Ev.working())
    +before : String <- log_of(w)
    calm(2400n, Ev.writing(before), w)
    wrote : String <- guide(w)
    rules : String <- Sys.read_file(Sys.told(cx(w), "CHAT.md"))
    skill : String <- Sys.read_file(Sys.told(cx(w), "HEAR.md"))
    +log : String <- log_of(w)
    agent : U32 & String <- run_ai(w, turn, prompt(w, rules, skill, log, extra))
    stopped : String <- Sys.read_file(Places.stopped(dir(w), turn))
    ended(w, turn, agent, stopped)

def next(s: Step) -> Talk:
  match s:
    case Step{again, talk, extra}:
      talk

def more(s: Step) -> String:
  match s:
    case Step{again, talk, extra}:
      extra

def goes_on(s: Step) -> Bool:
  match s:
    case Step{again, talk, extra}:
      again

# The turns one message sets off: one, and another each time the person switches the mode for the chat to
# build what it offered (fuel: at most a few).
def turns(fuel: Nat, go: Bool, +w: Talk, extra: String) -> IO(Unit):
  match fuel go:
    case 0n _:
      state(w, Ev.idle())
    case 1n+f False{}:
      state(w, Ev.idle())
    case 1n+f True{}:
      do IO<Unit>:
        +s : Step <- one(w, extra)
        turns(f, goes_on(s), next(s), more(s))

# ---------- The person writes ----------

def settings(+ai: String, +model: String, +mode: U32) -> String:
  ai ++ "\t" ++ model ++ "\t" ++ U32.show(mode)

def say.title(first: Bool, +w: Talk, +text: String) -> IO(Unit):
  match first:
    case True{}:
      Sys.write_file(Places.title(dir(w), conv(w)), String.take(String.trim(Sys.nth(String.lines(text), 0n)), 60n))
    case False{}:
      IO.pure(Unit, Unit{})

def say.go(can: Bool, +w: Talk, +text: String, first: Bool) -> IO(String):
  match can:
    case False{}:
      IO.pure(String, "busy")
    case True{}:
      do IO<String>:
        emit(w, Ev.event("me", [text]))
        say.title(first, w, text)
        Sys.write_file(Places.settings(dir(w), conv(w)), settings(ai(w), model(w), mode(w)))
        state(w, Ev.working())
        IO.spawn(Unit, turns(4n, True{}, w, ""))
        return "ok\t" ++ key(w)

def say.in(bad: Bool, +w: Talk, +text: String) -> IO(String):
  match bad:
    case True{}:
      IO.pure(String, "unknown")
    case False{}:
      do IO<String>:
        +log : String <- log_of(w)
        say.go(Ev.can_say(log), w, text, Ev.is_new(log))

def number(m: Maybe<&2, U32>) -> U32:
  match m:
    case None{}:
      0
    case Some{n}:
      n

def is_ai(+ai: String) -> Bool:
  (String.eq(ai, "claude") || String.eq(ai, "codex"))

# The AI, its model and the mode, as the body's first line gives them, split by tabs.
def talk_of(+cx: Sys.Ctx, +key: String, +dir: String, +conv: String, +head: String) -> Talk:
  Talk{cx, key, dir, conv, Sys.nth(String.split(head, Ev.tab()), 0n), Sys.nth(String.split(head, Ev.tab()), 1n), number(U32.read(Sys.nth(String.split(head, Ev.tab()), 2n)))}

# The body's first line: the AI, its model and the mode. The rest: what the person wrote.
def say.read(+cx: Sys.Ctx, +key: String, +dir: String, +conv: String, +head: String, +text: String) -> IO(String):
  say.in((String.is_empty(dir) || String.is_empty(String.trim(text)) || Bool.not(is_ai(Sys.nth(String.split(head, Ev.tab()), 0n)))), talk_of(cx, key, dir, conv, head), text)

# POST /api/c/<key>/<conversation>/say. A conversation with no project names itself as one (its key
# is its own name): it gets its folder here, with nothing asked. Answers "ok" and the project's key,
# "busy" while the chat answers or a question waits, "unknown" for a project that isn't there.
def say(+cx: Sys.Ctx, +key: String, +conv: String, +body: String) -> IO(String):
  do IO<String>:
    +dir : String <- Proj.ensure(key, conv)
    say.read(cx, key, dir, conv, Sys.nth(String.lines(body), 0n), String.drop(body, 1n+String.length(Sys.nth(String.lines(body), 0n))))

def again.go(can: Bool, +w: Talk) -> IO(String):
  match can:
    case False{}:
      IO.pure(String, "busy")
    case True{}:
      do IO<String>:
        state(w, Ev.working())
        IO.spawn(Unit, turns(4n, True{}, w, ""))
        return "ok\t" ++ key(w)

def again.in(bad: Bool, +w: Talk) -> IO(String):
  match bad:
    case True{}:
      IO.pure(String, "unknown")
    case False{}:
      do IO<String>:
        +log : String <- log_of(w)
        again.go((Ev.can_say(log) && Bool.not(String.is_empty(Ev.first(log, "me")))), w)

# POST /api/c/<key>/<conversation>/again, body: the AI, its model and the mode. The chat answers the
# conversation as it stands once more (after a reply that failed or was stopped): nothing new is said.
def again(+cx: Sys.Ctx, +key: String, +conv: String, +body: String) -> IO(String):
  do IO<String>:
    +dir : String <- Proj.dir(key)
    again.in((String.is_empty(dir) || Bool.not(is_ai(Sys.nth(String.split(body, Ev.tab()), 0n)))), talk_of(cx, key, dir, conv, Sys.nth(String.lines(body), 0n)))

# ---------- The person runs a command themselves (!) ----------

def ran.done(+w: Talk, +command: String, r: U32 & String) -> IO(String):
  (code, out) = r
  do IO<String>:
    emit(w, Ev.event("ran", [command, U32.show(code), String.take(String.trim(out), 20000n)]))
    state(w, Ev.idle())
    return "ok\t" ++ key(w)

def ran.go(can: Bool, forbidden: Bool, +w: Talk, +command: String, first: Bool) -> IO(String):
  match can forbidden:
    case False{} _:
      IO.pure(String, "busy")
    case True{} True{}:
      IO.pure(String, "readonly")
    case True{} False{}:
      do IO<String>:
        say.title(first, w, "!" ++ command)
        state(w, Ev.working())
        r : U32 & String <- Sys.run_in(dir(w), "sh", ["-c", command], 120000)
        ran.done(w, command, r)

def ran.in(bad: Bool, +w: Talk, +command: String) -> IO(String):
  match bad:
    case True{}:
      IO.pure(String, "unknown")
    case False{}:
      do IO<String>:
        +log : String <- log_of(w)
        ran.go(Ev.can_say(log), Gate.mode_forbids("Bash", Policy.mode_at(mode(w))), w, command, Ev.is_new(log))

def ran.read(+cx: Sys.Ctx, +key: String, +dir: String, +conv: String, +head: String, +command: String) -> IO(String):
  ran.in((String.is_empty(dir) || String.is_empty(String.trim(command))), talk_of(cx, key, dir, conv, head), String.trim(command))

# POST /api/c/<key>/<conversation>/run, body: the AI, model and mode on the first line, then a command.
# It runs in the project's folder, as the person: nothing is asked, since they are the one asking. A mode
# that only reads runs none (GATE.bend: mode_forbids) and answers "readonly". What it printed is kept in
# the conversation (the chat reads it too), up to two minutes of work.
def ran(+cx: Sys.Ctx, +key: String, +conv: String, +body: String) -> IO(String):
  do IO<String>:
    +dir : String <- Proj.ensure(key, conv)
    ran.read(cx, key, dir, conv, Sys.nth(String.lines(body), 0n), String.drop(body, 1n+String.length(Sys.nth(String.lines(body), 0n))))

# ---------- The person stops it ----------

def stop.word(is_law: Bool, is_mode: Bool) -> String:
  match is_law is_mode:
    case True{} _:
      Ev.dont_word()
    case False{} True{}:
      stay_word()
    case False{} False{}:
      Gate.deny_word()

def stop.answer(none: Bool, +dir: String, +conv: String, +q: String) -> IO(Unit):
  match none:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      Sys.write_file(Places.answer(dir, conv, q), stop.word(Ev.is_law(q), Ev.is_mode(q)))

def stop.turn(none: Bool, +dir: String, +turn: String) -> IO(Unit):
  match none:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      do IO<Unit>:
        Sys.write_file(Places.stopped(dir, turn), "stopped")
        done : String <- Sys.sh("p=$(cat \"$0\" 2>/dev/null); [ -n \"$p\" ] && { pkill -P \"$p\" 2>/dev/null; kill \"$p\" 2>/dev/null; }; true", [Places.turn(dir, turn) ++ ".pid"], 5000)
        return Unit{}

# POST /api/c/<key>/<conversation>/stop: the turn's process ends, and a question that waits is answered
# no. The turn's own computation writes the events (stopped), as for any other end.
def stop(+dir: String, +conv: String) -> IO(String):
  do IO<String>:
    +log : String <- Sys.read_file(Places.log(dir, conv))
    stop.turn(String.is_empty(Ev.running(log)), dir, Ev.running(log))
    stop.answer(String.is_empty(Ev.asking(log)), dir, conv, Ev.asking(log))
    return "ok"

# ---------- What a window reads and sends ----------

# GET /api/c/<key>/<conversation>/events/<n>: the events after the first n.
def events(+dir: String, +conv: String, n: Nat) -> IO(String):
  do IO<String>:
    log : String <- Sys.read_file(Places.log(dir, conv))
    return Ev.after(log, n)

# GET /api/c/<key>/<conversation>/now: what goes on, read from the conversation by EVENTS.bend: the turn
# that runs, the question that waits and the project's name, split by tabs (each empty when there is none).
# A window asks this instead of reading the whole conversation itself: the answer is short however long
# the conversation got.
def now(+dir: String, +conv: String) -> IO(String):
  do IO<String>:
    +log : String <- Sys.read_file(Places.log(dir, conv))
    return Ev.running(log) ++ SCon{Ev.tab(), Ev.asking(log) ++ SCon{Ev.tab(), Ev.project(log)}}

# POST /api/c/<key>/<conversation>/answer/<question>, body: the answer's word. The engine, which waits,
# reads it and writes the event.
def answer(+dir: String, +conv: String, +q: String, word: String) -> IO(String):
  do IO<String>:
    Sys.write_file(Places.answer(dir, conv, q), String.trim(word))
    return "ok"

# ---------- The interphone (GATE.bend) ----------
# Claude asks POST /mcp/<key>/<conversation>/<turn> before an action that isn't on its list, and waits.
# The gate decides (GATE.rules): a law or the mode refuses, the session allows, or the person is asked,
# as any other question of the conversation.

def gate_talk(+dir: String, +conv: String) -> Talk:
  Talk{Sys.Ctx{"", 0, 0}, "", dir, conv, "claude", "", 1}

def mcp.heard(+w: Talk, +q: String, +msg: String, +session: String, +said: String) -> IO(String):
  do IO<String>:
    emit(w, Ev.event("note", [q, Sys.pick(Gate.lets_run(said), "ok", "none"), Gate.note(said)]))
    Sys.write_file(Places.allowed(dir(w), conv(w)), Gate.session_after(session, msg, said))
    return Gate.answer(msg, said)

def mcp.person(+w: Talk, +turn: String, +msg: String, +session: String) -> IO(String):
  do IO<String>:
    +log : String <- log_of(w)
    +q : String = "gate-" ++ turn ++ "-" ++ Nat.show(Ev.count(log))
    +said : String <- ask(w, q, Gate.question(msg))
    mcp.heard(w, q, msg, session, said)

def mcp.by(ask: Bool, r: Gate.Rule, +w: Talk, +turn: String, +msg: String, +session: String) -> IO(String):
  match ask:
    case True{}:
      mcp.person(w, turn, msg, session)
    case False{}:
      IO.pure(String, Gate.now(msg, r))

# Only the chat that asks reaches the interphone, so its mode is Ask before changes.
def mcp.call(+dir: String, +conv: String, +turn: String, +msg: String) -> IO(String):
  do IO<String>:
    +session : String <- Sys.read_file(Places.allowed(dir, conv))
    mcp.by(Gate.is_ask(Gate.rule_for(msg, Policy.Mode.AskBeforeChanges{}, session)), Gate.rule_for(msg, Policy.Mode.AskBeforeChanges{}, session), gate_talk(dir, conv), turn, msg, session)

# ---------- What the person allowed (the mode's menu) ----------

def allowed(+dir: String, +conv: String) -> IO(String):
  Sys.read_file(Places.allowed(dir, conv))

def allowed_less.write(+dir: String, +conv: String, +left: String) -> IO(String):
  do IO<String>:
    Sys.write_file(Places.allowed(dir, conv), left)
    return left

# POST …/allowed, body: one action to take back (GATE.allowed_without), or "all". Answers what is left.
def allowed_less(+dir: String, +conv: String, body: String) -> IO(String):
  do IO<String>:
    +text : String <- Sys.read_file(Places.allowed(dir, conv))
    allowed_less.write(dir, conv, Gate.allowed_without(text, body))

# ---------- A turn's work (ASK.bend reads the turn's file) ----------

def progress(+dir: String, turn: String) -> IO(String):
  do IO<String>:
    text : String <- Sys.read_file(Places.turn(dir, turn))
    return Ask.progress(text)

# A turn ended when the conversation says how: it replied, it was stopped, or it could not start (a server
# stopped in the middle of a turn writes "stopped" for it when it starts again). Its events' fields never
# hold a tab of their own (EVENTS.bend writes it \t), so "reply<tab><turn><tab>" is that event and no other.
def turn_over(+log: String, +turn: String) -> Bool:
  (String.contains(log, "reply\t" ++ turn ++ "\t") || String.contains(log, "stopped\t" ++ turn) || String.contains(log, "fail\t" ++ turn ++ "\t"))

def work.keep(keep: Bool, +file: String, +w: String) -> IO(String):
  match keep:
    case True{}:
      do IO<String>:
        Sys.write_file(file, w)
        return w
    case False{}:
      IO.pure(String, w)

def work.read(+dir: String, +conv: String, +turn: String) -> IO(String):
  do IO<String>:
    text : String <- Sys.read_file(Places.turn(dir, turn))
    log : String <- Sys.read_file(Places.log(dir, conv))
    +w : String = Ask.work(text)
    work.keep((turn_over(log, turn) && Bool.not(String.is_empty(w))), Places.work(dir, turn), w)

def work.at(kept: Bool, +dir: String, +conv: String, +turn: String, +k: String) -> IO(String):
  match kept:
    case True{}:
      IO.pure(String, k)
    case False{}:
      work.read(dir, conv, turn)

# GET work/<turn>: what the turn did (ASK.bend reads the turn's file). A turn that runs is read again at
# each ask, as its file grows; one that ended is read once and kept (Places.work), so a conversation opened
# again doesn't read every turn's file again.
def work(+dir: String, +conv: String, +turn: String) -> IO(String):
  do IO<String>:
    +k : String <- Sys.read_file(Places.work(dir, turn))
    work.at(Bool.not(String.is_empty(k)), dir, conv, turn, k)

def output(+dir: String, turn: String, n: String) -> IO(String):
  do IO<String>:
    text : String <- Sys.read_file(Places.turn(dir, turn))
    return Ask.output(text, Ask.to_u32(n))
