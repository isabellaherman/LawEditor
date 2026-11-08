# LawEditor: the chat asks before it acts (HARNESS.md, "Ask before changes"). Pure; server.bend runs Claude.
#
# Claude runs with --permission-prompts none: what its tools don't allow is refused, and its
# stream-json output says so: {"subtype":"permission_denied","tool_name":"Edit","tool_use_id":"…"}.
# The tool call itself came earlier: {"type":"tool_use","id":"…","name":"Edit","input":{…}}.
# This reads both and turns them into a question for the person. If they allow it, the server
# resumes the same session (--resume) with that one action allowed.

import Base

# ---------- Text ----------

# The text after the first place marker appears ("" if it never does).
def after.at(s: String, +marker: String, here: Bool) -> String:
  match s here:
    case SNil{} _:
      ""
    case SCon{h, t} True{}:
      String.drop(SCon{h, t}, String.length(marker))
    case SCon{h, +t} False{}:
      after.at(t, marker, String.starts_with(t, marker))

def after(+s: String, +marker: String) -> String:
  after.at(s, marker, String.starts_with(s, marker))

# A JSON string's text, from just after its opening quote to the closing one.
# \n and \t become a new line and a tab; any other \x becomes x (\" \\ \/).
# esc: the last char was a backslash; quote and back: s starts with " or \.
def jstr.code(+c: Char, n: Bool, tab: Bool) -> Char:
  match n tab:
    case True{} _:
      Char.from_u32(10)
    case False{} True{}:
      Char.from_u32(9)
    case False{} False{}:
      c

def jstr.go(s: String, acc: String, esc: Bool, quote: Bool, back: Bool) -> String:
  match s esc quote back:
    case SNil{} _ _ _:
      String.reverse(acc)
    case SCon{+h, +t} True{} _ _:
      jstr.go(t, SCon{jstr.code(h, Char.is_eq(h, 'n'), Char.is_eq(h, 't')), acc}, False{}, String.starts_with(t, "\""), String.starts_with(t, "\\"))
    case SCon{h, t} False{} True{} _:
      String.reverse(acc)
    case SCon{h, t} False{} False{} True{}:
      jstr.go(t, acc, True{}, False{}, False{})
    case SCon{+h, +t} False{} False{} False{}:
      jstr.go(t, SCon{h, acc}, False{}, String.starts_with(t, "\""), String.starts_with(t, "\\"))

def jstr(+s: String) -> String:
  jstr.go(s, "", False{}, String.starts_with(s, "\""), String.starts_with(s, "\\"))

# The string value of "key" at its first place in s ("" if it isn't there).
def field(+s: String, key: String) -> String:
  jstr(after(s, "\"" ++ key ++ "\":\""))

# The last piece of a path: "/a/b/GDD.md" is "GDD.md".
def base_name.of(m: Maybe<&2, String>, path: String) -> String:
  match m:
    case None{}:
      path
    case Some{name}:
      name

def base_name(+path: String) -> String:
  base_name.of(List.last(&2, String, String.split(path, '/')), path)

# ---------- What Claude's output says ----------

def session(+out: String) -> String:
  field(out, "session_id")

# Was an action refused because it needs the person's yes?
def denied(+out: String) -> Bool:
  String.contains(out, "\"subtype\":\"permission_denied\"")

# The refused action, from the denial on: its tool, and its call id.
def denial(+out: String) -> String:
  after(out, "\"subtype\":\"permission_denied\"")

def tool(+out: String) -> String:
  field(denial(out), "tool_name")

# The input of the refused call: what comes after its id.
def input(+out: String) -> String:
  after(out, "\"id\":\"" ++ field(denial(out), "tool_use_id") ++ "\"")

def is_file_tool(+t: String) -> Bool:
  (String.eq(t, "Edit") || String.eq(t, "Write"))

# What it acts on: a file for Edit and Write, a command for Bash.
def target.of(+inp: String, file: Bool) -> String:
  match file:
    case True{}:
      field(inp, "file_path")
    case False{}:
      field(inp, "command")

def target(+t: String, +inp: String) -> String:
  target.of(inp, is_file_tool(t))

# The one action the person allows, as a Claude rule: Edit(//abs/path), Bash(exact command), or the tool.
# (In Claude's rules, //path is a path from the root of the disk.) A file rule is always Edit: Claude's Edit
# rules cover every tool that changes a file, Write included; a Write(…) rule doesn't let Write run.
def grant.of(+t: String, +what: String, file: Bool, bash: Bool) -> String:
  match file bash:
    case True{} _:
      "Edit(/" ++ what ++ ")"
    case False{} True{}:
      "Bash(" ++ what ++ ")"
    case False{} False{}:
      t

def grant(+t: String, +what: String) -> String:
  grant.of(t, what, is_file_tool(t), String.eq(t, "Bash"))

# What the person reads: the question, and what would change.
def question.of(+t: String, +what: String, edit: Bool, write: Bool, bash: Bool) -> String:
  match edit write bash:
    case True{} _ _:
      "Allow the chat to edit " ++ base_name(what) ++ "?"
    case False{} True{} _:
      "Allow the chat to write " ++ base_name(what) ++ "?"
    case False{} False{} True{}:
      "Allow the chat to run this command?"
    case False{} False{} False{}:
      "Allow the chat to use " ++ t ++ "?"

def question(+t: String, +what: String) -> String:
  question.of(t, what, String.eq(t, "Edit"), String.eq(t, "Write"), String.eq(t, "Bash"))

def preview.of(+inp: String, edit: Bool, write: Bool) -> String:
  match edit write:
    case True{} _:
      field(inp, "new_string")
    case False{} True{}:
      field(inp, "content")
    case False{} False{}:
      field(inp, "command")

def preview(+t: String, +inp: String) -> String:
  preview.of(inp, String.eq(t, "Edit"), String.eq(t, "Write"))

# The answer, once nothing was refused. Only the last event, {"type":"result",…}, has a "result" key
# (inside a message's text, a quote is escaped, so "result":" can't appear there).
def result(+out: String) -> String:
  field(out, "result")

# What the page gets. "ask" lines: session, grant, question, then the preview (it may span lines).
def reply.ask(+out: String) -> String:
  "ask\n" ++ session(out) ++ "\n" ++ grant(tool(out), target(tool(out), input(out))) ++ "\n" ++
  question(tool(out), target(tool(out), input(out))) ++ "\n" ++ preview(tool(out), input(out))

def reply.at(+out: String, asks: Bool) -> String:
  match asks:
    case True{}:
      reply.ask(out)
    case False{}:
      "ok\n" ++ result(out)

def reply(+out: String) -> String:
  reply.at(out, denied(out))

# ---------- The person's answer ----------

def allow() -> U32: 0
def always() -> U32: 1
def dont() -> U32: 2

# Does the answer let the action run? Is it kept for the rest of the session?
def allows(+a: U32) -> Bool:
  (U32.is_eq(a, 0) || U32.is_eq(a, 1))

def keeps(+a: U32) -> Bool:
  U32.is_eq(a, 1)

# What the chat is told when its session resumes. Claude's denial said "don't retry, it will be denied
# for the rest of this session"; once allowed, it must hear that this changed, or it won't try again.
def told(allowed: Bool, +grants: String) -> String:
  match allowed:
    case True{}:
      "The person allowed it: you now have permission for " ++ String.join(String.split(grants, '\t'), ", ") ++ ". The earlier denial no longer applies. Try that action again."
    case False{}:
      "The person did not allow it. Don't do it; answer them without it."
