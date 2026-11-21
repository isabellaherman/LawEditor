# LawEditor in the terminal: the same conversations as the page, as text.
#
#   laweditor          a new conversation (or, in a folder that is a project, one in it)
#   laweditor here     this folder becomes a project, and the conversation is in it
#   laweditor list     the conversations, and nothing else
#   laweditor timers   the timers the chats set (engine/CLOCK.bend); then "timers pause <n>", "resume <n>",
#                      "test <n>" (its turn starts now) and "stop <n>" (it is taken away)
#
# It is a window, like the page: it sends what the person writes and answers to the server
# (engine/TURN.bend conducts the turn) and prints the conversation's events (harness/EVENTS.bend).
# So what is done here shows in the app, and what the app does shows here. The server has to be running
# (bun run start); LAWEDITOR_PORT says where, LAWEDITOR_AI which AI (claude, or codex).
#
# Inside: write and press Enter. !command runs a command in the project. /new, /list, /open <n>,
# /mode (Only read or Ask before changes), /quit. A question is answered with its letter.

import Base
import ./engine/SYS.bend as Sys
import ./harness/EVENTS.bend as Ev
import ./harness/HEAR.bend as Hear
import ./harness/OFFER.bend as Offer
import ./harness/ASK.bend as Ask
import ./harness/CHAT.bend as Chat
import ./harness/GATE.bend as Gate
import ./harness/POLICY.bend as Policy
import ./harness/TIMER.bend as Timer
import ./harness/SKILL.bend as Skill

# ---------- The window's own state ----------
# key: the conversation's project ("" while it has none: it then names itself). seen: the events printed.
type Cli is Data:
  Cli{port: String, ai: String, key: String, conv: String, seen: Nat, mode: U32}

def port(c: Cli) -> String:
  match c:
    case Cli{port, ai, key, conv, seen, mode}:
      port

def ai(c: Cli) -> String:
  match c:
    case Cli{port, ai, key, conv, seen, mode}:
      ai

def conv(c: Cli) -> String:
  match c:
    case Cli{port, ai, key, conv, seen, mode}:
      conv

def seen(c: Cli) -> Nat:
  match c:
    case Cli{port, ai, key, conv, seen, mode}:
      seen

def mode(c: Cli) -> U32:
  match c:
    case Cli{port, ai, key, conv, seen, mode}:
      mode

# The project a request names: the conversation's own name while it has no project.
def key.or(+key: String, +conv: String) -> String:
  Sys.pick(String.is_empty(key), conv, key)

def key(c: Cli) -> String:
  match c:
    case Cli{port, ai, key, conv, seen, mode}:
      key.or(key, conv)

def at_key(c: Cli, key2: String) -> Cli:
  match c:
    case Cli{port, ai, key, conv, seen, mode}:
      Cli{port, ai, key2, conv, seen, mode}

def at_seen(c: Cli, seen2: Nat) -> Cli:
  match c:
    case Cli{port, ai, key, conv, seen, mode}:
      Cli{port, ai, key, conv, seen2, mode}

def at_mode(c: Cli, mode2: U32) -> Cli:
  match c:
    case Cli{port, ai, key, conv, seen, mode}:
      Cli{port, ai, key, conv, seen, mode2}

def at_conv(c: Cli, key2: String, conv2: String) -> Cli:
  match c:
    case Cli{port, ai, key, conv, seen, mode}:
      Cli{port, ai, key2, conv2, 0n, mode}

# ---------- Talking to the server ----------
# curl carries each request; what is sent goes in through its stdin, never on the command line.

def url(+c: Cli, path: String) -> String:
  "http://127.0.0.1:" ++ port(c) ++ path

def conversation(+c: Cli, path: String) -> String:
  url(c, "/api/c/" ++ key(c) ++ "/" ++ conv(c) ++ "/" ++ path)

def got(r: Result<&1, &1, U32 & String, U32 & (String & String)>) -> String:
  match r:
    case Fail{e}:
      ""
    case Done{(code, (out, err))}:
      out

def get(address: String) -> IO(String):
  do IO<String>:
    r : Result<&1, &1, U32 & String, U32 & (String & String)> <- Process.run("curl", ["-s", "-m", "30", address], "", 4194304, 40000)
    return got(r)

def post(address: String, body: String) -> IO(String):
  do IO<String>:
    r : Result<&1, &1, U32 & String, U32 & (String & String)> <- Process.run("curl", ["-s", "-m", "30", "-X", "POST", "--data-binary", "@-", address], body, 4194304, 40000)
    return got(r)

def settings(+c: Cli) -> String:
  ai(c) ++ "\t\t" ++ U32.show(mode(c))

# ---------- What an event looks like, in text ----------

# What the person reads of a reply: without its LAW:, MODE:, PLAN:, PROJECT:, TIMER: and SKILL: lines.
def shown(text: String) -> String:
  Skill.words(Timer.words(Offer.words(Hear.words(Ask.plan_words(Chat.project_words(text))))))

def indent.go(ls: List<&2, String>) -> String:
  match ls:
    case Nil{}:
      ""
    case h <> t:
      "  " ++ h ++ "\n" ++ indent.go(t)

def indent(text: String) -> String:
  indent.go(String.lines(text))

def note_mark(+state: String) -> String:
  Sys.pick(String.eq(state, "ok"), "  ✓ ", Sys.pick(String.eq(state, "error"), "  ✗ ", "  · "))

def keys(+q: String) -> String:
  Sys.pick(Ev.is_law(q), "  [a] Add   [A] Always add   [d] Don't add",
  Sys.pick(Ev.is_mode(q), "  [s] Switch   [n] Stay",
  Sys.pick(Ev.is_timer(q), "  [y] Set timer   [n] Don't set",
  Sys.pick(Ev.is_skill(q), "  [y] Save skill   [n] Don't save",
  "  [y] Allow   [s] Allow for this session   [n] Don't allow"))))

# What is said of a file that isn't Bend, on a line of its own ("" when nothing is).
def gate_note(+note: String) -> String:
  Sys.pick(String.is_empty(note), "", "  ! " ++ note ++ "\n")

# A gate question's text is three parts (GATE.question): the question; how to draw what would change, with
# what is said of a file that isn't Bend (the third piece of that line); and what would change.
def gate_text(+text: String) -> String:
  "  ? " ++ Sys.nth(String.lines(text), 0n) ++ "\n" ++ gate_note(Sys.nth(String.split(Sys.nth(String.lines(text), 1n), Ev.tab()), 2n)) ++ indent(String.join(Ev.after.drop(String.lines(text), 2n), "\n"))

def ask_text(+q: String, +text: String) -> String:
  Sys.pick(Ev.is_law(q), "  Law? \"" ++ text ++ "\"\n",
  Sys.pick((Ev.is_mode(q) || Ev.is_timer(q)), "  ? " ++ Sys.nth(String.lines(text), 0n) ++ "\n" ++ indent(String.join(Ev.after.drop(String.lines(text), 1n), "\n")),
  gate_text(text)))

# What Bend said of the project after a reply changed it (engine/BUILD.bend): its check, and its page.
# A text's first line is the file (or the files); the rest is what Bend said.
def bend_said(+text: String) -> String:
  indent(String.join(Ev.after.drop(String.lines(text), 1n), "\n"))

def check_text(+state: String, +text: String) -> String:
  Sys.pick(String.eq(state, "ok"), "  ✓ Bend checked " ++ Sys.nth(String.lines(text), 0n) ++ ": no errors\n",
  "  ✗ Bend found an error in " ++ Sys.nth(String.lines(text), 0n) ++ "\n" ++ bend_said(text))

# at: where the project's page is served ("" when the pages door isn't open).
def page_at(+at: String) -> String:
  Sys.pick(String.is_empty(at), "", "  ▸ " ++ at ++ "\n")

def page_text(+state: String, +text: String, +at: String) -> String:
  Sys.pick(String.eq(state, "ok"), "  ✓ Bend bundled " ++ Sys.nth(String.lines(text), 0n) ++ "\n" ++ page_at(at),
  Sys.pick(String.eq(state, "warn"), "  ! " ++ text ++ "\n" ++ page_at(at),
  "  ✗ Bend could not bundle " ++ Sys.nth(String.lines(text), 0n) ++ "\n" ++ bend_said(text)))

# One event, as lines to print ("" for the ones that say nothing here). at: the project's page (page_text).
def show(+l: String, +at: String) -> String:
  Sys.pick(Ev.is_a(l, "me"), "❯ " ++ Ev.field(l, 0n) ++ "\n",
  Sys.pick(Ev.is_a(l, "turn"), "  ● " ++ Ev.field(l, 1n) ++ " is answering…\n",
  Sys.pick(Ev.is_a(l, "reply"), "\n" ++ shown(Ev.field(l, 1n)) ++ "\n\n",
  Sys.pick(Ev.is_a(l, "fail"), "  ✗ " ++ Ev.field(l, 1n) ++ "\n",
  Sys.pick(Ev.is_a(l, "stopped"), "  · Stopped.\n",
  Sys.pick(Ev.is_a(l, "ask"), ask_text(Ev.field(l, 0n), Ev.field(l, 1n)),
  Sys.pick(Ev.is_a(l, "note"), note_mark(Ev.field(l, 1n)) ++ Ev.field(l, 2n) ++ "\n",
  Sys.pick(Ev.is_a(l, "project"), "  ▸ " ++ Ev.field(l, 1n) ++ "  (" ++ Ev.field(l, 0n) ++ ")\n",
  Sys.pick(Ev.is_a(l, "check"), check_text(Ev.field(l, 1n), Ev.field(l, 2n)),
  Sys.pick(Ev.is_a(l, "page"), page_text(Ev.field(l, 1n), Ev.field(l, 2n), at),
  Sys.pick(Ev.is_a(l, "ran"), "$ " ++ Ev.field(l, 0n) ++ "\n" ++ indent(Ev.field(l, 2n)),
  Sys.pick(Ev.is_a(l, "timer"), "◷ Timer, " ++ Ev.field(l, 1n) ++ ":\n" ++ indent(Ev.field(l, 2n)),
  ""))))))))))))

def show_all(ls: List<&2, String>, +at: String) -> String:
  match ls:
    case Nil{}:
      ""
    case +h <> t:
      show(h, at) ++ show_all(t, at)

# Is a page among these events? Only then is the pages door asked where it is.
def has_page(ls: List<&2, String>) -> Bool:
  match ls:
    case Nil{}:
      False{}
    case +h <> t:
      (Ev.is_a(h, "page") || has_page(t))

# ---------- The lists ----------

def row(+l: String, +n: Nat) -> String:
  "  " ++ Nat.show(n) ++ "  " ++ Sys.pick(String.eq(Sys.nth(String.split(l, Ev.tab()), 3n), "working"), "● ", Sys.pick(String.eq(Sys.nth(String.split(l, Ev.tab()), 3n), "asking"), "◆ ", "  ")) ++ Sys.nth(String.split(l, Ev.tab()), 4n) ++ Sys.pick(String.is_empty(Sys.nth(String.split(l, Ev.tab()), 1n)), "", "   [" ++ Sys.nth(String.split(l, Ev.tab()), 1n) ++ "]") ++ "\n"

def rows(ls: List<&2, String>, +n: Nat) -> String:
  match ls:
    case Nil{}:
      ""
    case +h <> t:
      row(h, n) ++ rows(t, 1n+n)

# The conversations, numbered from 1: ● works, ◆ waits for you; the project's name in brackets.
def listing(text: String) -> String:
  "\n  Conversations\n" ++ rows(Ev.lines(text), 1n) ++ "\n"

# Where a conversation is now, from the server's list (its project gets a folder once it is one).
def find.pick(hit: Bool, +l: String, +later: String) -> String:
  match hit:
    case True{}:
      Sys.nth(String.split(l, Ev.tab()), 0n)
    case False{}:
      later

def find.go(ls: List<&2, String>, +conv: String) -> String:
  match ls:
    case Nil{}:
      ""
    case +h <> t:
      find.pick(String.eq(Sys.nth(String.split(h, Ev.tab()), 2n), conv), h, find.go(t, conv))

def follow.at(none: Bool, c: Cli, k: String) -> Cli:
  match none:
    case True{}:
      c
    case False{}:
      at_key(c, k)

def follow(+c: Cli, +list: String) -> Cli:
  follow.at(String.is_empty(find.go(Ev.lines(list), conv(c))), c, find.go(Ev.lines(list), conv(c)))

def pick_cli(c: Bool, a: Cli, b: Cli) -> Cli:
  match c:
    case True{}:
      a
    case False{}:
      b

# ---------- One step of the window ----------
# go: False when the person leaves. f: the keyboard.
type Step is Type:
  Step{go: Bool, c: Cli, f: File}

def typed.at(none: Bool, text: String) -> Maybe<&2, String>:
  match none:
    case True{}:
      None{}
    case False{}:
      Some{String.trim(text)}

# A line from the keyboard, without its end. None: the keyboard closed (Ctrl+D).
def typed(r: Result<&1, &1, U32 & String, String>) -> Maybe<&2, String>:
  match r:
    case Fail{e}:
      None{}
    case Done{+text}:
      typed.at(String.is_empty(text), text)

# ---------- Answering a question ----------

def word_of.law(+k: String) -> String:
  Sys.pick(String.eq(k, "a"), Ev.add_word(), Sys.pick(String.eq(k, "A"), Ev.always_word(), Sys.pick(String.eq(k, "d"), Ev.dont_word(), "")))

def word_of.mode(+k: String) -> String:
  Sys.pick(String.eq(k, "s"), "switch", Sys.pick(String.eq(k, "n"), "stay", ""))

def word_of.timer(+k: String) -> String:
  Sys.pick(String.eq(k, "y"), Timer.set_word(), Sys.pick(String.eq(k, "n"), Timer.dont_word(), ""))

def word_of.skill(+k: String) -> String:
  Sys.pick(String.eq(k, "y"), Skill.save_word(), Sys.pick(String.eq(k, "n"), Skill.dont_word(), ""))

def word_of.gate(+k: String) -> String:
  Sys.pick(String.eq(k, "y"), Gate.allow_word(), Sys.pick(String.eq(k, "s"), Gate.session_word(), Sys.pick(String.eq(k, "n"), Gate.deny_word(), "")))

# The word the server reads, from the letter the person typed ("" for a letter that isn't one of them).
def word_of(+q: String, +k: String) -> String:
  Sys.pick(Ev.is_law(q), word_of.law(k), Sys.pick(Ev.is_mode(q), word_of.mode(k), Sys.pick(Ev.is_timer(q), word_of.timer(k), Sys.pick(Ev.is_skill(q), word_of.skill(k), word_of.gate(k)))))

# Switch moves this window's mode too, as it moves the page's picker.
def after_answer(+c: Cli, switched: Bool) -> Cli:
  match switched:
    case True{}:
      at_mode(c, Policy.mode_index(Policy.Mode.AskBeforeChanges{}))
    case False{}:
      c

def answer.send(valid: Bool, +c: Cli, f: File, +q: String, +word: String) -> IO(Step):
  match valid:
    case False{}:
      IO.pure(Step, Step{True{}, c, f})
    case True{}:
      do IO<Step>:
        sent : String <- post(conversation(c, "answer/" ++ q), word)
        IO.sleep(400)
        return Step{True{}, after_answer(c, (Ev.is_mode(q) && String.eq(word, "switch"))), f}

def answer.typed(m: Maybe<&2, String>, +c: Cli, f: File, +q: String) -> IO(Step):
  match m:
    case None{}:
      IO.pure(Step, Step{False{}, c, f})
    case Some{+k}:
      answer.send(Bool.not(String.is_empty(word_of(q, k))), c, f, q, word_of(q, k))

def answer.read(got: File & Result<&1, &1, U32 & String, String>, +c: Cli, +q: String) -> IO(Step):
  (f, r) = got
  answer.typed(typed(r), c, f, q)

def answer(+c: Cli, f: File, +q: String) -> IO(Step):
  do IO<Step>:
    IO.write(keys(q) ++ "\n  > ")
    got : File & Result<&1, &1, U32 & String, String> <- File.read_line(f, 65536)
    answer.read(got, c, q)

# ---------- Writing ----------

def help() -> String:
  "  Write and press Enter.  !command runs it in the project.\n  /new   /list   /open <n>   /mode   /quit\n"

def mode_line(+c: Cli) -> String:
  "  Mode: " ++ Policy.mode_name(mode(c)) ++ "\n"

def kind.at(none: Bool, quit: Bool, list: Bool, new: Bool, open: Bool, mode: Bool, run: Bool, slash: Bool) -> Nat:
  match none quit list new open mode run slash:
    case True{} _ _ _ _ _ _ _:
      0n
    case False{} True{} _ _ _ _ _ _:
      1n
    case False{} False{} True{} _ _ _ _ _:
      2n
    case False{} False{} False{} True{} _ _ _ _:
      3n
    case False{} False{} False{} False{} True{} _ _ _:
      4n
    case False{} False{} False{} False{} False{} True{} _ _:
      5n
    case False{} False{} False{} False{} False{} False{} True{} _:
      6n
    case False{} False{} False{} False{} False{} False{} False{} True{}:
      7n
    case False{} False{} False{} False{} False{} False{} False{} False{}:
      8n

# What a line is: 0 nothing, 1 /quit, 2 /list, 3 /new, 4 /open, 5 /mode, 6 !command, 7 /help, 8 a message.
def kind(+t: String) -> Nat:
  kind.at(String.is_empty(t), String.eq(t, "/quit"), String.eq(t, "/list"), String.eq(t, "/new"), String.starts_with(t, "/open "), String.eq(t, "/mode"), String.starts_with(t, "!"), String.starts_with(t, "/"))

def refused(+r: String) -> String:
  Sys.pick(String.starts_with(r, "ok"), "",
  Sys.pick(String.eq(r, "busy"), "  · The chat is still answering, or a question waits.\n",
  Sys.pick(String.eq(r, "readonly"), "  · Only read runs no command. /mode changes it.\n",
  "  ✗ The server didn't take it. Is LawEditor running?\n")))

# A message that went through is already on the screen: its event isn't printed again.
def sent(+c: Cli, +r: String) -> Cli:
  pick_cli(String.starts_with(r, "ok"), at_seen(c, 1n+seen(c)), c)

def number(m: Maybe<&2, U32>) -> Nat:
  match m:
    case None{}:
      0n
    case Some{n}:
      U32.to_nat(n)

# The n-th conversation of the list (from 1): its project's key and its name.
def opened(+c: Cli, +l: String) -> Cli:
  pick_cli(String.is_empty(l), c, at_conv(c, Sys.nth(String.split(l, Ev.tab()), 0n), Sys.nth(String.split(l, Ev.tab()), 2n)))

def nth_row(ls: List<&2, String>, n: Nat) -> String:
  match ls n:
    case Nil{} _:
      ""
    case h <> t 0n:
      ""
    case h <> t 1n:
      h
    case h <> t 1n+k:
      nth_row(t, k)

def do_line(k: Nat, +c: Cli, f: File, +t: String) -> IO(Step):
  match k:
    case 0n:
      IO.pure(Step, Step{True{}, c, f})
    case 1n:
      IO.pure(Step, Step{False{}, c, f})
    case 2n:
      do IO<Step>:
        list : String <- get(url(c, "/api/conversations"))
        IO.write(listing(list))
        return Step{True{}, c, f}
    case 3n:
      do IO<Step>:
        +id : String <- Sys.new_id()
        IO.write("  A new conversation.\n")
        return Step{True{}, at_conv(c, "", "c" ++ id), f}
    case 4n:
      do IO<Step>:
        list : String <- get(url(c, "/api/conversations"))
        return Step{True{}, opened(c, nth_row(Ev.lines(list), number(U32.read(String.trim(String.drop(t, 6n)))))), f}
    case 5n:
      do IO<Step>:
        IO.write(mode_line(at_mode(c, (1 - mode(c) : U32))))
        return Step{True{}, at_mode(c, (1 - mode(c) : U32)), f}
    case 6n:
      do IO<Step>:
        +r : String <- post(conversation(c, "run"), settings(c) ++ "\n" ++ String.drop(t, 1n))
        IO.write(refused(r))
        return Step{True{}, c, f}
    case 7n:
      do IO<Step>:
        IO.write(help())
        return Step{True{}, c, f}
    case _:
      do IO<Step>:
        +r : String <- post(conversation(c, "say"), settings(c) ++ "\n" ++ t)
        IO.write(refused(r))
        return Step{True{}, sent(c, r), f}

def said.typed(m: Maybe<&2, String>, +c: Cli, f: File) -> IO(Step):
  match m:
    case None{}:
      IO.pure(Step, Step{False{}, c, f})
    case Some{+t}:
      do_line(kind(t), c, f, t)

def said.read(got: File & Result<&1, &1, U32 & String, String>, +c: Cli) -> IO(Step):
  (f, r) = got
  said.typed(typed(r), c, f)

def write(+c: Cli, f: File) -> IO(Step):
  do IO<Step>:
    IO.write("❯ ")
    got : File & Result<&1, &1, U32 & String, String> <- File.read_line(f, 1048576)
    said.read(got, c)

# What to do now: answer the question that waits, wait for the chat, or write.
def act.at(asking: Bool, running: Bool, +c: Cli, f: File, +log: String) -> IO(Step):
  match asking running:
    case True{} _:
      answer(c, f, Ev.asking(log))
    case False{} True{}:
      do IO<Step>:
        IO.sleep(400)
        return Step{True{}, c, f}
    case False{} False{}:
      write(c, f)

def act(+c: Cli, f: File, +log: String) -> IO(Step):
  act.at(Bool.not(String.is_empty(Ev.asking(log))), Bool.not(String.is_empty(Ev.running(log))), c, f, log)

# Where the open conversation's project has its page (the server's pages door), asked only when needed.
def page_url(+base: String, +c: Cli) -> String:
  Sys.pick(String.is_empty(String.trim(base)), "", String.trim(base) ++ "/" ++ key(c) ++ "/")

def page_where(need: Bool, +c: Cli) -> IO(String):
  match need:
    case False{}:
      IO.pure(String, "")
    case True{}:
      do IO<String>:
        +base : String <- get(url(c, "/api/pages"))
        return page_url(base, c)

# Each round: where the conversation is now, its new events printed, then one thing done.
def loop(fuel: Nat, s: Step) -> IO(Unit):
  match fuel s:
    case 0n Step{go, c, f}:
      File.close(f)
    case 1n+n Step{False{}, c, f}:
      File.close(f)
    case 1n+n Step{True{}, +c, f}:
      do IO<Unit>:
        +list : String <- get(url(c, "/api/conversations"))
        +c2 : Cli = follow(c, list)
        +log : String <- get(conversation(c2, "events/0"))
        +at : String <- page_where(has_page(Ev.after.drop(Ev.lines(log), seen(c2))), c2)
        IO.write(show_all(Ev.after.drop(Ev.lines(log), seen(c2)), at))
        s2 : Step <- act(at_seen(c2, Nat.max(seen(c2), Ev.count(log))), f, log)
        loop(n, s2)

# ---------- Start ----------

def arg.at(rest: List<String>) -> String:
  match rest:
    case Nil{}:
      ""
    case a <> more:
      a

def arg(args: List<String>) -> String:
  match args:
    case Nil{}:
      ""
    case p <> rest:
      arg.at(rest)

def begin(r: Result<&1, &1, U32 & String, File>, +c: Cli) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.print("The keyboard can't be read here.")
    case Done{f}:
      do IO<Unit>:
        IO.write("LawEditor · " ++ ai(c) ++ " · " ++ Policy.mode_name(mode(c)) ++ "\n" ++ help() ++ "\n")
        loop(4294967295n, Step{True{}, c, f})

def here.in(+c: Cli, +got: String) -> IO(Cli):
  do IO<Cli>:
    IO.write(Sys.pick(String.is_empty(got), "  This folder couldn't be opened as a project.\n", "  In " ++ Sys.nth(String.split(got, Ev.tab()), 1n) ++ ".\n"))
    return at_key(c, Sys.nth(String.split(got, Ev.tab()), 0n))

# This folder as the conversation's project: asked for (here), or already one (it has a .laweditor).
def here(wanted: Bool, +c: Cli, pwd: String) -> IO(Cli):
  match wanted:
    case False{}:
      IO.pure(Cli, c)
    case True{}:
      do IO<Cli>:
        +got : String <- post(url(c, "/api/open-path"), pwd)
        here.in(c, got)

# ---------- The timers ----------
# GET /api/timers answers the time now on its first line, then one timer per line: its project's key, its
# folder, then the timer as it is kept (harness/TIMER.bend reads it).

def timer_of(+row: String) -> Timer.Timer:
  Timer.read(Ev.after.drop(String.split(row, Ev.tab()), 2n))

def timers.rows(rows: List<&2, String>, +now: U32, +n: Nat) -> String:
  match rows:
    case Nil{}:
      ""
    case +h <> t:
      "  " ++ Nat.show(n) ++ "  " ++ Timer.row(now, timer_of(h)) ++ "   [" ++ Sys.nth(String.split(h, Ev.tab()), 0n) ++ "]\n" ++ timers.rows(t, now, 1n+n)

def timers.listing.at(none: Bool, +text: String) -> String:
  match none:
    case True{}:
      "\n  No timers.\n\n"
    case False{}:
      "\n  Timers\n" ++ timers.rows(Ev.after.drop(Ev.lines(text), 1n), Timer.number(U32.read(Sys.nth(Ev.lines(text), 0n))), 1n) ++ "\n  laweditor timers pause <n> | resume <n> | test <n> | stop <n>\n\n"

# The timers, numbered from 1, each with when it comes due next and its project's key in brackets.
def timers.listing(+text: String) -> String:
  timers.listing.at(String.is_empty(Sys.nth(Ev.lines(text), 1n)), text)

# What is said once the server answered, for each thing asked of a timer.
def timers.said(+verb: String, +answer: String, +t: Timer.Timer) -> String:
  Sys.pick(String.eq(String.trim(answer), "busy"), "  Not now: that conversation is answering, or a question waits there.",
  Sys.pick(String.eq(String.trim(answer), "gone"), "  That timer isn't there anymore.",
  Sys.pick(String.eq(verb, "stop"), "  Stopped: ", Sys.pick(String.eq(verb, "pause"), "  Paused: ", Sys.pick(String.eq(verb, "resume"), "  Going again: ", "  Its turn started now, in its conversation: "))) ++ Timer.brief(t)))

def timers.do.at(none: Bool, +c: Cli, +verb: String, +row: String) -> IO(Unit):
  match none:
    case True{}:
      IO.print("  No timer with that number. laweditor timers lists them.")
    case False{}:
      do IO<Unit>:
        +sent : String <- post(url(c, "/api/p/" ++ Sys.nth(String.split(row, Ev.tab()), 0n) ++ "/timer-" ++ verb), Timer.id(timer_of(row)))
        IO.print(timers.said(verb, sent, timer_of(row)))

# The n-th timer of the list (from 1; "" when there is none).
def timers.pick(+n: U32, +text: String) -> String:
  Sys.pick(U32.is_eq(n, 0), "", Sys.nth(Ev.after.drop(Ev.lines(text), 1n), U32.to_nat((n - 1 : U32))))

def is_verb(+v: String) -> Bool:
  (String.eq(v, "stop") || String.eq(v, "pause") || String.eq(v, "resume") || String.eq(v, "test"))

# verb: "" lists them; stop, pause, resume and test are done to the n-th.
def timers(does: Bool, +c: Cli, +verb: String, +n: String) -> IO(Unit):
  match does:
    case False{}:
      do IO<Unit>:
        text : String <- get(url(c, "/api/timers"))
        IO.write(timers.listing(text))
    case True{}:
      do IO<Unit>:
        +text : String <- get(url(c, "/api/timers"))
        timers.do.at(String.is_empty(timers.pick(Timer.number(U32.read(n)), text)), c, verb, timers.pick(Timer.number(U32.read(n)), text))

def start(up: Bool, list: Bool, +c: Cli, +a: String, pwd: String) -> IO(Unit):
  match up list:
    case False{} _:
      IO.print("LawEditor isn't running. Start it with: bun run start (in LawEditor's folder).")
    case True{} True{}:
      do IO<Unit>:
        text : String <- get(url(c, "/api/conversations"))
        IO.write(listing(text))
    case True{} False{}:
      do IO<Unit>:
        name : String <- Sys.read_file(".laweditor/name")
        +c2 : Cli <- here((String.eq(a, "here") || Bool.not(String.is_empty(name))), c, pwd)
        r : Result<&1, &1, U32 & String, File> <- File.open("/dev/stdin", "r")
        begin(r, c2)

# The words after the program's name, one per line, so each can be read more than once.
def words_of.go(args: List<String>) -> String:
  match args:
    case Nil{}:
      ""
    case h <> t:
      h ++ "\n" ++ words_of.go(t)

def words_of(args: List<String>) -> List<&2, String>:
  Ev.after.drop(String.lines(words_of.go(args)), 1n)

# timers: the list, or "timers pause|resume|test|stop <n>", when the server is up. Everything else is a conversation (start).
def begin_with(listed: Bool, up: Bool, +c: Cli, +w: List<&2, String>, pwd: String) -> IO(Unit):
  match listed:
    case True{}:
      timers(is_verb(Sys.nth(w, 1n)), c, Sys.nth(w, 1n), Sys.nth(w, 2n))
    case False{}:
      start(up, String.eq(Sys.nth(w, 0n), "list"), c, Sys.nth(w, 0n), pwd)

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    +port : String <- Sys.env("LAWEDITOR_PORT", "4280")
    +ai : String <- Sys.env("LAWEDITOR_AI", "claude")
    pwd : String <- Sys.env("PWD", ".")
    +id : String <- Sys.new_id()
    +c : Cli = Cli{port, ai, "", "c" ++ id, 0n, 0}
    +w : List<&2, String> = words_of(args)
    +up : String <- get(url(c, "/api/told/HARNESS.md"))
    begin_with((Bool.not(String.is_empty(up)) && String.eq(Sys.nth(w, 0n), "timers")), Bool.not(String.is_empty(up)), c, w, pwd)
