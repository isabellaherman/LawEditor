# LawEditor server. Run it from your project folder:
#
#   bend /path/to/LawEditor/server.bend /path/to/LawEditor/dist /path/to/LawEditor/AGENT.md
#
# It serves the editor, keeps the project's files (GDD.md, TYPES.bend, LAWS.bend)
# in the folder it runs from, and runs the agent (claude or codex) there.

import Base
import ./MODELS.bend as Models
import ./POLICY.bend as Policy

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

# The n-th word of the request line: "GET /path HTTP/1.1".
def req_word(s: String, n: Nat) -> String:
  nth(String.split(s, ' '), n)

# Everything after the blank line that ends the headers.
def req_body.at(s: String, here: Bool) -> String:
  match s here:
    case SNil{} _:
      ""
    case SCon{h, t} True{}:
      String.drop(SCon{h, t}, 4n)
    case SCon{h, +t} False{}:
      req_body.at(t, String.starts_with(t, "\r\n\r\n"))

def req_body(+s: String) -> String:
  req_body.at(s, String.starts_with(s, "\r\n\r\n"))

# The part of a path after a prefix: "/api/file/LAWS.bend" less "/api/file/" is "LAWS.bend".
def after(s: String, prefix: String) -> String:
  String.drop(s, String.length(prefix))

def pick(c: Bool, a: String, b: String) -> String:
  match c:
    case True{}:
      a
    case False{}:
      b

# ---------- HTTP ----------

def content_type(+path: String) -> String:
  pick(String.ends_with(path, ".html"), "text/html; charset=utf-8",
  pick(String.ends_with(path, ".js"), "text/javascript; charset=utf-8",
  pick(String.ends_with(path, ".css"), "text/css; charset=utf-8",
  pick(String.ends_with(path, ".svg"), "image/svg+xml",
  pick(String.ends_with(path, ".webp"), "image/webp",
  pick(String.ends_with(path, ".png"), "image/png",
  "text/plain; charset=utf-8"))))))

def http(status: String, ctype: String, body: String) -> String:
  "HTTP/1.1 " ++ status ++ "\r\nContent-Type: " ++ ctype ++ "\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n" ++ body

def ok_text(body: String) -> String:
  http("200 OK", "text/plain; charset=utf-8", body)

def not_found() -> String:
  http("404 Not Found", "text/plain; charset=utf-8", "not found")

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

# A whole file as text, or "" if it can't be read.
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

# Create a file with a starting text, only if it doesn't exist yet.
def ensure_open(r: Result<&1, &1, U32 & String, File>, path: String, data: String) -> IO(Unit):
  match r:
    case Fail{e}:
      write_file(path, data)
    case Done{f}:
      File.close(f)

def ensure_file(+path: String, data: String) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, File> <- File.open(path, "r")
    ensure_open(r, path, data)

# The files the editor may read and write in the project folder.
def is_project_file(+name: String) -> Bool:
  (String.eq(name, "GDD.md") || String.eq(name, "TYPES.bend") || String.eq(name, "LAWS.bend"))

# ---------- Processes ----------

# Run a program; answer its exit code and output (stdout, then stderr), or 127 if it can't start.
def run_out(r: Result<&1, &1, U32 & String, U32 & (String & String)>) -> U32 & String:
  match r:
    case Fail{(code, msg)}:
      (127, msg)
    case Done{(code, (out, err))}:
      (code, out ++ err)

def run(program: String, args: List<String>, timeout_ms: U32) -> IO(U32 & String):
  do IO<U32 & String>:
    r : Result<&1, &1, U32 & String, U32 & (String & String)> <- Process.run(program, args, "", 4194304, timeout_ms)
    return run_out(r)

# Is the agent's command installed? `claude --version` / `codex --version`.
def connect_reply(r: U32 & String) -> String:
  (+code, out) = r
  pick(U32.is_eq(code, 0), ok_text("ok"), http("404 Not Found", "text/plain; charset=utf-8", "notfound"))

def connect(ai: String) -> IO(String):
  do IO<String>:
    r : U32 & String <- run(ai, ["--version"], 15000)
    return connect_reply(r)

# The command line for each agent: it may read and edit files here, and run bend.
def agent_args.pick(is_codex: Bool, prompt: String) -> List<String>:
  match is_codex:
    case True{}:
      ["exec", "--full-auto", prompt]
    case False{}:
      ["-p", prompt, "--allowedTools", "Read,Edit,Write,Bash(bend:*)", "--permission-mode", "acceptEdits"]

def agent_args(+ai: String, prompt: String) -> List<String>:
  agent_args.pick(String.eq(ai, "codex"), prompt)

# Bend checks the laws. A law that compiles but has no proof yet is fine (a TODO);
# an error points at a Location.
def check_reply(agent: U32 & String, check: U32 & String) -> String:
  (+acode, +aout) = agent
  (ccode, +cout) = check
  pick(U32.is_eq(acode, 127), ok_text("error\nCould not start the agent: " ++ aout),
  pick(String.starts_with(aout, "ERROR"), ok_text("error\n" ++ aout),
  pick(String.contains(cout, "Location:"), ok_text("error\n" ++ cout),
  pick(String.contains(aout, "law "), ok_text("ok\n" ++ aout),
  ok_text("error\nThe agent answered without a law:\n" ++ aout)))))

def generate(+ai: String, agent_md: String, sentence: String) -> IO(String):
  do IO<String>:
    rules : String <- read_file(agent_md)
    agent : U32 & String <- run(ai, agent_args(ai, rules ++ "\n\n## Sentence\n\n" ++ sentence), 600000)
    check : U32 & String <- run("bend", ["LAWS.bend", "--check-only"], 120000)
    return check_reply(agent, check)

# CHAT.md (what the chat is told) lives next to AGENT.md (what the law agent is told).
def chat_md(+agent_md: String) -> String:
  String.reverse(String.drop(String.reverse(agent_md), String.length("AGENT.md"))) ++ "CHAT.md"

# The chat: the agent answers the conversation so far, with the model picked in the chat.
# What it may do comes from POLICY.bend (LAWS.bend: it only reads). No model: the CLI's own default.
def chat_args.pick(is_codex: Bool, has_model: Bool, model: String, prompt: String) -> List<String>:
  match is_codex has_model:
    case True{} True{}:
      ["exec", "-m", model, "--sandbox", Policy.codex_sandbox(Policy.chat()), prompt]
    case True{} False{}:
      ["exec", "--sandbox", Policy.codex_sandbox(Policy.chat()), prompt]
    case False{} True{}:
      ["-p", prompt, "--model", model, "--allowedTools", Policy.claude_tools(Policy.chat())]
    case False{} False{}:
      ["-p", prompt, "--allowedTools", Policy.claude_tools(Policy.chat())]

def chat_args(+ai: String, +model: String, prompt: String) -> List<String>:
  chat_args.pick(String.eq(ai, "codex"), Bool.not(String.is_empty(model)), model, prompt)

def chat_reply(agent: U32 & String) -> String:
  (+code, +out) = agent
  pick(U32.is_eq(code, 127), ok_text("error\nCould not start the agent: " ++ out), ok_text("ok\n" ++ out))

# target: "<ai>/<model>" from /api/chat/<ai>/<model>.
def chat(+target: String, agent_md: String, conversation: String) -> IO(String):
  do IO<String>:
    rules : String <- read_file(chat_md(agent_md))
    agent : U32 & String <- run(nth(String.split(target, '/'), 0n), chat_args(nth(String.split(target, '/'), 0n), nth(String.split(target, '/'), 1n), rules ++ "\n\n## Chat\n\n" ++ conversation), 600000)
    return chat_reply(agent)

# The models an AI offers, asked to its own CLI (MODELS.bend reads the answer). Only claude and codex.
def is_ai(+ai: String) -> Bool:
  (String.eq(ai, "claude") || String.eq(ai, "codex"))

def models_args(is_codex: Bool) -> List<String>:
  match is_codex:
    case True{}:
      ["debug", "models"]
    case False{}:
      ["--help"]

def models_read(is_codex: Bool, +out: String) -> String:
  match is_codex:
    case True{}:
      Models.codex(out)
    case False{}:
      Models.claude(out)

def models_reply(is_codex: Bool, r: U32 & String) -> String:
  (code, +out) = r
  ok_text(models_read(is_codex, out))

def models.at(known: Bool, +ai: String) -> IO(String):
  match known:
    case True{}:
      do IO<String>:
        r : U32 & String <- run(ai, models_args(String.eq(ai, "codex")), 30000)
        return models_reply(String.eq(ai, "codex"), r)
    case False{}:
      IO.pure(String, not_found())

def models(+ai: String) -> IO(String):
  models.at(is_ai(ai), ai)

# ---------- Routes ----------

def static_reply(+text: String, +path: String) -> String:
  pick(String.is_empty(text), not_found(), http("200 OK", content_type(path), text))

def route_static.at(bad: Bool, +path: String, dist: String) -> IO(String):
  match bad:
    case True{}:
      IO.pure(String, not_found())
    case False{}:
      do IO<String>:
        text : String <- read_file(dist ++ path)
        return static_reply(text, path)

def route_static(+path: String, dist: String) -> IO(String):
  route_static.at(String.contains(path, ".."), path, dist)

def route_file_get.at(allowed: Bool, name: String) -> IO(String):
  match allowed:
    case True{}:
      do IO<String>:
        text : String <- read_file(name)
        return ok_text(text)
    case False{}:
      IO.pure(String, not_found())

def route_file_get(+name: String) -> IO(String):
  route_file_get.at(is_project_file(name), name)

def route_agent_md(agent_md: String) -> IO(String):
  do IO<String>:
    text : String <- read_file(agent_md)
    return ok_text(text)

def route_chat_md(+agent_md: String) -> IO(String):
  route_agent_md(chat_md(agent_md))

# GET: /api/models/<ai>, /api/connect/<ai>, /api/file/AGENT.md, /api/file/CHAT.md, /api/file/<name>, or a file of the page.
def route_get.files(is_file: Bool, +path: String, dist: String) -> IO(String):
  match is_file:
    case True{}:
      route_file_get(after(path, "/api/file/"))
    case False{}:
      route_static(pick(String.eq(path, "/"), "/index.html", path), dist)

def route_get.chat_md(is_chat_md: Bool, +path: String, dist: String, +agent_md: String) -> IO(String):
  match is_chat_md:
    case True{}:
      route_chat_md(agent_md)
    case False{}:
      route_get.files(String.starts_with(path, "/api/file/"), path, dist)

def route_get.agent(is_agent: Bool, +path: String, dist: String, +agent_md: String) -> IO(String):
  match is_agent:
    case True{}:
      route_agent_md(agent_md)
    case False{}:
      route_get.chat_md(String.eq(path, "/api/file/CHAT.md"), path, dist, agent_md)

def route_get.connect(is_connect: Bool, +path: String, dist: String, agent_md: String) -> IO(String):
  match is_connect:
    case True{}:
      connect(after(path, "/api/connect/"))
    case False{}:
      route_get.agent(String.eq(path, "/api/file/AGENT.md"), path, dist, agent_md)

def route_get.models(is_models: Bool, +path: String, dist: String, agent_md: String) -> IO(String):
  match is_models:
    case True{}:
      models(after(path, "/api/models/"))
    case False{}:
      route_get.connect(String.starts_with(path, "/api/connect/"), path, dist, agent_md)

def route_get(+path: String, dist: String, agent_md: String) -> IO(String):
  route_get.models(String.starts_with(path, "/api/models/"), path, dist, agent_md)

# POST: /api/generate/<ai> (body: the sentence), /api/chat/<ai>/<model> (body: the conversation),
# /api/file/<name> (body: the file).
def route_file_post.at(allowed: Bool, name: String, body: String) -> IO(String):
  match allowed:
    case True{}:
      do IO<String>:
        write_file(name, body)
        return ok_text("saved")
    case False{}:
      IO.pure(String, not_found())

def route_file_post(+name: String, body: String) -> IO(String):
  route_file_post.at(is_project_file(name), name, body)

def route_post.files(is_file: Bool, +path: String, body: String) -> IO(String):
  match is_file:
    case True{}:
      route_file_post(after(path, "/api/file/"), body)
    case False{}:
      IO.pure(String, not_found())

def route_post.generate(is_gen: Bool, +path: String, body: String, agent_md: String) -> IO(String):
  match is_gen:
    case True{}:
      generate(after(path, "/api/generate/"), agent_md, body)
    case False{}:
      route_post.files(String.starts_with(path, "/api/file/"), path, body)

def route_post.chat(is_chat: Bool, +path: String, body: String, agent_md: String) -> IO(String):
  match is_chat:
    case True{}:
      chat(after(path, "/api/chat/"), agent_md, body)
    case False{}:
      route_post.generate(String.starts_with(path, "/api/generate/"), path, body, agent_md)

def route_post(+path: String, body: String, agent_md: String) -> IO(String):
  route_post.chat(String.starts_with(path, "/api/chat/"), path, body, agent_md)

def route.at(is_post: Bool, +req: String, dist: String, agent_md: String) -> IO(String):
  match is_post:
    case True{}:
      route_post(req_word(req, 1n), req_body(req), agent_md)
    case False{}:
      route_get(req_word(req, 1n), dist, agent_md)

def route(+req: String, dist: String, agent_md: String) -> IO(String):
  route.at(String.eq(req_word(req, 0n), "POST"), req, dist, agent_md)

# ---------- Connections ----------

def send_done(m: Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit>) -> IO(Unit):
  (s, r) = m
  Socket.close(s)

def answer.text(s: Socket, req: String, dist: String, agent_md: String) -> IO(Unit):
  do IO<Unit>:
    res  : String <- route(req, dist, agent_md)
    sent : Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit> <- TCP.send(s, res)
    send_done(sent)

# Images go out as bytes: read as text, they would be decoded as UTF-8 and break.
def bytes_of(r: Result<&1, &1, U32 & String, List<&2, U32>>) -> List<&2, U32>:
  match r:
    case Fail{e}:
      []
    case Done{data}:
      data

def send_bytes.body(m: Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit>, data: List<&2, U32>) -> IO(Unit):
  (s, r) = m
  do IO<Unit>:
    sent : Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit> <- TCP.send_bytes(s, data)
    send_done(sent)

def send_bytes.read(s: Socket, got: File & Result<&1, &1, U32 & String, List<&2, U32>>, ctype: String) -> IO(Unit):
  (f, r) = got
  do IO<Unit>:
    File.close(f)
    head : Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit> <- TCP.send(s, http("200 OK", ctype, ""))
    send_bytes.body(head, bytes_of(r))

def send_bytes.open(s: Socket, r: Result<&1, &1, U32 & String, File>, ctype: String) -> IO(Unit):
  match r:
    case Fail{e}:
      do IO<Unit>:
        sent : Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit> <- TCP.send(s, not_found())
        send_done(sent)
    case Done{f}:
      do IO<Unit>:
        got : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(f, 4194304)
        send_bytes.read(s, got, ctype)

def answer.bytes(s: Socket, +path: String, dist: String) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, File> <- File.open(dist ++ path, "r")
    send_bytes.open(s, r, content_type(path))

def is_image(+path: String) -> Bool:
  ((String.ends_with(path, ".webp") || String.ends_with(path, ".png")) && Bool.not(String.contains(path, "..")))

def answer.at(image: Bool, s: Socket, +req: String, dist: String, agent_md: String) -> IO(Unit):
  match image:
    case True{}:
      answer.bytes(s, req_word(req, 1n), dist)
    case False{}:
      answer.text(s, req, dist, agent_md)

def answer(s: Socket, +req: String, dist: String, agent_md: String) -> IO(Unit):
  answer.at(is_image(req_word(req, 1n)), s, req, dist, agent_md)

# A POST whose body hasn't arrived with the headers gets one more read.
def more(m: Socket & Result<&1, &1, U32 & String, Maybe<&1, String>>, head: String, dist: String, agent_md: String) -> IO(Unit):
  (s, r) = m
  match r:
    case Done{Some{rest}}:
      answer(s, head ++ rest, dist, agent_md)
    case Done{None{}}:
      answer(s, head, dist, agent_md)
    case Fail{e}:
      Socket.close(s)

def first.at(waiting: Bool, s: Socket, req: String, dist: String, agent_md: String) -> IO(Unit):
  match waiting:
    case True{}:
      do IO<Unit>:
        m : Socket & Result<&1, &1, U32 & String, Maybe<&1, String>> <- TCP.recv(s, 1048576)
        more(m, req, dist, agent_md)
    case False{}:
      answer(s, req, dist, agent_md)

def first(s: Socket, +req: String, dist: String, agent_md: String) -> IO(Unit):
  first.at((String.eq(req_word(req, 0n), "POST") && String.is_empty(req_body(req))), s, req, dist, agent_md)

def talk_read(m: Socket & Result<&1, &1, U32 & String, Maybe<&1, String>>, dist: String, agent_md: String) -> IO(Unit):
  (s, r) = m
  match r:
    case Done{Some{req}}:
      first(s, req, dist, agent_md)
    case Done{None{}}:
      Socket.close(s)
    case Fail{e}:
      Socket.close(s)

def talk(s: Socket, dist: String, agent_md: String) -> IO(Unit):
  do IO<Unit>:
    m : Socket & Result<&1, &1, U32 & String, Maybe<&1, String>> <- TCP.recv(s, 1048576)
    talk_read(m, dist, agent_md)

def conn(m: Listener & Result<&1, &1, U32 & String, Socket>, +dist: String, +agent_md: String) -> IO(Listener):
  (l, r) = m
  do IO<Listener>:
    s : Socket <- IO.pass(Socket, r)
    IO.spawn(Unit, talk(s, dist, agent_md))
    return l

def serve(fuel: Nat, l: Listener, +dist: String, +agent_md: String) -> IO(Unit):
  match fuel:
    case 0n:
      Listener.close(l)
    case 1n+fuel2:
      do IO<Unit>:
        m  : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
        l2 : Listener <- conn(m, dist, agent_md)
        serve(fuel2, l2, dist, agent_md)

# ---------- Start ----------

# The arguments: the program, then the page folder (dist), then AGENT.md.
def start.agent(dist: String, rest: List<String>, l: Listener) -> IO(Unit):
  match rest:
    case Nil{}:
      serve(4294967295n, l, dist, "AGENT.md")
    case a <> more:
      serve(4294967295n, l, dist, a)

def start.dist(rest: List<String>, l: Listener) -> IO(Unit):
  match rest:
    case Nil{}:
      serve(4294967295n, l, "dist", "AGENT.md")
    case d <> more:
      start.agent(d, more, l)

def start(args: List<String>, l: Listener) -> IO(Unit):
  match args:
    case Nil{}:
      serve(4294967295n, l, "dist", "AGENT.md")
    case p <> rest:
      start.dist(rest, l)

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    ensure_file("GDD.md", "")
    ensure_file("TYPES.bend", "import Base\n")
    ensure_file("LAWS.bend", "import Base\nimport ./TYPES.bend as T\n")
    l : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", 4280))
    IO.print("LawEditor: http://127.0.0.1:4280")
    start(args, l)
