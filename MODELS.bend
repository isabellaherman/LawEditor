# LawEditor: the models each AI offers, read from its own CLI. Pure; server.bend runs the CLI.
#
# Claude: `claude --help` lists the aliases --model takes ("'fable', 'opus', or 'sonnet'"),
#   each the latest model of its family. That is what Claude Code's own /model offers.
# Codex: `codex debug models` prints its model catalog as JSON; each model has a "slug" and a "display_name".
#
# Both answer one model per line: "<id>\t<name>".

import Base

# ---------- Text ----------

# The n-th item of a list of strings, or "".
def nth(xs: List<&2, String>, n: Nat) -> String:
  match xs n:
    case Nil{} _:
      ""
    case h <> t 0n:
      h
    case h <> t 1n+k:
      nth(t, k)

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

# The text up to the first c. Tail calls: a catalog is long.
def upto.go(s: String, here: Bool, +c: Char, acc: String) -> String:
  match s here:
    case SNil{} _:
      String.reverse(acc)
    case SCon{h, t} True{}:
      String.reverse(acc)
    case SCon{+h, +t} False{}:
      upto.go(t, String.starts_with(t, SCon{c, SNil{}}), c, SCon{h, acc})

def upto(+s: String, +c: Char) -> String:
  upto.go(s, String.starts_with(s, SCon{c, SNil{}}), c, "")

# s cut wherever marker starts: the first piece is what comes before it; every other piece starts with it.
# Tail calls: each piece is built backwards in cur, the pieces backwards in done, and both turned at the end.
def pieces.go(s: String, here: Bool, +marker: String, cur: String, done: List<&2, String>) -> List<&2, String>:
  match s here:
    case SNil{} _:
      List.reverse(&2, String, String.reverse(cur) <> done)
    case SCon{+h, +t} True{}:
      pieces.go(t, String.starts_with(t, marker), marker, SCon{h, SNil{}}, String.reverse(cur) <> done)
    case SCon{+h, +t} False{}:
      pieces.go(t, String.starts_with(t, marker), marker, SCon{h, cur}, done)

def pieces(+s: String, +marker: String) -> List<&2, String>:
  pieces.go(s, String.starts_with(s, marker), marker, "", [])

def capital(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{h, t}:
      SCon{Char.to_upper(h), t}

# ---------- Claude ----------

# The quoted words of a list like "'fable', 'opus', or 'sonnet'": every other piece between quotes.
def quoted(xs: List<&2, String>, inside: Bool) -> List<&2, String>:
  match xs inside:
    case Nil{} _:
      []
    case h <> t True{}:
      h <> quoted(t, False{})
    case h <> t False{}:
      quoted(t, True{})

def claude.lines(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      []
    case +h <> t:
      (h ++ "\t" ++ capital(h)) <> claude.lines(t)

def claude(help: String) -> String:
  String.join(claude.lines(quoted(String.split(upto(after(help, "alias for the latest model (e.g."), ')'), '\''), False{})), "\n")

# ---------- Codex ----------

def codex.line(+piece: String) -> String:
  upto(String.drop(piece, String.length("{\"slug\":\"")), '"') ++ "\t" ++ upto(after(piece, "\"display_name\":\""), '"')

def codex.lines.if(listed: Bool, +h: String, rest: List<&2, String>) -> List<&2, String>:
  match listed:
    case True{}:
      codex.line(h) <> rest
    case False{}:
      rest

# Every piece after the first is one model; only the ones it lists ("visibility":"list") are offered.
def codex.lines(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      []
    case +h <> t:
      codex.lines.if(String.contains(h, "\"visibility\":\"list\""), h, codex.lines(t))

def codex.models(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      []
    case h <> t:
      codex.lines(t)

def codex(catalog: String) -> String:
  String.join(codex.models(pieces(catalog, "{\"slug\":\"")), "\n")
