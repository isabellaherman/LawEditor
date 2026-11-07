# LawEditor: what each agent may do. Pure; its rules are in LAWS.bend.

import Base

# The tools an agent can be given.
def read() -> U32: 0
def edit() -> U32: 1
def write() -> U32: 2
def run_bend() -> U32: 3

# The agents: the chat, and the one that writes laws.
def chat() -> U32: 0
def law_agent() -> U32: 1

# The tools each agent is given.
def tools(mode: U32) -> List<U32>:
  match mode:
    case 0:
      [read()]
    case n:
      [read(), edit(), write(), run_bend()]

# ---------- Each CLI's flags, from the tools ----------

# The name Claude's --allowedTools gives each tool.
def claude_name(t: U32) -> String:
  match t:
    case 0:
      "Read"
    case 1:
      "Edit"
    case 2:
      "Write"
    case n:
      "Bash(bend:*)"

def claude_names(ts: List<U32>) -> List<&2, String>:
  match ts:
    case Nil{}:
      Nil{}
    case h <> t:
      claude_name(h) <> claude_names(t)

# What Claude's --allowedTools gets for an agent: its tools, by name, joined by commas.
def claude_tools(mode: U32) -> String:
  String.join(claude_names(tools(mode)), ",")

# Does the agent change files (edit or write)?
def changes(ts: List<U32>) -> Bool:
  match ts:
    case Nil{}:
      False{}
    case +h <> t:
      (U32.is_eq(h, edit()) || U32.is_eq(h, write())) || changes(t)

# Codex's --sandbox for an agent: one that changes no file only reads.
def codex_sandbox.at(changes: Bool) -> String:
  match changes:
    case True{}:
      "workspace-write"
    case False{}:
      "read-only"

def codex_sandbox(mode: U32) -> String:
  codex_sandbox.at(changes(tools(mode)))
