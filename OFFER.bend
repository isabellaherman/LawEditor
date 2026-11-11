# LawEditor: the chat offers the mode. Pure; the page asks it.
#
# In Only read the chat can't build. When the person wants something built, the chat doesn't refuse:
# it ends its reply with one line
#   MODE: "Ask before changes"
# and the page asks the person to switch (as Claude Code asks to leave plan mode and build).
# Switch moves the picker and sends the request again, now in Ask before changes; Stay changes nothing.
# The flow below is the source of the diagram, and LAWS.bend checks it.

import Base
import ./FLOW.bend as F
import ./POLICY.bend as P

# ---------- The chat's reply ----------

def line() -> String: "MODE: \"Ask before changes\""

# Does the reply offer the mode?
def offers.go(ls: List<&2, String>) -> Bool:
  match ls:
    case Nil{}:
      False{}
    case h <> t:
      String.eq(String.trim(h), line()) || offers.go(t)

def offers(reply: String) -> Bool:
  offers.go(String.lines(reply))

# What the person reads: the reply without its MODE: lines.
def words.keep(yes: Bool, x: String, rest: List<&2, String>) -> List<&2, String>:
  match yes:
    case True{}:
      x <> rest
    case False{}:
      rest

def words.go(ls: List<&2, String>) -> List<&2, String>:
  match ls:
    case Nil{}:
      Nil{}
    case +h <> t:
      words.keep(Bool.not(String.starts_with(String.trim(h), "MODE:")), h, words.go(t))

def words(reply: String) -> String:
  String.trim(String.join(words.go(String.lines(reply)), "\n"))

# ---------- The person's answer ----------

def switch() -> U32: 0
def stay() -> U32: 1

def switches(+a: U32) -> Bool:
  U32.is_eq(a, 0)

# The chat's mode after the answer (POLICY.bend counts the modes 0, 1, 2): Switch is Ask before changes,
# Stay keeps Only read.
def mode_after.at(sw: Bool) -> U32:
  match sw:
    case True{}:
      P.mode_index(P.Mode.AskBeforeChanges{})
    case False{}:
      P.mode_index(P.Mode.OnlyRead{})

def mode_after(+a: U32) -> U32:
  mode_after.at(switches(a))

# What the chat is told when the request goes again, after Switch.
def told() -> String:
  "The person switched to Ask before changes. Build what they asked now: first the smallest version they can play or use, then say how to open it and ask one question. Still end with the LAW: lines of the rules in it, the ones they said and the ones you chose."

# ---------- The flow (FLOW.bend), drawn as the diagram ----------
# The question's arrows come from switches above: change the code and the diagram changes with it.

def answer_to.at(sw: Bool) -> Nat:
  match sw:
    case True{}:
      4n
    case False{}:
      9n

def answer_to(+a: U32) -> Nat:
  answer_to.at(switches(a))

def flow() -> List<&2, F.Step>:
  [
    F.Step{"You ask for something to be built", F.Person{}, False{}, [F.Go{1n, ""}]},
    F.Step{"The chat sees it and ends its reply with MODE: \"Ask before changes\"", F.Skill{}, False{}, [F.Go{2n, ""}]},
    F.Step{"Read the MODE: line", F.System{}, False{}, [F.Go{3n, ""}]},
    F.Step{"Switch to Ask before changes? The talk stops until you answer", F.Person{}, False{}, [F.Go{answer_to(switch()), "Switch"}, F.Go{answer_to(stay()), "Stay"}]},
    F.Step{"The picker moves to Ask before changes; the request goes again", F.System{}, False{}, [F.Go{5n, ""}]},
    F.Step{"The chat writes the smallest version you can play", F.Skill{}, False{}, [F.Go{6n, ""}]},
    F.Step{"Claude is refused: turn it into a question", F.System{}, False{}, [F.Go{7n, ""}]},
    F.Step{"Allow, Always allow or Don't allow", F.Person{}, False{}, [F.Go{8n, "Allow"}, F.Go{10n, "Don't allow"}]},
    F.Step{"Write it; the chat says how to open it and asks one question", F.System{}, True{}, []},
    F.Step{"Stay in Only read: the chat only talks and hears rules", F.System{}, False{}, []},
    F.Step{"Nothing is written; the chat answers without it", F.System{}, False{}, []}
  ]
