# LawEditor: where each thing is kept. Pure.
#
# The server runs in the home of the projects (~/LawEditor unless LAWEDITOR_HOME says otherwise). A project
# is a folder: one made by LawEditor lives in that home, under its key; one opened from elsewhere on the
# computer keeps its place, and the home's .folders file knows where it is (its key starts with "x-").
# In a project: its program, in .bend files (main.bend is where it starts; index.html when it has a page),
# RULES.md (the person's rules, one sentence per line), LAWS.bend (their laws, which import the program),
# and .laweditor/ (its name, its conversations, what was allowed, each turn's record, Bend's guide for
# the chat to read, and the page as Bend last bundled it). LawEditor makes none of the first three: each
# appears when there is something to put in it.

import Base

# Only letters, digits and "-" are kept from a name that comes from outside, so it can't point elsewhere.
def safe.keep(+c: Char, ok: Bool, rest: String) -> String:
  match ok:
    case True{}:
      SCon{c, rest}
    case False{}:
      rest

def safe(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{+h, t}:
      safe.keep(h, (Char.is_alpha(h) || Char.is_digit(h) || Char.is_eq(h, '-')), safe(t))

# ---------- A project opened from elsewhere ----------

def folders() -> String: ".folders"

def is_outside(+key: String) -> Bool:
  String.starts_with(key, "x-")

def nth(xs: List<&2, String>, n: Nat) -> String:
  match xs n:
    case Nil{} _:
      ""
    case h <> t 0n:
      h
    case h <> t 1n+k:
      nth(t, k)

def tab() -> Char: Char.from_u32(9)

def outside.pick(hit: Bool, +line: String, +later: String) -> String:
  match hit:
    case True{}:
      nth(String.split(line, tab()), 1n)
    case False{}:
      later

def outside.go(ls: List<&2, String>, +key: String) -> String:
  match ls:
    case Nil{}:
      ""
    case +h <> t:
      outside.pick(String.eq(nth(String.split(h, tab()), 0n), key), h, outside.go(t, key))

# A project's folder, from its key and the .folders file's text ("" if the key names nothing).
def folder.at(outside: Bool, +key: String, +known: String) -> String:
  match outside:
    case True{}:
      outside.go(String.lines(known), key)
    case False{}:
      safe(key)

def folder(+key: String, +known: String) -> String:
  folder.at(is_outside(key), key, known)

# ---------- In a project ----------

def chats(+dir: String) -> String:
  dir ++ "/.laweditor/chats/"

# A conversation: its events (harness/EVENTS.bend), its state for the list, its title.
def log(+dir: String, conv: String) -> String:
  chats(dir) ++ safe(conv) ++ ".log"

def state(+dir: String, conv: String) -> String:
  chats(dir) ++ safe(conv) ++ ".state"

def title(+dir: String, conv: String) -> String:
  chats(dir) ++ safe(conv) ++ ".title"

# The AI, model and mode the conversation last used: the law agent and a later turn follow them.
def settings(+dir: String, conv: String) -> String:
  chats(dir) ++ safe(conv) ++ ".settings"

# The person's answer to a question, while the engine waits for it.
def answer(+dir: String, conv: String, question: String) -> String:
  chats(dir) ++ safe(conv) ++ "." ++ safe(question) ++ ".answer"

# A turn: what the AI printed, as it printed it (ASK.bend reads it), and the mark that the person stopped it.
def turn(+dir: String, turn: String) -> String:
  dir ++ "/.laweditor/turns/" ++ safe(turn) ++ ".jsonl"

# A turn's work as ASK.bend read it, kept once the turn ended (its file never changes after).
def work(+dir: String, turn: String) -> String:
  dir ++ "/.laweditor/turns/" ++ safe(turn) ++ ".work"

def stopped(+dir: String, turn: String) -> String:
  dir ++ "/.laweditor/turns/" ++ safe(turn) ++ ".stopped"

# What the person allowed for a conversation (GATE.bend).
def allowed(+dir: String, conv: String) -> String:
  dir ++ "/.laweditor/allowed/" ++ safe(conv) ++ ".allowed"

# A terminal opened in the project: what it printed, and where its keys go.
def term_out(+dir: String) -> String:
  dir ++ "/.laweditor/term.out"

def term_in(+dir: String) -> String:
  dir ++ "/.laweditor/term.in"

# Bend's guide, as the installed bend prints it: the chat reads it there (engine/TURN.bend writes it).
def guide(+dir: String) -> String:
  dir ++ "/.laweditor/GUIDE.md"

# The project's page, as Bend last bundled it (engine/BUILD.bend). LawEditor's own place: it is emptied
# before each bundle, and the pages door serves it (server.bend).
def page_in() -> String: ".laweditor/page"

def page(+dir: String) -> String:
  dir ++ "/" ++ page_in()
