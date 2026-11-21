# LawEditor: a conversation, as the engine keeps it. Pure; engine/TURN.bend writes it, and every window
# (the page, the terminal) reads it and draws.
#
# A conversation is a list of events, oldest first, one per line, its fields split by tabs:
#
#   me      <text>                              the person wrote
#   turn    <turn> <ai> <model> <mode>          the chat started answering
#   reply   <turn> <text>                       its answer, whole (with its LAW:, MODE:, PLAN: and PROJECT: lines)
#   fail    <turn> <why>                        it couldn't answer
#   stopped <turn>                              the person stopped it
#   ask     <question> <text>                   a question for the person (law-…, mode-…, gate-…, timer-…, skill-…)
#   answer  <question> <word>                   what they answered
#   note    <question> <state> <text>           what came of it (busy, ok, error, none)
#   project <key> <name>                        the conversation's project got its folder and name
#   check   <turn> <state> <text>               Bend checked the project after the turn changed it (ok, error)
#   page    <turn> <state> <text>               Bend bundled the project's page (ok, warn, error)
#   ran     <command> <code> <output>           a command the person ran themselves (!)
#   timer   <timer> <when> <text>               a timer the person set came due and started a turn (TIMER.bend)
#
# Nothing is ever taken out: a window that has read n events asks for the ones after n.

import Base
import ./HEAR.bend as Hear
import ./CHAT.bend as Chat

# ---------- A field ----------
# A field may hold tabs and new lines: they are written as \t and \n, and a backslash as \\.

def tab() -> Char: Char.from_u32(9)
def nl() -> Char: Char.from_u32(10)
def back() -> Char: Char.from_u32(92)

def esc.put(+c: Char, is_back: Bool, is_nl: Bool, is_tab: Bool, rest: String) -> String:
  match is_back is_nl is_tab:
    case True{} _ _:
      SCon{back(), SCon{back(), rest}}
    case False{} True{} _:
      SCon{back(), SCon{'n', rest}}
    case False{} False{} True{}:
      SCon{back(), SCon{'t', rest}}
    case False{} False{} False{}:
      SCon{c, rest}

def esc(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{+h, t}:
      esc.put(h, Char.is_eq(h, back()), Char.is_eq(h, nl()), Char.is_eq(h, tab()), esc(t))

def unesc.code(+c: Char, is_n: Bool, is_t: Bool) -> Char:
  match is_n is_t:
    case True{} _:
      nl()
    case False{} True{}:
      tab()
    case False{} False{}:
      c

def unesc.keep(is_back: Bool, c: Char, rest: String) -> String:
  match is_back:
    case True{}:
      rest
    case False{}:
      SCon{c, rest}

# pending: the character before was a backslash.
def unesc.go(s: String, pending: Bool) -> String:
  match s pending:
    case SNil{} _:
      ""
    case SCon{+h, t} True{}:
      SCon{unesc.code(h, Char.is_eq(h, 'n'), Char.is_eq(h, 't')), unesc.go(t, False{})}
    case SCon{+h, t} False{}:
      unesc.keep(Char.is_eq(h, back()), h, unesc.go(t, Char.is_eq(h, back())))

def unesc(s: String) -> String:
  unesc.go(s, False{})

# ---------- An event ----------

def fields.join(xs: List<&2, String>) -> String:
  match xs:
    case Nil{}:
      ""
    case h <> t:
      SCon{tab(), esc(h) ++ fields.join(t)}

# One event's line, ending in a new line: its kind, then its fields.
def event(kind: String, fields: List<&2, String>) -> String:
  kind ++ fields.join(fields) ++ SCon{nl(), ""}

def nth(xs: List<&2, String>, n: Nat) -> String:
  match xs n:
    case Nil{} _:
      ""
    case h <> t 0n:
      h
    case h <> t 1n+k:
      nth(t, k)

# An event's kind, and its n-th field (0 is the first after the kind), as it was written.
def kind(line: String) -> String:
  nth(String.split(line, tab()), 0n)

def field(line: String, n: Nat) -> String:
  unesc(nth(String.split(line, tab()), 1n+n))

def is_a(+line: String, +k: String) -> Bool:
  String.eq(kind(line), k)

# ---------- Reading a conversation ----------

def after.drop(xs: List<&2, String>, n: Nat) -> List<&2, String>:
  match xs n:
    case Nil{} _:
      Nil{}
    case h <> t 0n:
      h <> t
    case h <> t 1n+k:
      after.drop(t, k)

def lines.keep(+s: String, rest: List<&2, String>) -> List<&2, String>:
  match s:
    case SNil{}:
      rest
    case SCon{h, t}:
      s <> rest

def lines.go(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> t:
      lines.keep(h, lines.go(t))

# The events, without empty lines.
def lines(log: String) -> List<&2, String>:
  lines.go(String.lines(log))

def length(xs: List<&2, String>) -> Nat:
  match xs:
    case Nil{}:
      0n
    case h <> t:
      1n+length(t)

def count(log: String) -> Nat:
  length(lines(log))

def unlines(xs: List<&2, String>) -> String:
  match xs:
    case Nil{}:
      ""
    case h <> t:
      h ++ SCon{nl(), unlines(t)}

# The events after the first n: what a window that has read n still has to read.
def after(log: String, n: Nat) -> String:
  unlines(after.drop(lines(log), n))

# What LawEditor itself tells the chat: Bend's word on the project, when it isn't plain good (an error of
# the check, a page that couldn't be bundled, a page with no Bend in it). engine/BUILD.bend writes them.
def is_told(+l: String) -> Bool:
  ((is_a(l, "check") || is_a(l, "page")) && Bool.not(String.eq(field(l, 1n), "ok")))

def told.text(check: Bool, +l: String) -> String:
  match check:
    case True{}:
      "LawEditor: Bend checked the project after that reply and found an error. Fix it before anything else.\n" ++ String.take(field(l, 2n), 4000n)
    case False{}:
      "LawEditor: " ++ String.take(field(l, 2n), 4000n)

# The conversation as the chat reads it: "Person: …" and "Agent: …", oldest first.
# A command the person ran is part of the talk too: the chat reads what it printed. So is what Bend said
# of the project ("LawEditor: …").
def talk.line(me: Bool, reply: Bool, ran: Bool, told: Bool, +l: String, rest: List<&2, String>) -> List<&2, String>:
  match me reply ran told:
    case True{} _ _ _:
      ("Person: " ++ field(l, 0n)) <> rest
    case False{} True{} _ _:
      ("Agent: " ++ field(l, 1n)) <> rest
    case False{} False{} True{} _:
      ("Person: (ran the command `" ++ field(l, 0n) ++ "`; it printed:)\n" ++ String.take(field(l, 2n), 4000n)) <> rest
    case False{} False{} False{} True{}:
      told.text(is_a(l, "check"), l) <> rest
    case False{} False{} False{} False{}:
      rest

# A timer that came due speaks as the app, not as the person: they set it, but they aren't the one writing now.
def talk.woke(woke: Bool, +l: String, rest: List<&2, String>) -> List<&2, String>:
  match woke:
    case True{}:
      ("LawEditor: a timer the person set (" ++ field(l, 1n) ++ ") came due. It asks:\n" ++ field(l, 2n)) <> rest
    case False{}:
      rest

def talk.go(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> t:
      talk.woke(is_a(h, "timer"), h, talk.line(is_a(h, "me"), is_a(h, "reply"), is_a(h, "ran"), is_told(h), h, talk.go(t)))

def talk(log: String) -> String:
  String.join(talk.go(lines(log)), "\n")

# The last event of a kind ("" if none).
def last.pick(hit: Bool, +l: String, +found: String) -> String:
  match hit:
    case True{}:
      l
    case False{}:
      found

def last.go(xs: List<&2, String>, +k: String, +found: String) -> String:
  match xs:
    case Nil{}:
      found
    case +h <> t:
      last.go(t, k, last.pick(is_a(h, k), h, found))

def last(log: String, +k: String) -> String:
  last.go(lines(log), k, "")

# The first event of a kind ("" if none).
def first.pick(hit: Bool, +l: String, +later: String) -> String:
  match hit:
    case True{}:
      l
    case False{}:
      later

def first.go(xs: List<&2, String>, +k: String) -> String:
  match xs:
    case Nil{}:
      ""
    case +h <> t:
      first.pick(is_a(h, k), h, first.go(t, k))

def first(log: String, +k: String) -> String:
  first.go(lines(log), k)

# The conversation's project: its name and its folder ("" while it has none).
def project(+log: String) -> String:
  field(last(log, "project"), 1n)

def project_key(+log: String) -> String:
  field(last(log, "project"), 0n)

# The name the chat gave the project in any of its replies (its first PROJECT: line; "" if it gave none).
def named.pick(reply: Bool, +l: String, +later: String) -> String:
  match reply:
    case True{}:
      first.pick(Bool.not(String.is_empty(Chat.project_name(field(l, 1n)))), Chat.project_name(field(l, 1n)), later)
    case False{}:
      later

def named.go(xs: List<&2, String>) -> String:
  match xs:
    case Nil{}:
      ""
    case +h <> t:
      named.pick(is_a(h, "reply"), h, named.go(t))

def named(log: String) -> String:
  named.go(lines(log))

# A conversation's title, for the list: the person's first message, its first line, up to 60 characters.
def title(+log: String) -> String:
  String.take(String.trim(nth(String.lines(field(first(log, "me"), 0n)), 0n)), 60n)

# Has anything been said or done in it yet?
def is_new(+log: String) -> Bool:
  (String.is_empty(first(log, "me")) && String.is_empty(first(log, "ran")))

# The project's name when the chat gave none: the conversation's title, up to 40 characters.
def name_or_title.at(+name: String, +log: String, none: Bool) -> String:
  match none:
    case True{}:
      String.take(title(log), 40n)
    case False{}:
      name

def name_or_title(+log: String) -> String:
  name_or_title.at(named(log), log, String.is_empty(named(log)))

# ---------- What is going on ----------

# Did a turn end? A reply, a failure or a stop names it.
def ended.is(+l: String, +turn: String) -> Bool:
  ((is_a(l, "reply") || is_a(l, "fail") || is_a(l, "stopped")) && String.eq(field(l, 0n), turn))

def ended.go(xs: List<&2, String>, +turn: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case +h <> t:
      (ended.is(h, turn) || ended.go(t, turn))

# The turn that is running now ("" if the chat isn't answering).
def running.at(+turn: String, none: Bool, ended: Bool) -> String:
  match none ended:
    case True{} _:
      ""
    case False{} True{}:
      ""
    case False{} False{}:
      turn

def running(+log: String) -> String:
  running.at(field(last(log, "turn"), 0n), String.is_empty(last(log, "turn")), ended.go(lines(log), field(last(log, "turn"), 0n)))

# Was a question answered?
def answered.go(xs: List<&2, String>, +q: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case +h <> t:
      ((is_a(h, "answer") && String.eq(field(h, 0n), q)) || answered.go(t, q))

# The question that waits for the person ("" if none): the last one asked, if it has no answer yet.
def asking.at(+q: String, none: Bool, answered: Bool) -> String:
  match none answered:
    case True{} _:
      ""
    case False{} True{}:
      ""
    case False{} False{}:
      q

def asking(+log: String) -> String:
  asking.at(field(last(log, "ask"), 0n), String.is_empty(last(log, "ask")), answered.go(lines(log), field(last(log, "ask"), 0n)))

# What came of a question: its last note's state ("busy" while its law is being written; "" with no note).
def noted.step(hit: Bool, +l: String, +found: String) -> String:
  match hit:
    case True{}:
      field(l, 1n)
    case False{}:
      found

def noted.go(xs: List<&2, String>, +q: String, +found: String) -> String:
  match xs:
    case Nil{}:
      found
    case +h <> t:
      noted.go(t, q, noted.step((is_a(h, "note") && String.eq(field(h, 0n), q)), h, found))

def noted(log: String, +q: String) -> String:
  noted.go(lines(log), q, "")

# ---------- What a server that stopped left behind ----------
# The engine that waited for an answer, or ran a turn, is gone with the server. When the server starts,
# each conversation gets the events that close what was open: a question nobody waits for anymore is
# answered no, a turn that was running failed, and a law that was being written is said not to be.
# Without them the conversation would wait forever.

# What set the chat going last: a timer (True), or the person (a message, a command of theirs).
def woken.step(person: Bool, timer: Bool, was: Bool) -> Bool:
  match person timer:
    case True{} _:
      False{}
    case False{} True{}:
      True{}
    case False{} False{}:
      was

def woken.go(xs: List<&2, String>, was: Bool) -> Bool:
  match xs:
    case Nil{}:
      was
    case +h <> t:
      woken.go(t, woken.step((is_a(h, "me") || is_a(h, "ran")), is_a(h, "timer"), was))

def woken(log: String) -> Bool:
  woken.go(lines(log), False{})

def no_word.at(heard: Bool, offer: Bool) -> String:
  match heard offer:
    case True{} _:
      "dont"
    case False{} True{}:
      "stay"
    case False{} False{}:
      "deny"

# The word that says no to a question, by its kind (HEAR.bend, TIMER.bend and SKILL.bend share theirs, OFFER.bend, GATE.bend).
def no_word(+q: String) -> String:
  no_word.at((String.starts_with(q, "law-") || String.starts_with(q, "timer-") || String.starts_with(q, "skill-")), String.starts_with(q, "mode-"))

def left.one(open: Bool, +q: String, rest: String) -> String:
  match open:
    case True{}:
      event("answer", [q, no_word(q)]) ++ event("note", [q, "none", "Not answered: LawEditor was closed while it waited."]) ++ rest
    case False{}:
      rest

def left.go(xs: List<&2, String>, +log: String) -> String:
  match xs:
    case Nil{}:
      ""
    case +h <> t:
      left.one((is_a(h, "ask") && Bool.not(answered.go(lines(log), field(h, 0n)))), field(h, 0n), left.go(t, log))

def left.turn(none: Bool, +turn: String) -> String:
  match none:
    case True{}:
      ""
    case False{}:
      event("fail", [turn, "LawEditor was closed while the chat was answering."])

# A rule that was added, whose law was still being written: its last note says "busy".
def law_busy(+l: String, +log: String) -> Bool:
  (is_a(l, "note") && String.starts_with(field(l, 0n), "law-") && String.eq(field(l, 1n), "busy") && String.eq(noted(log, field(l, 0n)), "busy"))

def left.law(busy: Bool, +q: String, rest: String) -> String:
  match busy:
    case True{}:
      event("note", [q, "error", "Its law was not written: LawEditor was closed meanwhile. Generate it in Laws."]) ++ rest
    case False{}:
      rest

def left.laws(xs: List<&2, String>, +log: String) -> String:
  match xs:
    case Nil{}:
      ""
    case +h <> t:
      left.law(law_busy(h, log), field(h, 0n), left.laws(t, log))

def left(+log: String) -> String:
  left.turn(String.is_empty(running(log)), running(log)) ++ left.go(lines(log), log) ++ left.laws(lines(log), log)

# Is a law being written now? The law agent may add a definition to the project's code, so the chat's
# next turn waits for it (engine/TURN.bend): the two never write the same file at once.
def writing.go(xs: List<&2, String>, +log: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case +h <> t:
      (law_busy(h, log) || writing.go(t, log))

def writing(+log: String) -> Bool:
  writing.go(lines(log), log)

# May the person write now? Not while the chat answers, and not while a question waits (CHAT.bend: can_send).
def can_say(+log: String) -> Bool:
  (String.is_empty(running(log)) && String.is_empty(asking(log)))

# The conversation's state, for the list: asking wins over working.
def idle() -> String: "idle"
def working() -> String: "working"
def waiting() -> String: "asking"

# ---------- Hearing rules (HEAR.bend) ----------

# A question's kind is how its name starts: law-, mode-, gate-, timer-, skill-.
def is_timer(+q: String) -> Bool:
  String.starts_with(q, "timer-")

def is_skill(+q: String) -> Bool:
  String.starts_with(q, "skill-")

def is_law(+q: String) -> Bool:
  String.starts_with(q, "law-")

def is_mode(+q: String) -> Bool:
  String.starts_with(q, "mode-")

def is_gate(+q: String) -> Bool:
  String.starts_with(q, "gate-")

# The words a law question is answered with, and HEAR.bend's answer for each.
def add_word() -> String: "add"
def always_word() -> String: "always"
def dont_word() -> String: "dont"

def hear_answer.at(add: Bool, always: Bool) -> U32:
  match add always:
    case True{} _:
      Hear.add()
    case False{} True{}:
      Hear.always()
    case False{} False{}:
      Hear.dont()

def hear_answer(+word: String) -> U32:
  hear_answer.at(String.eq(word, add_word()), String.eq(word, always_word()))

# The conversation's hearing mode: it starts asking, and the answers move it (HEAR.mode_after).
def hear_mode.step(is_law: Bool, +l: String, +mode: U32) -> U32:
  match is_law:
    case True{}:
      Hear.mode_after(mode, hear_answer(field(l, 1n)))
    case False{}:
      mode

def hear_mode.go(xs: List<&2, String>, +mode: U32) -> U32:
  match xs:
    case Nil{}:
      mode
    case +h <> t:
      hear_mode.go(t, hear_mode.step((is_a(h, "answer") && is_law(field(h, 0n))), h, mode))

def hear_mode(log: String) -> U32:
  hear_mode.go(lines(log), Hear.start())

# The sentences already proposed in this conversation, one per line, so none is asked twice.
def heard.line(is_law: Bool, +l: String, rest: List<&2, String>) -> List<&2, String>:
  match is_law:
    case True{}:
      field(l, 1n) <> rest
    case False{}:
      rest

def heard.go(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> t:
      heard.line((is_a(h, "ask") && is_law(field(h, 0n))), h, heard.go(t))

def heard(log: String) -> String:
  String.join(heard.go(lines(log)), "\n")

# ---------- An old conversation (0.1.10 kept "Person: …" / "Agent: …" lines) ----------
# Its first line was the title; then the talk; then, after a record separator on its own line, each
# message's turn. It becomes events: the turns it names are kept with the replies.

def old.sep() -> String: SCon{Char.from_u32(30), ""}

def old.starts(+h: String) -> Bool:
  (String.starts_with(h, "Person: ") || String.starts_with(h, "Agent: "))

# Who a line belongs to: 0 the person, 1 the agent, or whoever was writing (2 before the first message).
def old.who.at(person: Bool, agent: Bool, who: U32) -> U32:
  match person agent:
    case True{} _:
      0
    case False{} True{}:
      1
    case False{} False{}:
      who

def old.who(+h: String, who: U32) -> U32:
  old.who.at(String.starts_with(h, "Person: "), String.starts_with(h, "Agent: "), who)

def old.text.at(person: Bool, agent: Bool, h: String, text: String) -> String:
  match person agent:
    case True{} _:
      String.drop(h, 8n)
    case False{} True{}:
      String.drop(h, 7n)
    case False{} False{}:
      text ++ SCon{nl(), h}

def old.text(+h: String, text: String) -> String:
  old.text.at(String.starts_with(h, "Person: "), String.starts_with(h, "Agent: "), h, text)

def old.flush.at(person: Bool, agent: Bool, text: String, turn: String) -> String:
  match person agent:
    case True{} _:
      event("me", [text])
    case False{} True{}:
      event("reply", [turn, text])
    case False{} False{}:
      ""

def old.flush(+who: U32, text: String, turn: String) -> String:
  old.flush.at(U32.is_eq(who, 0), U32.is_eq(who, 1), text, turn)

def old.emit(starts: Bool, who: U32, text: String, turn: String) -> String:
  match starts:
    case True{}:
      old.flush(who, text, turn)
    case False{}:
      ""

def old.next(starts: Bool, first: Bool, +i: Nat) -> Nat:
  match starts first:
    case True{} False{}:
      1n+i
    case _ _:
      i

# who and text: the message being gathered; i: its place among the messages (its turn is the i-th).
def old.go(ls: List<&2, String>, +who: U32, +text: String, +turns: List<&2, String>, +i: Nat) -> String:
  match ls:
    case Nil{}:
      old.flush(who, text, nth(turns, i))
    case +h <> t:
      old.emit(old.starts(h), who, text, nth(turns, i)) ++ old.go(t, old.who(h, who), old.text(h, text), turns, old.next(old.starts(h), U32.is_eq(who, 2), i))

def old.before.keep(is_sep: Bool, h: String, rest: List<&2, String>) -> List<&2, String>:
  match is_sep:
    case True{}:
      Nil{}
    case False{}:
      h <> rest

def old.before(ls: List<&2, String>) -> List<&2, String>:
  match ls:
    case Nil{}:
      Nil{}
    case +h <> t:
      old.before.keep(String.eq(h, old.sep()), h, old.before(t))

def old.turns(ls: List<&2, String>, seen: Bool) -> String:
  match ls seen:
    case Nil{} _:
      ""
    case h <> t True{}:
      h
    case +h <> t False{}:
      old.turns(t, String.eq(h, old.sep()))

def old.tail(ls: List<&2, String>) -> List<&2, String>:
  match ls:
    case Nil{}:
      Nil{}
    case h <> t:
      t

def from_old(+text: String) -> String:
  old.go(old.before(old.tail(String.lines(text))), 2, "", String.split(old.turns(String.lines(text), False{}), ','), 0n)
