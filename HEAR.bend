# LawEditor: the chat hears rules. Pure; the server and the page ask it.
#
# Two parts, like a game's AI and its rules:
#   the skill (HEAR.md) is a prompt. It asks the chat to end its reply with one line
#     LAW: "<sentence>"
#   for each rule the person stated. A prompt can miss a rule or make one up.
#   the system (this file) reads those lines and decides what happens to each.
#   Nothing reaches the document without the person's answer (LAWS.bend proves it).

import Base
import ./FLOW.bend as F

# ---------- The chat's reply ----------

def mark() -> String: "LAW: \""

# The sentence inside a line LAW: "<sentence>" (or "" if it isn't one).
def sentence_of.at(is_mark: Bool, line: String) -> String:
  match is_mark:
    case True{}:
      String.trim(String.reverse(String.drop(String.reverse(String.drop(line, String.length(mark()))), 1n)))
    case False{}:
      ""

def sentence_of(+line: String) -> String:
  sentence_of.at(String.starts_with(String.trim(line), mark()) && String.ends_with(String.trim(line), "\""), String.trim(line))

# Is this line a proposal? A LAW: line with a sentence in it.
def is_proposal(+line: String) -> Bool:
  Bool.not(String.is_empty(sentence_of(line)))

def keep(yes: Bool, x: String, rest: List<&2, String>) -> List<&2, String>:
  match yes:
    case True{}:
      x <> rest
    case False{}:
      rest

def proposals.step(+line: String, rest: List<&2, String>) -> List<&2, String>:
  keep(is_proposal(line), sentence_of(line), rest)

def proposals.go(ls: List<&2, String>) -> List<&2, String>:
  match ls:
    case Nil{}:
      Nil{}
    case h <> t:
      proposals.step(h, proposals.go(t))

# The sentences the chat proposed, in order.
def proposals(reply: String) -> List<&2, String>:
  proposals.go(String.lines(reply))

# Any LAW: line, even one with no sentence, is for the system, not for the person.
def words.step(+line: String, rest: List<&2, String>) -> List<&2, String>:
  keep(Bool.not(String.starts_with(String.trim(line), "LAW:")), line, rest)

def words.go(ls: List<&2, String>) -> List<&2, String>:
  match ls:
    case Nil{}:
      Nil{}
    case h <> t:
      words.step(h, words.go(t))

# What the person reads: the reply without its LAW: lines.
def words(reply: String) -> String:
  String.trim(String.join(words.go(String.lines(reply)), "\n"))

# For the page: how many proposals, and the n-th one.
def length(xs: List<&2, String>) -> Nat:
  match xs:
    case Nil{}:
      0n
    case h <> t:
      (1n + length(t) : Nat)

def count(reply: String) -> Nat:
  length(proposals(reply))

def nth(xs: List<&2, String>, n: Nat) -> String:
  match xs n:
    case Nil{} _:
      ""
    case h <> t 0n:
      h
    case h <> t 1n+k:
      nth(t, k)

def proposal(reply: String, n: Nat) -> String:
  nth(proposals(reply), n)

# ---------- Already in the document? ----------

def in_doc(+sentence: String, ls: List<&2, String>) -> Bool:
  match ls:
    case Nil{}:
      False{}
    case h <> t:
      String.eq(String.trim(h), sentence) || in_doc(sentence, t)

# A proposal is new when no line of GDD.md already says it. Old ones are not asked again.
def is_new(+sentence: String, gdd: String) -> Bool:
  Bool.not(in_doc(String.trim(sentence), String.lines(gdd)))

# ---------- The person's answer ----------

# What the page does with a new proposal: ask (every session starts here), or add it.
def asking() -> U32: 0
def adding() -> U32: 1
def start() -> U32: 0

# The person's answer to a proposal.
def add() -> U32: 0
def always() -> U32: 1
def dont() -> U32: 2

# Ask before adding?
def must_ask(mode: U32) -> Bool:
  U32.is_eq(mode, 0)

# Does this answer put the sentence in the document?
def adds(+answer: U32) -> Bool:
  U32.is_eq(answer, 0) || U32.is_eq(answer, 1)

# The mode after an answer: "Always add" stops the asking for the rest of the session. Add and Don't add keep it.
def mode_after.at(always: Bool) -> U32:
  match always:
    case True{}:
      1
    case False{}:
      0

def mode_after(+mode: U32, +answer: U32) -> U32:
  mode_after.at(U32.is_eq(mode, 1) || U32.is_eq(answer, 1))

# ---------- The flow (FLOW.bend), drawn as the diagram ----------
# The question's arrows come from adds and must_ask above: change the code and the diagram changes with it.

def answer_to.at(added: Bool) -> Nat:
  match added:
    case True{}:
      6n
    case False{}:
      9n

def answer_to(+answer: U32) -> Nat:
  answer_to.at(adds(answer))

def mode_to.at(ask: Bool) -> Nat:
  match ask:
    case True{}:
      4n
    case False{}:
      5n

def mode_to(mode: U32) -> Nat:
  mode_to.at(must_ask(mode))

def flow() -> List<&2, F.Step>:
  [
    F.Step{"You talk", F.Person{}, False{}, [F.Go{1n, ""}]},
    F.Step{"The chat hears the rules, said or taken for granted, and the ones it chose while building; it ends its reply with LAW: lines", F.Skill{}, False{}, [F.Go{2n, ""}]},
    F.Step{"Read the LAW: lines", F.System{}, False{}, [F.Go{3n, "new"}, F.Go{8n, "already in the document"}]},
    F.Step{"Ask, or add?", F.System{}, False{}, [F.Go{mode_to(asking()), "asking (every session starts here)"}, F.Go{mode_to(adding()), "after Always add"}]},
    F.Step{"Add, Always add or Don't add: the talk stops until you answer", F.Person{}, False{}, [F.Go{answer_to(add()), "Add"}, F.Go{answer_to(always()), "Always add"}, F.Go{answer_to(dont()), "Don't add"}]},
    F.Step{"You said Always add, this session", F.Person{}, False{}, [F.Go{6n, ""}]},
    F.Step{"Put the sentence in the document", F.System{}, True{}, [F.Go{7n, ""}]},
    F.Step{"The law agent writes its law", F.Skill{}, True{}, [F.Go{10n, ""}]},
    F.Step{"Already there: not asked again", F.System{}, False{}, []},
    F.Step{"Not added", F.System{}, False{}, []},
    F.Step{"Bend checks the law: green or red", F.System{}, False{}, []}
  ]
