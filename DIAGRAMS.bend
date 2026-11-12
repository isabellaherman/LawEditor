# LawEditor: the harness's diagrams, as Mermaid text, made from the flows themselves.
#
#   bend DIAGRAMS.bend          prints every diagram, exactly as it would be sent
#   bend DIAGRAMS.bend <url>    sends each one that changed (HTTP POST, header Title) to <url>, from a clean commit only
#
# Nothing here is typed by hand: each diagram is a flow the code already has (HEAR.flow(), OFFER.flow(),
# ARCH.flow()), and its top node names the commit it came from.

import Base
import ./FLOW.bend as F
import ./HEAR.bend as H
import ./OFFER.bend as O
import ./ARCH.bend as A

# ---------- Mermaid text ----------

def swap(s: String, c: Char, e: String) -> String:
  String.join(String.split(s, c), e)

# Characters Mermaid reads as syntax become entities (';' first: the entities end in ';').
def esc(s: String) -> String:
  swap(swap(swap(swap(swap(swap(swap(swap(swap(swap(s, ';', "#59;"), '"', "#quot;"), '(', "#40;"), ')', "#41;"), '[', "#91;"), ']', "#93;"), '{', "#123;"), '}', "#125;"), '|', "#124;"), '<', "#lt;")

def color(w: F.Who) -> String:
  match w:
    case F.Person{}:
      "blue"
    case F.Skill{}:
      "yellow"
    case F.System{}:
      "green"

def writes_mark(x: Bool) -> String:
  match x:
    case True{}:
      ", writes a file"
    case False{}:
      ""

def id(i: Nat) -> String:
  "S" ++ Nat.show(i)

def arrow.at(empty: Bool, +from: String, to: Nat, label: String) -> String:
  match empty:
    case True{}:
      "  " ++ from ++ " --> " ++ id(to) ++ "\n"
    case False{}:
      "  " ++ from ++ " -->|" ++ esc(label) ++ "| " ++ id(to) ++ "\n"

def arrow(+from: String, g: F.Go) -> String:
  match g:
    case F.Go{t, +l}:
      arrow.at(String.is_empty(l), from, t, l)

def arrows(gs: List<&2, F.Go>, +from: String) -> String:
  match gs:
    case Nil{}:
      ""
    case h <> t:
      arrow(from, h) ++ arrows(t, from)

def node(s: F.Step, +i: Nat) -> String:
  match s:
    case F.Step{n, +w, x, g}:
      "  " ++ id(i) ++ "[" ++ esc(n ++ writes_mark(x)) ++ "]:::" ++ color(w) ++ "\n" ++ arrows(g, id(i))

def nodes(ss: List<&2, F.Step>, +i: Nat) -> String:
  match ss:
    case Nil{}:
      ""
    case h <> t:
      node(h, i) ++ nodes(t, (1n + i : Nat))

def head(source: String) -> String:
  "%% borzoi from LawEditor\nflowchart TD\n  SRC[" ++ esc(source) ++ "] --> S0\n"

def mermaid(source: String, f: List<&2, F.Step>) -> String:
  head(source) ++ nodes(f, 0n)

# The legend: who acts in a step, from FLOW.bend, colored by the same color() as every diagram.
def legend(source: String) -> String:
  "%% borzoi from LawEditor\nflowchart TD\n  SRC[" ++ esc(source) ++ "] --> L\n"
  ++ "  L[Who acts in a step]\n"
  ++ "  L --> P[" ++ esc(F.who_means(F.Person{})) ++ "]:::" ++ color(F.Person{}) ++ "\n"
  ++ "  L --> K[" ++ esc(F.who_means(F.Skill{})) ++ "]:::" ++ color(F.Skill{}) ++ "\n"
  ++ "  L --> Y[" ++ esc(F.who_means(F.System{})) ++ "]:::" ++ color(F.System{}) ++ "\n"
  ++ "  L --> W[" ++ esc("Any step" ++ writes_mark(True{})) ++ "]\n"

# ---------- The diagrams: (title, text) ----------

def diagrams(+commit: String) -> List<&1, String & String>:
  [
    ("Harness: legend", legend("FLOW.bend at " ++ commit)),
    ("Harness: today", mermaid("ARCH.flow at " ++ commit, A.flow())),
    ("Flow: the chat hears rules", mermaid("HEAR.flow at " ++ commit, H.flow())),
    ("Flow: the chat offers the mode", mermaid("OFFER.flow at " ++ commit, O.flow()))
  ]

# ---------- Files ----------

def text_of(r: Result<&1, &1, U32 & String, String>) -> String:
  match r:
    case Fail{e}:
      ""
    case Done{text}:
      text

def read_got(got: File & Result<&1, &1, U32 & String, String>) -> IO(String):
  (f, r) = got
  do IO<String>:
    File.close(f)
    return text_of(r)

def read_open(r: Result<&1, &1, U32 & String, File>) -> IO(String):
  match r:
    case Fail{e}:
      IO.pure(String, "")
    case Done{f}:
      do IO<String>:
        got : File & Result<&1, &1, U32 & String, String> <- File.read(f, 4194304)
        read_got(got)

def read_file(path: String) -> IO(String):
  do IO<String>:
    r : Result<&1, &1, U32 & String, File> <- File.open(path, "r")
    read_open(r)

def write_done(w: File & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (f, r) = w
  File.close(f)

def write_open(r: Result<&1, &1, U32 & String, File>, data: String) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.pure(Unit, Unit{})
    case Done{f}:
      do IO<Unit>:
        w : File & Result<&1, &1, U32 & String, Unit> <- File.write(f, data)
        write_done(w)

def write_file(path: String, data: String) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, File> <- File.open(path, "w")
    write_open(r, data)

# ---------- Running ----------

def out(r: Result<&1, &1, U32 & String, U32 & (String & String)>) -> String:
  match r:
    case Fail{(code, msg)}:
      ""
    case Done{(code, (o, e))}:
      String.trim(o)

def dirty.at(clean: Bool) -> String:
  match clean:
    case True{}:
      ""
    case False{}:
      " + uncommitted changes"

def dirty(status: String) -> String:
  dirty.at(String.is_empty(status))

def commit_of(hash: String, +status: String) -> String:
  hash ++ dirty(status)

def print_all(ds: List<&1, String & String>) -> IO(Unit):
  match ds:
    case Nil{}:
      do IO<Unit>:
        return Unit{}
    case (t, m) <> rest:
      do IO<Unit>:
        IO.print("==== " ++ t ++ "\n" ++ m)
        print_all(rest)

# Borzoi keeps every version it gets, so a diagram is sent only when it changed: the last one sent
# lives in .borzoi/<n>.mmd (not in git). The top line (its commit) doesn't count as a change.
def body(m: String) -> String:
  String.join(List.drop(&2, String, String.lines(m), 3n), "\n")

def last_path(i: Nat) -> String:
  ".borzoi/" ++ Nat.show(i) ++ ".mmd"

def sent.at(ok: Bool, +t: String, m: String, i: Nat) -> IO(Unit):
  match ok:
    case True{}:
      do IO<Unit>:
        write_file(last_path(i), m)
        IO.print("sent: " ++ t)
    case False{}:
      IO.print("NOT sent (the address refused it): " ++ t)

def sent(r: Result<&1, &1, U32 & String, U32 & (String & String)>, +t: String, m: String, i: Nat) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.print("NOT sent (curl did not run): " ++ t)
    case Done{(code, o)}:
      sent.at(U32.is_eq(code, 0), t, m, i)

def send_one.at(same: Bool, +t: String, +m: String, +url: String, +i: Nat) -> IO(Unit):
  match same:
    case True{}:
      IO.print("unchanged, not sent: " ++ t)
    case False{}:
      do IO<Unit>:
        r : Result<&1, &1, U32 & String, U32 & (String & String)> <- Process.run("curl", ["-s", "-f", "-X", "POST", "-H", "Title: " ++ t, "--data-binary", "@-", url], m, 65536, 20000)
        sent(r, t, m, i)

def send_all(ds: List<&1, String & String>, +url: String, +i: Nat) -> IO(Unit):
  match ds:
    case Nil{}:
      do IO<Unit>:
        return Unit{}
    case (+t, +m) <> rest:
      do IO<Unit>:
        last : String <- read_file(last_path(i))
        send_one.at(String.eq(body(last), body(m)), t, m, url, i)
        send_all(rest, url, (1n + i : Nat))

# Only a clean commit is sent, so every version in Borzoi names a real commit.
def send_clean(clean: Bool, ds: List<&1, String & String>, +url: String) -> IO(Unit):
  match clean:
    case True{}:
      do IO<Unit>:
        p : Result<&1, &1, U32 & String, U32 & (String & String)> <- Process.run("mkdir", ["-p", ".borzoi"], "", 4096, 10000)
        send_all(ds, url, 0n)
    case False{}:
      IO.print("Not sent: commit first. Every version sent names a commit.")

def go(args: List<String>, clean: Bool, ds: List<&1, String & String>) -> IO(Unit):
  match args:
    case Nil{}:
      print_all(ds)
    case p <> rest:
      match rest:
        case Nil{}:
          print_all(ds)
        case +url <> more:
          send_clean(clean, ds, url)

def run(args: List<String>, hash: String, +status: String) -> IO(Unit):
  go(args, String.is_empty(status), diagrams(commit_of(hash, status)))

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    h : Result<&1, &1, U32 & String, U32 & (String & String)> <- Process.run("git", ["rev-parse", "--short", "HEAD"], "", 4096, 10000)
    s : Result<&1, &1, U32 & String, U32 & (String & String)> <- Process.run("git", ["status", "--porcelain"], "", 65536, 10000)
    run(args, out(h), out(s))
