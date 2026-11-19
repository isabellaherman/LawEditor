# LawEditor's engine: files and programs. What the rest of the engine is made of.

import Base

# ---------- Where the engine runs ----------
# root: LawEditor's own folder (its page in dist/, what the AIs are told in harness/). port: where it
# listens. pages: the second port, where what the projects built is served (0 when there is none).
type Ctx is Data:
  Ctx{root: String, port: U32, pages: U32}

def root(cx: Ctx) -> String:
  match cx:
    case Ctx{root, port, pages}:
      root

def port(cx: Ctx) -> U32:
  match cx:
    case Ctx{root, port, pages}:
      port

def pages(cx: Ctx) -> U32:
  match cx:
    case Ctx{root, port, pages}:
      pages

# What an AI is told: AGENT.md (the law agent), CHAT.md and HEAR.md (the chat), HARNESS.md (its modes).
def told(cx: Ctx, name: String) -> String:
  root(cx) ++ "/harness/" ++ name

def address(cx: Ctx) -> String:
  "127.0.0.1:" ++ U32.show(port(cx))

def pages_address(cx: Ctx) -> String:
  "127.0.0.1:" ++ U32.show(pages(cx))

# ---------- Text ----------

def nth(xs: List<&2, String>, n: Nat) -> String:
  match xs n:
    case Nil{} _:
      ""
    case h <> t 0n:
      h
    case h <> t 1n+k:
      nth(t, k)

# The part of a path after a prefix: "/api/models/claude" less "/api/models/" is "claude".
def after(s: String, prefix: String) -> String:
  String.drop(s, String.length(prefix))

def pick(c: Bool, a: String, b: String) -> String:
  match c:
    case True{}:
      a
    case False{}:
      b

# xs, then rest: an args list built as one.
def with_each(xs: List<&2, String>, rest: List<String>) -> List<String>:
  match xs:
    case Nil{}:
      rest
    case h <> t:
      h <> with_each(t, rest)

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

# A whole file as text, or "" if it can't be read.
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

# Adds to the end of a file (a conversation's events: nothing is ever taken out).
def append_file(path: String, data: String) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, File> <- File.open(path, "a")
    write_open(r, data)

# ---------- Programs ----------

# A program's exit code and what it printed (stdout, then stderr), or 127 if it can't start.
def run_out(r: Result<&1, &1, U32 & String, U32 & (String & String)>) -> U32 & String:
  match r:
    case Fail{(code, msg)}:
      (127, msg)
    case Done{(code, (out, err))}:
      (code, out ++ err)

# The same, but what it said on its errors is kept only when it failed: a CLI that tells its own progress
# there (Codex prints its banner, the prompt and its log) answers with its words alone.
def run_out.quiet.pick(+code: U32, +out: String, err: String) -> U32 & String:
  (code, pick(U32.is_eq(code, 0), out, out ++ err))

def run_out.quiet(r: Result<&1, &1, U32 & String, U32 & (String & String)>) -> U32 & String:
  match r:
    case Fail{(code, msg)}:
      (127, msg)
    case Done{(code, (out, err))}:
      run_out.quiet.pick(code, out, err)

def run_quiet(program: String, args: List<String>, timeout_ms: U32) -> IO(U32 & String):
  do IO<U32 & String>:
    r : Result<&1, &1, U32 & String, U32 & (String & String)> <- Process.run(program, args, "", 4194304, timeout_ms)
    return run_out.quiet(r)

# A program run in a folder, answering with what it printed (its errors only when it failed).
def run_in_quiet(dir: String, program: String, args: List<String>, timeout_ms: U32) -> IO(U32 & String):
  run_quiet("sh", "-c" <> "cd \"$0\" && exec \"$@\"" <> dir <> program <> args, timeout_ms)

def run(program: String, args: List<String>, timeout_ms: U32) -> IO(U32 & String):
  do IO<U32 & String>:
    r : Result<&1, &1, U32 & String, U32 & (String & String)> <- Process.run(program, args, "", 4194304, timeout_ms)
    return run_out(r)

def printed(r: U32 & String) -> String:
  (code, out) = r
  out

# A small shell script and what it printed. Every value goes in as an argument ("$0", "$1", …), never
# pasted into the script.
def sh(script: String, args: List<String>, timeout_ms: U32) -> IO(String):
  do IO<String>:
    r : U32 & String <- run("sh", "-c" <> script <> args, timeout_ms)
    return printed(r)

# A program run in a folder.
def run_in(dir: String, program: String, args: List<String>, timeout_ms: U32) -> IO(U32 & String):
  run("sh", "-c" <> "cd \"$0\" && exec \"$@\"" <> dir <> program <> args, timeout_ms)

# A program run in a folder, with what it prints going to a file as it prints, so another request can read
# it meanwhile. Its errors go to a file beside it (<file>.err), so nothing it starts can hold this call open
# after it ends; its process id goes there too (<file>.pid), so Stop can end it.
def run_to.out(r: U32 & String, text: String, err: String) -> U32 & String:
  (code, none) = r
  (code, text ++ err)

def run_to(dir: String, +file: String, program: String, args: List<String>, timeout_ms: U32) -> IO(U32 & String):
  do IO<U32 & String>:
    r : Result<&1, &1, U32 & String, U32 & (String & String)> <- Process.run("sh", "-c" <> "out=\"$1\"; case \"$out\" in /*) ;; *) out=\"$(pwd)/$out\";; esac; echo $$ > \"$out.pid\"; cd \"$0\" && shift && exec \"$@\" > \"$out\" 2> \"$out.err\"" <> dir <> file <> program <> args, "", 4194304, timeout_ms)
    text : String <- read_file(file)
    err : String <- read_file(file ++ ".err")
    return run_to.out(run_out(r), text, err)

# ---------- Waiting ----------

# Read a file every 300 ms until it says something (said: the last read, trimmed).
def wait(fuel: Nat, +path: String, said: String) -> IO(String):
  match fuel said:
    case 0n _:
      IO.pure(String, "")
    case _ SCon{h, t}:
      IO.pure(String, SCon{h, t})
    case 1n+f SNil{}:
      do IO<String>:
        IO.sleep(300)
        got : String <- read_file(path)
        wait(f, path, String.trim(got))

# ---------- Names ----------

def id_of(r: Result<&1, &1, U32 & String, U32>) -> String:
  match r:
    case Fail{e}:
      "0"
    case Done{n}:
      U32.hex(n)

# A new name for a turn: letters and digits, never used before.
def new_id() -> IO(String):
  do IO<String>:
    a : Result<&1, &1, U32 & String, U32> <- IO.random_u32()
    b : Result<&1, &1, U32 & String, U32> <- IO.random_u32()
    return "t" ++ id_of(a) ++ id_of(b)

def env_or(r: Result<&1, &1, U32 & String, String>, d: String) -> String:
  match r:
    case Fail{e}:
      d
    case Done{v}:
      v

def env.at(+v: String, d: String) -> String:
  pick(String.is_empty(v), d, v)

# A setting from the environment, or what to use without it.
def env(name: String, +d: String) -> IO(String):
  do IO<String>:
    r : Result<&1, &1, U32 & String, String> <- IO.get_env(name)
    return env.at(env_or(r, ""), d)
