# LawEditor: what each agent may do. Pure; its rules are in LAWS.bend.

import Base

# ---------- Tools ----------

# The tools an agent can be given.
type AgentTool is Data:
  AgentTool.Read{}
  AgentTool.Edit{}
  AgentTool.Write{}
  AgentTool.RunBend{}

def read() -> AgentTool: AgentTool.Read{}
def edit() -> AgentTool: AgentTool.Edit{}
def write() -> AgentTool: AgentTool.Write{}
def run_bend() -> AgentTool: AgentTool.RunBend{}

# What each tool does. Reading only looks; editing and writing change a file;
# running bend runs a command (bend, and only bend).
def changes_file(t: AgentTool) -> Bool:
  match t:
    case AgentTool.Read{}:
      False{}
    case AgentTool.Edit{}:
      True{}
    case AgentTool.Write{}:
      True{}
    case AgentTool.RunBend{}:
      False{}

def runs_command(t: AgentTool) -> Bool:
  match t:
    case AgentTool.Read{}:
      False{}
    case AgentTool.Edit{}:
      False{}
    case AgentTool.Write{}:
      False{}
    case AgentTool.RunBend{}:
      True{}

# ---------- Agents ----------

# The agents: the chat, and the one that writes laws (Generate). There are no others.
type Agent is Data:
  Agent.Chat{}
  Agent.LawAgent{}

def chat() -> Agent: Agent.Chat{}
def law_agent() -> Agent: Agent.LawAgent{}

# ---------- The chat's modes (HARNESS.md) ----------

# What the person picks under the message field.
type Mode is Data:
  Mode.OnlyRead{}
  Mode.AskBeforeChanges{}
  Mode.ChangeFreely{}

# The tools a mode gives the chat. What a mode asks before doing comes later (HARNESS.md, "When it asks").
def mode_tools(m: Mode) -> List<&2, AgentTool>:
  match m:
    case Mode.OnlyRead{}:
      [read()]
    case Mode.AskBeforeChanges{}:
      [read()]
    case Mode.ChangeFreely{}:
      [read(), edit(), write()]

# Is the mode built yet? Only read, and Ask before changes. Change freely comes later.
def mode_ready(m: Mode) -> Bool:
  match m:
    case Mode.OnlyRead{}:
      True{}
    case Mode.AskBeforeChanges{}:
      True{}
    case Mode.ChangeFreely{}:
      False{}

# Does the mode ask the person before an action? Only an AI that can ask may use it:
# Claude can (ASK.bend); Codex can't yet (it would need its app-server).
def mode_asks(m: Mode) -> Bool:
  match m:
    case Mode.OnlyRead{}:
      False{}
    case Mode.AskBeforeChanges{}:
      True{}
    case Mode.ChangeFreely{}:
      False{}

def can_ask(codex: Bool) -> Bool:
  Bool.not(codex)

# What the chat is told about its mode (the ## Mode section of its prompt).
def mode_told(m: Mode) -> String:
  match m:
    case Mode.OnlyRead{}:
      "Only read. You may read the files. Never edit or create a file, and run no command."
    case Mode.AskBeforeChanges{}:
      "Ask before changes. You may read the files. When the person asks for a change, make it with your tools; if it needs their yes, you are stopped and they are asked. Never change LAWS.bend."
    case Mode.ChangeFreely{}:
      "Change freely. You may read, edit and create files. Never change LAWS.bend."

def mode_section(m: Mode) -> String:
  "## Mode\n\n" ++ mode_told(m)

# What the chat may never do, in any mode: change the project's laws (Claude's --disallowedTools; a deny wins).
def never() -> List<&2, String>:
  ["Edit(LAWS.bend)", "Write(LAWS.bend)"]

# The chat's mode today.
def chat_mode() -> Mode: Mode.OnlyRead{}

# The tools each agent is given. The chat's come from its mode.
def tools(a: Agent) -> List<&2, AgentTool>:
  match a:
    case Agent.Chat{}:
      mode_tools(chat_mode())
    case Agent.LawAgent{}:
      [read(), edit(), write(), run_bend()]

# ---------- The modes, for the page (it counts them 0, 1, 2) ----------

def mode_at(i: U32) -> Mode:
  match i:
    case 0:
      Mode.OnlyRead{}
    case 1:
      Mode.AskBeforeChanges{}
    case n:
      Mode.ChangeFreely{}

def mode_index(m: Mode) -> U32:
  match m:
    case Mode.OnlyRead{}:
      0
    case Mode.AskBeforeChanges{}:
      1
    case Mode.ChangeFreely{}:
      2

def mode_count() -> U32: 3

# The name the picker shows.
def mode_name.of(m: Mode) -> String:
  match m:
    case Mode.OnlyRead{}:
      "Only read"
    case Mode.AskBeforeChanges{}:
      "Ask before changes"
    case Mode.ChangeFreely{}:
      "Change freely"

def mode_name(i: U32) -> String:
  mode_name.of(mode_at(i))

# Can the person pick it? Only a mode that is built, and one that asks only with an AI that can ask.
def mode_can_pick.of(m: Mode, codex: Bool) -> Bool:
  match m:
    case Mode.OnlyRead{}:
      True{}
    case Mode.AskBeforeChanges{}:
      can_ask(codex)
    case Mode.ChangeFreely{}:
      False{}

def mode_can_pick(i: U32, codex: Bool) -> Bool:
  mode_can_pick.of(mode_at(i), codex)

# Does the mode at i ask? (The page sends the chat to /api/ask then.)
def mode_asks_at(i: U32) -> Bool:
  mode_asks(mode_at(i))

def chat_mode_index() -> U32:
  mode_index(chat_mode())

# Does any of these tools change a file? Run a command?
def changes(ts: List<&2, AgentTool>) -> Bool:
  match ts:
    case Nil{}:
      False{}
    case h <> t:
      changes_file(h) || changes(t)

def runs(ts: List<&2, AgentTool>) -> Bool:
  match ts:
    case Nil{}:
      False{}
    case h <> t:
      runs_command(h) || runs(t)

# ---------- Each CLI's flags, from the tools ----------

# The name Claude's --allowedTools gives each tool.
def claude_name(t: AgentTool) -> String:
  match t:
    case AgentTool.Read{}:
      "Read"
    case AgentTool.Edit{}:
      "Edit"
    case AgentTool.Write{}:
      "Write"
    case AgentTool.RunBend{}:
      "Bash(bend:*)"

def claude_names(ts: List<&2, AgentTool>) -> List<&2, String>:
  match ts:
    case Nil{}:
      Nil{}
    case h <> t:
      claude_name(h) <> claude_names(t)

# What Claude's --allowedTools gets for an agent: its tools, by name, joined by commas.
def claude_tools(a: Agent) -> String:
  String.join(claude_names(tools(a)), ",")

# Codex's --sandbox for an agent: one that changes no file only reads.
# Codex can't allow a single command: in workspace-write it may run any command in the folder.
def codex_sandbox.at(changes: Bool) -> String:
  match changes:
    case True{}:
      "workspace-write"
    case False{}:
      "read-only"

def codex_sandbox(a: Agent) -> String:
  codex_sandbox.at(changes(tools(a)))
