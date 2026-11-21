# LawEditor: the person's skills. Pure; the engine and the windows ask it.
#
# The harness gives resources that don't know what they are for: a clock to be called again (TIMER.bend),
# a terminal, the files of the project. A skill is the person's own orientation for using them in one
# context: when to use it, what it needs, the steps, when to stay silent, what to do alone and what to ask
# first, where to speak. It is text of theirs, kept with the project, that the chat reads before it acts.
#
# As with the rules it hears (HEAR.bend) and the timers it asks for (TIMER.bend), the chat sets nothing:
#   the instructions (SKILL.md) ask it to end its reply with the skill, each line marked:
#     SKILL: "Check Discord"
#     SKILL| When to use: on weekdays, or when the person asks what is new in the team's Discord.
#     SKILL| 1. Read mentions, threads and DMs.
#     SKILL| 2. Answer what you know. Chase what is pending, politely.
#   the system (this file) reads those lines, and the engine asks the person before the file is written.
# Every line carries its mark, so a window can hide a skill from the words whatever part of a long reply
# it is given (web/where.js: inParts).

import Base
import ./EVENTS.bend as Ev
import ./CHAT.bend as Chat

# ---------- The chat's reply ----------

def head() -> String: "SKILL: \""
def line() -> String: "SKILL|"

# The name inside a line SKILL: "<name>" ("" if it isn't one).
def name_of.at(is_head: Bool, l: String) -> String:
  match is_head:
    case True{}:
      String.trim(String.reverse(String.drop(String.reverse(String.drop(l, String.length(head()))), 1n)))
    case False{}:
      ""

def name_of(+l: String) -> String:
  name_of.at((String.starts_with(String.trim(l), head()) && String.ends_with(String.trim(l), "\"")), String.trim(l))

def is_head(+l: String) -> Bool:
  Bool.not(String.is_empty(name_of(l)))

def is_line(+l: String) -> Bool:
  String.starts_with(String.trim(l), line())

# What a marked line says: without its mark, and without the one space after it.
def text_of.at(spaced: Bool, +s: String) -> String:
  match spaced:
    case True{}:
      String.drop(s, 1n)
    case False{}:
      s

def text_of(+l: String) -> String:
  text_of.at(String.starts_with(String.drop(String.trim_start(l), String.length(line())), " "), String.drop(String.trim_start(l), String.length(line())))

def keep(yes: Bool, x: String, rest: List<&2, String>) -> List<&2, String>:
  match yes:
    case True{}:
      x <> rest
    case False{}:
      rest

def names.go(ls: List<&2, String>) -> List<&2, String>:
  match ls:
    case Nil{}:
      Nil{}
    case +h <> t:
      keep(is_head(h), name_of(h), names.go(t))

# The names of the skills the reply holds, in order.
def names(reply: String) -> List<&2, String>:
  names.go(String.lines(reply))

def count(reply: String) -> Nat:
  Ev.length(names(reply))

def name(reply: String, n: Nat) -> String:
  Ev.nth(names(reply), n)

def seen_after(is_head: Bool, +seen: Nat) -> Nat:
  match is_head:
    case True{}:
      1n+seen
    case False{}:
      seen

# Is a skill open after this line? A SKILL: line opens one when it has a name, and closes the one before
# when it has none; any other line leaves things as they were.
def open_after(any_head: Bool, is_head: Bool, open: Bool) -> Bool:
  match any_head:
    case True{}:
      is_head
    case False{}:
      open

# seen: how many skills were opened so far. The n-th skill's lines are the marked ones read while seen is
# n + 1 and that skill is still open.
def body.go(ls: List<&2, String>, +n: Nat, +seen: Nat, +open: Bool) -> List<&2, String>:
  match ls:
    case Nil{}:
      Nil{}
    case +h <> t:
      keep((is_line(h) && open && Nat.is_eq(seen, 1n+n)), text_of(h), body.go(t, n, seen_after(is_head(h), seen), open_after(String.starts_with(String.trim(h), "SKILL:"), is_head(h), open)))

# What the n-th skill says: its marked lines, in order.
def body(reply: String, +n: Nat) -> String:
  String.trim(String.join(body.go(String.lines(reply), n, 0n, False{}), "\n"))

def words.go(ls: List<&2, String>) -> List<&2, String>:
  match ls:
    case Nil{}:
      Nil{}
    case +h <> t:
      keep(Bool.not((String.starts_with(String.trim(h), "SKILL:") || is_line(h))), h, words.go(t))

# What the person reads: the reply without its skills.
def words(reply: String) -> String:
  String.trim(String.join(words.go(String.lines(reply)), "\n"))

# ---------- A skill, as it is kept ----------
# One file per skill, in the project's .laweditor/skills, named by its name in simple letters
# ("Check Discord" is check-discord.md). Its first line is its name; the rest is what it says.

def slug(name: String) -> String:
  Chat.slug(name)

# Can it be kept? It has a name that makes a file's name, and it says something.
def is_whole(+name: String, body: String) -> Bool:
  (Bool.not(String.is_empty(slug(name))) && Bool.not(String.is_empty(String.trim(body))))

def file(name: String, body: String) -> String:
  "# " ++ name ++ "\n\n" ++ body ++ "\n"

def path(+name: String) -> String:
  ".laweditor/skills/" ++ slug(name) ++ ".md"

# ---------- The question ----------
# In the shape of an action's question (GATE.question), so a window draws what would be written the same
# way: the question; how to draw it (its language and name); then the text itself.

def title(exists: Bool, name: String) -> String:
  match exists:
    case True{}:
      "Replace the skill \"" ++ name ++ "\"?"
    case False{}:
      "Save this as a skill?"

def question(exists: Bool, +name: String, body: String) -> String:
  title(exists, name) ++ "\nmd" ++ SCon{Ev.tab(), name ++ SCon{Ev.tab(), ""}} ++ "\n" ++ body

def save_word() -> String: "save"
def dont_word() -> String: "dont"

def saves(+word: String) -> Bool:
  String.eq(word, save_word())

def saved_note(name: String) -> String:
  "Skill saved: " ++ name ++ "."

# ---------- What the chat is told ----------
# have: the project's skills, one per line: the file's name without its end, a tab, the file's first line.

def listed.name(+first: String, +slug: String) -> String:
  Ev.first.pick(String.starts_with(first, "# "), String.drop(first, 2n), slug)

def listed.go(ls: List<&2, String>) -> List<&2, String>:
  match ls:
    case Nil{}:
      Nil{}
    case +h <> t:
      ("- " ++ listed.name(Ev.nth(String.split(h, Ev.tab()), 1n), Ev.nth(String.split(h, Ev.tab()), 0n)) ++ ": .laweditor/skills/" ++ Ev.nth(String.split(h, Ev.tab()), 0n) ++ ".md") <> listed.go(t)

def listed.at(none: Bool, +have: String) -> String:
  match none:
    case True{}:
      "None yet."
    case False{}:
      String.join(listed.go(Ev.lines(have)), "\n")

# The skills the project has, as the chat reads them: each with the file to read before using it.
def listed(+have: String) -> String:
  "## The skills of this project\n\n" ++ listed.at(String.is_empty(String.trim(have)), have)
