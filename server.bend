# LawEditor's server: the engine behind every window (the page, the terminal).
#
#   cd ~/LawEditor && /path/to/LawEditor/dist/laweditor-server /path/to/LawEditor
#
# It runs in the home of the projects (engine/PLACES.bend) and is told where LawEditor itself is: it
# serves the page from there (dist/) and reads what the AIs are told (harness/). LAWEDITOR_PORT moves it
# from 4280. What the projects built is served at a second door (LAWEDITOR_PAGES_PORT, or the port plus
# 1000): see "The pages door" below. It keeps no "current" project and no conversation in memory: every request names its project
# and its conversation, and what happened is in their files. So any number of windows and conversations
# can go at once, and all of them see the same thing.
#
# This file is the door: it reads a request and hands it to the engine (engine/).

import Base
import ./engine/SYS.bend as Sys
import ./engine/PLACES.bend as Places
import ./engine/PROJECTS.bend as Proj
import ./engine/TURN.bend as Turn
import ./engine/LAW.bend as Law
import ./engine/TERMINAL.bend as Term
import ./harness/MODELS.bend as Models
import ./harness/GATE.bend as Gate
import ./harness/EVENTS.bend as Ev
import ./harness/INSPECT.bend as Insp

# ---------- A request ----------

# The n-th word of the request line: "GET /path HTTP/1.1".
def req_word(s: String, n: Nat) -> String:
  Sys.nth(String.split(s, ' '), n)

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

# A header of the request ("" if it has none). Only the lines before the blank one are headers: what
# comes after is the body, and a body can say anything.
def header.pick(blank: Bool, hit: Bool, +h: String, +name: String, later: String) -> String:
  match blank hit:
    case True{} _:
      ""
    case False{} True{}:
      String.trim(String.drop(h, String.length(name)))
    case False{} False{}:
      later

def header.go(ls: List<&2, String>, +name: String) -> String:
  match ls:
    case Nil{}:
      ""
    case +h <> t:
      header.pick(String.is_empty(String.trim(h)), String.starts_with(String.to_lower(h), name), h, name, header.go(t, name))

def header(req: String, +name: String) -> String:
  header.go(String.lines(req), name)

# Only this computer's own windows may ask. A page of another site, open in the same browser, could
# otherwise send requests here (and this server runs commands): the browser names where a request comes
# from (Origin), and a request named by another site is refused. A request must also be addressed to this
# server by its own name (Host), so no outside name can be pointed at it. The terminal sends no Origin.
def is_ours(+origin: String, +host: String, +address: String, +port: String) -> Bool:
  ((String.is_empty(origin) || String.eq(origin, "http://" ++ address) || String.eq(origin, "http://localhost:" ++ port)) && (String.eq(host, address) || String.eq(host, "localhost:" ++ port)))

# ---------- An answer ----------

def content_type(+path: String) -> String:
  Sys.pick(String.ends_with(path, ".html"), "text/html; charset=utf-8",
  Sys.pick((String.ends_with(path, ".js") || String.ends_with(path, ".mjs")), "text/javascript; charset=utf-8",
  Sys.pick(String.ends_with(path, ".css"), "text/css; charset=utf-8",
  Sys.pick(String.ends_with(path, ".json"), "application/json",
  Sys.pick(String.ends_with(path, ".svg"), "image/svg+xml",
  Sys.pick(String.ends_with(path, ".webp"), "image/webp",
  Sys.pick(String.ends_with(path, ".png"), "image/png",
  Sys.pick(String.ends_with(path, ".jpg"), "image/jpeg",
  Sys.pick(String.ends_with(path, ".gif"), "image/gif",
  Sys.pick(String.ends_with(path, ".wav"), "audio/wav",
  Sys.pick(String.ends_with(path, ".mp3"), "audio/mpeg",
  Sys.pick(String.ends_with(path, ".ogg"), "audio/ogg",
  "text/plain; charset=utf-8"))))))))))))

def http(status: String, ctype: String, body: String) -> String:
  "HTTP/1.1 " ++ status ++ "\r\nContent-Type: " ++ ctype ++ "\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n" ++ body

def ok_text(body: String) -> String:
  http("200 OK", "text/plain; charset=utf-8", body)

def not_found() -> String:
  http("404 Not Found", "text/plain; charset=utf-8", "not found")

def json(body: String) -> String:
  http("200 OK", "application/json", body)

# What the engine answered, as a page reads it.
def ok(m: IO(String)) -> IO(String):
  do IO<String>:
    text : String <- m
    return ok_text(text)

def as_json(m: IO(String)) -> IO(String):
  do IO<String>:
    text : String <- m
    return json(text)

def missing() -> IO(String):
  IO.pure(String, not_found())

# The first route whose test holds; d if none does. Each route is only described here: the one picked runs.
def routes.at(hit: Bool, a: IO(String), rest: IO(String)) -> IO(String):
  match hit:
    case True{}:
      a
    case False{}:
      rest

def routes(rs: List<(Bool & IO(String))>, d: IO(String)) -> IO(String):
  match rs:
    case Nil{}:
      d
    case (hit, a) <> t:
      routes.at(hit, a, routes(t, d))

# ---------- The page ----------

def dist(cx: Sys.Ctx) -> String:
  Sys.root(cx) ++ "/dist"

def static_reply(+text: String, +path: String) -> String:
  Sys.pick(String.is_empty(text), not_found(), http("200 OK", content_type(path), text))

def static.at(bad: Bool, +path: String, +cx: Sys.Ctx) -> IO(String):
  match bad:
    case True{}:
      missing()
    case False{}:
      do IO<String>:
        text : String <- Sys.read_file(dist(cx) ++ path)
        return static_reply(text, path)

def static(+cx: Sys.Ctx, +path: String) -> IO(String):
  static.at(String.contains(path, ".."), Sys.pick(String.eq(path, "/"), "/index.html", path), cx)

# ---------- The AIs ----------

# Is the AI's command installed? `claude --version` / `codex --version`.
def connect_reply(r: U32 & String) -> String:
  (+code, out) = r
  Sys.pick(U32.is_eq(code, 0), ok_text("ok"), http("404 Not Found", "text/plain; charset=utf-8", "notfound"))

def connect.at(known: Bool, +ai: String) -> IO(String):
  match known:
    case True{}:
      do IO<String>:
        r : U32 & String <- Sys.run(ai, ["--version"], 15000)
        return connect_reply(r)
    case False{}:
      missing()

def connect(+ai: String) -> IO(String):
  connect.at(Turn.is_ai(ai), ai)

# The models an AI offers, asked to its own CLI (MODELS.bend reads the answer).
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
        r : U32 & String <- Sys.run(ai, models_args(String.eq(ai, "codex")), 30000)
        return models_reply(String.eq(ai, "codex"), r)
    case False{}:
      missing()

def models(+ai: String) -> IO(String):
  models.at(Turn.is_ai(ai), ai)

# What an AI is told, as it is: only these four files.
def is_told(+name: String) -> Bool:
  (String.eq(name, "AGENT.md") || String.eq(name, "CHAT.md") || String.eq(name, "HEAR.md") || String.eq(name, "HARNESS.md"))

def told.at(known: Bool, +cx: Sys.Ctx, name: String) -> IO(String):
  match known:
    case True{}:
      ok(Sys.read_file(Sys.told(cx, name)))
    case False{}:
      missing()

def told(+cx: Sys.Ctx, +name: String) -> IO(String):
  told.at(is_told(name), cx, name)

# Debug (a screen to remove later): LawEditor's own LAWS.bend as it is, and Bend's check of it, run now.
def debug_check(+cx: Sys.Ctx) -> IO(String):
  do IO<String>:
    r : U32 & String <- Sys.run("bend", [Sys.root(cx) ++ "/PROOF.bend"], 120000)
    return ok_text(Sys.printed(r))

# The first two pieces of a path.
def is2(+p: List<&2, String>, a: String, b: String) -> Bool:
  (String.eq(Sys.nth(p, 0n), a) && String.eq(Sys.nth(p, 1n), b))

# ---------- A project: /api/p/<key>/… ----------

# The files the Laws view may read and write in a project: the person's rules and their laws.
def is_project_file(+name: String) -> Bool:
  (String.eq(name, "RULES.md") || String.eq(name, "LAWS.bend"))

def saved(+dir: String, name: String, body: String) -> IO(String):
  do IO<String>:
    Sys.write_file(dir ++ "/" ++ name, body)
    return "saved"

# rest: the path after the key, its pieces. A project that isn't there reads as empty and takes no write.
def project_get(+cx: Sys.Ctx, +dir: String, +rest: List<&2, String>) -> IO(String):
  routes([
    (String.is_empty(dir), ok(IO.pure(String, ""))),
    (String.eq(Sys.nth(rest, 0n), "files"), ok(Proj.files(dir))),
    (is2(rest, "term", "out"), ok(Term.out(dir, Sys.nth(rest, 2n)))),
    ((String.eq(Sys.nth(rest, 0n), "file") && is_project_file(Sys.nth(rest, 1n))), ok(Sys.read_file(dir ++ "/" ++ Sys.nth(rest, 1n))))
  ], missing())

def project_post(+cx: Sys.Ctx, +dir: String, +rest: List<&2, String>, +body: String) -> IO(String):
  routes([
    (String.is_empty(dir), missing()),
    ((String.eq(Sys.nth(rest, 0n), "file") && is_project_file(Sys.nth(rest, 1n))), ok(saved(dir, Sys.nth(rest, 1n), body))),
    ((String.eq(Sys.nth(rest, 0n), "generate") && Turn.is_ai(Sys.nth(rest, 1n))), ok(Law.write(cx, dir, Sys.nth(rest, 1n), body))),
    (String.eq(Sys.nth(rest, 0n), "read"), ok(Proj.read(dir, String.trim(body)))),
    (is2(rest, "term", "start"), ok(Term.start(dir))),
    (is2(rest, "term", "in"), ok(Term.keys(dir, body))),
    (is2(rest, "term", "stop"), ok(Term.stop(dir))),
    (String.eq(Sys.nth(rest, 0n), "rename"), ok(Proj.rename(dir, body))),
    (String.eq(Sys.nth(rest, 0n), "open"), ok(Proj.open(dir)))
  ], missing())

# A write makes the folder ready first: the first sentence written in Laws, before any talk, starts a
# project of its own (a draft, as a conversation's does).
def project(+cx: Sys.Ctx, post: Bool, +key: String, +rest: List<&2, String>, +body: String) -> IO(String):
  match post:
    case True{}:
      do IO<String>:
        +dir : String <- Proj.ensure(key, key)
        project_post(cx, dir, rest, body)
    case False{}:
      do IO<String>:
        +dir : String <- Proj.dir(key)
        project_get(cx, dir, rest)

# ---------- A conversation: /api/c/<key>/<conversation>/… ----------

def to_nat(m: Maybe<&2, U32>) -> Nat:
  match m:
    case None{}:
      0n
    case Some{n}:
      U32.to_nat(n)

def conversation_get(+dir: String, +conv: String, +rest: List<&2, String>) -> IO(String):
  routes([
    (String.is_empty(dir), ok(IO.pure(String, ""))),
    (String.eq(Sys.nth(rest, 0n), "events"), ok(Turn.events(dir, conv, to_nat(U32.read(Sys.nth(rest, 1n)))))),
    (String.eq(Sys.nth(rest, 0n), "now"), ok(Turn.now(dir, conv))),
    (String.eq(Sys.nth(rest, 0n), "allowed"), ok(Turn.allowed(dir, conv))),
    (String.eq(Sys.nth(rest, 0n), "progress"), ok(Turn.progress(dir, Sys.nth(rest, 1n)))),
    (String.eq(Sys.nth(rest, 0n), "work"), ok(Turn.work(dir, conv, Sys.nth(rest, 1n)))),
    (String.eq(Sys.nth(rest, 0n), "output"), ok(Turn.output(dir, Sys.nth(rest, 1n), Sys.nth(rest, 2n))))
  ], missing())

def conversation_post(+dir: String, +conv: String, +rest: List<&2, String>, +body: String) -> IO(String):
  routes([
    (String.is_empty(dir), missing()),
    (String.eq(Sys.nth(rest, 0n), "answer"), ok(Turn.answer(dir, conv, Sys.nth(rest, 1n), body))),
    (String.eq(Sys.nth(rest, 0n), "stop"), ok(Turn.stop(dir, conv))),
    (String.eq(Sys.nth(rest, 0n), "allowed"), ok(Turn.allowed_less(dir, conv, body))),
    (String.eq(Sys.nth(rest, 0n), "delete"), ok(Proj.forget(dir, conv)))
  ], missing())

def conversation.in(post: Bool, +dir: String, +conv: String, +rest: List<&2, String>, +body: String) -> IO(String):
  match post:
    case True{}:
      conversation_post(dir, conv, rest, body)
    case False{}:
      conversation_get(dir, conv, rest)

def conversation.at(say: Bool, again: Bool, run: Bool, +cx: Sys.Ctx, post: Bool, +key: String, +conv: String, +rest: List<&2, String>, +body: String) -> IO(String):
  match say again run:
    case True{} _ _:
      ok(Turn.say(cx, key, conv, body))
    case False{} True{} _:
      ok(Turn.again(cx, key, conv, body))
    case False{} False{} True{}:
      ok(Turn.ran(cx, key, conv, body))
    case False{} False{} False{}:
      do IO<String>:
        +dir : String <- Proj.dir(key)
        conversation.in(post, dir, conv, rest, body)

# say and run make the conversation's folder themselves (engine/TURN.bend); everything else needs it there.
def conversation(+cx: Sys.Ctx, +post: Bool, +key: String, +conv: String, +rest: List<&2, String>, +body: String) -> IO(String):
  conversation.at((post && String.eq(Sys.nth(rest, 0n), "say")), (post && String.eq(Sys.nth(rest, 0n), "again")), (post && String.eq(Sys.nth(rest, 0n), "run")), cx, post, key, conv, rest, body)

# ---------- The interphone: /mcp/<key>/<conversation>/<turn> (GATE.bend) ----------

def mcp.at(notice: Bool, call: Bool, +dir: String, +conv: String, +turn: String, +msg: String) -> IO(String):
  match notice call:
    case True{} _:
      IO.pure(String, http("202 Accepted", "text/plain; charset=utf-8", ""))
    case False{} True{}:
      as_json(Turn.mcp.call(dir, conv, turn, msg))
    case False{} False{}:
      IO.pure(String, json(Gate.reply(msg)))

def mcp(+key: String, +conv: String, +turn: String, +msg: String) -> IO(String):
  do IO<String>:
    +dir : String <- Proj.dir(key)
    mcp.at(Gate.is_notice(msg), Gate.is_call(msg), dir, conv, turn, msg)

# Where the pages door is ("" when it couldn't open): a window makes a project's address from it.
def pages_url(+cx: Sys.Ctx) -> String:
  Sys.pick(U32.is_eq(Sys.pages(cx), 0), "", "http://" ++ Sys.pages_address(cx))

# ---------- Routes ----------
# p: the path's pieces ("/api/c/rio-negro/abc/say" is api, c, rio-negro, abc, say).

def route_get(+cx: Sys.Ctx, +p: List<&2, String>, +path: String) -> IO(String):
  routes([
    (is2(p, "api", "models"), models(Sys.nth(p, 2n))),
    (is2(p, "api", "connect"), connect(Sys.nth(p, 2n))),
    (is2(p, "api", "told"), told(cx, Sys.nth(p, 2n))),
    ((is2(p, "api", "debug") && String.eq(Sys.nth(p, 2n), "check")), debug_check(cx)),
    ((is2(p, "api", "debug") && String.eq(Sys.nth(p, 2n), "LAWS.bend")), ok(Sys.read_file(Sys.root(cx) ++ "/LAWS.bend"))),
    (is2(p, "api", "projects"), ok(Proj.projects())),
    (is2(p, "api", "pages"), ok(IO.pure(String, pages_url(cx)))),
    (is2(p, "api", "conversations"), ok(Proj.conversations())),
    (is2(p, "api", "p"), project(cx, False{}, Sys.nth(p, 2n), Ev.after.drop(p, 3n), "")),
    (is2(p, "api", "c"), conversation(cx, False{}, Sys.nth(p, 2n), Sys.nth(p, 3n), Ev.after.drop(p, 4n), "")),
    (String.eq(Sys.nth(p, 0n), "mcp"), IO.pure(String, http("405 Method Not Allowed", "text/plain; charset=utf-8", ""))),
    (String.eq(Sys.nth(p, 0n), "api"), missing())
  ], static(cx, path))

def route_post(+cx: Sys.Ctx, +p: List<&2, String>, +body: String) -> IO(String):
  routes([
    (is2(p, "api", "open-folder"), ok(Proj.choose())),
    (is2(p, "api", "open-path"), ok(Proj.open_path(body))),
    (is2(p, "api", "p"), project(cx, True{}, Sys.nth(p, 2n), Ev.after.drop(p, 3n), body)),
    (is2(p, "api", "c"), conversation(cx, True{}, Sys.nth(p, 2n), Sys.nth(p, 3n), Ev.after.drop(p, 4n), body)),
    (String.eq(Sys.nth(p, 0n), "mcp"), mcp(Sys.nth(p, 1n), Sys.nth(p, 2n), Sys.nth(p, 3n), body))
  ], missing())

def route.at(is_post: Bool, +cx: Sys.Ctx, +req: String) -> IO(String):
  match is_post:
    case True{}:
      route_post(cx, Ev.after.drop(String.split(req_word(req, 1n), '/'), 1n), req_body(req))
    case False{}:
      route_get(cx, Ev.after.drop(String.split(req_word(req, 1n), '/'), 1n), req_word(req, 1n))

def route.ours(ours: Bool, +cx: Sys.Ctx, +req: String) -> IO(String):
  match ours:
    case True{}:
      route.at(String.eq(req_word(req, 0n), "POST"), cx, req)
    case False{}:
      IO.pure(String, http("403 Forbidden", "text/plain; charset=utf-8", "This server only answers its own page and terminal."))

def route(+cx: Sys.Ctx, +req: String) -> IO(String):
  route.ours(is_ours(header(req, "origin:"), header(req, "host:"), Sys.address(cx), U32.show(Sys.port(cx))), cx, req)

# ---------- Connections ----------

def send_done(m: Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit>) -> IO(Unit):
  (s, r) = m
  Socket.close(s)

def answer.text(s: Socket, req: String, +cx: Sys.Ctx) -> IO(Unit):
  do IO<Unit>:
    res  : String <- route(cx, req)
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

def answer.bytes(s: Socket, +path: String, +cx: Sys.Ctx) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, File> <- File.open(dist(cx) ++ path, "r")
    send_bytes.open(s, r, content_type(path))

def is_image(+path: String) -> Bool:
  ((String.ends_with(path, ".webp") || String.ends_with(path, ".png")) && Bool.not(String.contains(path, "..")))

def answer.at(image: Bool, s: Socket, +req: String, +cx: Sys.Ctx) -> IO(Unit):
  match image:
    case True{}:
      answer.bytes(s, req_word(req, 1n), cx)
    case False{}:
      answer.text(s, req, cx)

# ---------- The pages door ----------
# A project's page, as Bend last bundled it (engine/BUILD.bend), is served from a second port and never
# from the app's own. To the browser, a page a chat wrote is then another site: a request it sends to the
# app is named by another origin and refused (is_ours), so no page can use the app's own powers (run a
# command, answer a question). The door only reads: GET /<key>/<file>, from the project's
# .laweditor/page. A request belongs to this door when it is addressed to it by name (Host).
# The app shows a page in a frame of its own with tools over it (harness/INSPECT.bend): a page asked for
# with ?inspect comes with the probe, a script of LawEditor's that reads the page's boxes and tells the
# frame. Asked for without it (a tab of its own), the page is exactly what Bend bundled.

def is_pages(+host: String, +cx: Sys.Ctx) -> Bool:
  (Bool.not(U32.is_eq(Sys.pages(cx), 0)) && (String.eq(host, Sys.pages_address(cx)) || String.eq(host, "localhost:" ++ U32.show(Sys.pages(cx)))))

def page.send_text(s: Socket, res: String) -> IO(Unit):
  do IO<Unit>:
    sent : Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit> <- TCP.send(s, res)
    send_done(sent)

# The file a path names: a folder is its index.html.
def page.file(+rest: String) -> String:
  Sys.pick((String.is_empty(rest) || String.ends_with(rest, "/")), rest ++ "index.html", rest)

# The page with the probe (harness/INSPECT.bend), for the app's own frame; a page that isn't there is not found.
def page.send_probed(missing: Bool, s: Socket, html: String) -> IO(Unit):
  match missing:
    case True{}:
      page.send_text(s, not_found())
    case False{}:
      page.send_text(s, http("200 OK", "text/html; charset=utf-8", Insp.with_probe(html)))

# A file of the page, as it is; or, when the app asked for the probe and the file is a page, with it.
def page.send_file(probed: Bool, s: Socket, +file: String) -> IO(Unit):
  match probed:
    case True{}:
      do IO<Unit>:
        +html : String <- Sys.read_file(file)
        page.send_probed(String.is_empty(html), s, html)
    case False{}:
      do IO<Unit>:
        r : Result<&1, &1, U32 & String, File> <- File.open(file, "r")
        send_bytes.open(s, r, content_type(file))

# bare: the address names the project and nothing after it, not even "/": the page's own files are asked
# for beside it, so it is sent to the same address with the "/" (and with what was asked after "?").
# ask: the app asked for the probe.
def page.send(bad: Bool, bare: Bool, ask: Bool, s: Socket, +key: String, +file: String) -> IO(Unit):
  match bad bare:
    case True{} _:
      page.send_text(s, not_found())
    case False{} True{}:
      page.send_text(s, "HTTP/1.1 301 Moved Permanently\r\nLocation: /" ++ key ++ "/" ++ Sys.pick(ask, "?" ++ Insp.query(), "") ++ "\r\nConnection: close\r\n\r\n")
    case False{} False{}:
      page.send_file(Insp.probed(ask, file), s, file)

# path: without what comes after "?". p: its pieces. q: what comes after "?".
def page.at(s: Socket, get: Bool, +path: String, +p: List<&2, String>, q: String) -> IO(Unit):
  do IO<Unit>:
    +dir : String <- Proj.dir(Sys.nth(p, 0n))
    page.send((Bool.not(get) || String.contains(path, "..") || String.is_empty(Sys.nth(p, 0n)) || String.is_empty(dir)),
      (String.is_empty(Sys.nth(p, 1n)) && Bool.not(String.ends_with(path, "/"))), Insp.asks(q),
      s, Places.safe(Sys.nth(p, 0n)), Places.page(dir) ++ "/" ++ page.file(String.join(Ev.after.drop(p, 1n), "/")))

# The probe itself: LawEditor's own script, the same for every project (harness/INSPECT.bend says what it is).
def page.probe(s: Socket, +cx: Sys.Ctx) -> IO(Unit):
  do IO<Unit>:
    js : String <- Sys.read_file(Sys.root(cx) ++ Insp.probe_file())
    page.send_text(s, http("200 OK", "text/javascript; charset=utf-8", js))

def page.pick(probe: Bool, s: Socket, get: Bool, +path: String, +p: List<&2, String>, q: String, +cx: Sys.Ctx) -> IO(Unit):
  match probe:
    case True{}:
      page.probe(s, cx)
    case False{}:
      page.at(s, get, path, p, q)

def page.answer(s: Socket, +req: String, +cx: Sys.Ctx) -> IO(Unit):
  +parts = String.split(req_word(req, 1n), '?')
  +p = Ev.after.drop(String.split(Sys.nth(parts, 0n), '/'), 1n)
  page.pick((String.eq(req_word(req, 0n), "GET") && String.eq(Sys.nth(p, 0n), Insp.probe_name())), s, String.eq(req_word(req, 0n), "GET"), Sys.nth(parts, 0n), p, Sys.nth(parts, 1n), cx)

def answer.door(pages: Bool, s: Socket, +req: String, +cx: Sys.Ctx) -> IO(Unit):
  match pages:
    case True{}:
      page.answer(s, req, cx)
    case False{}:
      answer.at(is_image(req_word(req, 1n)), s, req, cx)

def answer(s: Socket, +req: String, +cx: Sys.Ctx) -> IO(Unit):
  answer.door(is_pages(header(req, "host:"), cx), s, req, cx)

# A POST whose body hasn't arrived with the headers gets one more read.
def more(m: Socket & Result<&1, &1, U32 & String, Maybe<&1, String>>, head: String, +cx: Sys.Ctx) -> IO(Unit):
  (s, r) = m
  match r:
    case Done{Some{rest}}:
      answer(s, head ++ rest, cx)
    case Done{None{}}:
      answer(s, head, cx)
    case Fail{e}:
      Socket.close(s)

def first.at(waiting: Bool, s: Socket, req: String, +cx: Sys.Ctx) -> IO(Unit):
  match waiting:
    case True{}:
      do IO<Unit>:
        m : Socket & Result<&1, &1, U32 & String, Maybe<&1, String>> <- TCP.recv(s, 1048576)
        more(m, req, cx)
    case False{}:
      answer(s, req, cx)

# A POST that says its body is empty (Content-Length: 0, as an empty fetch sends) has nothing more to wait for.
def first(s: Socket, +req: String, +cx: Sys.Ctx) -> IO(Unit):
  first.at((String.eq(req_word(req, 0n), "POST") && String.is_empty(req_body(req)) && Bool.not(String.contains(String.to_lower(req), "content-length: 0\r"))), s, req, cx)

def talk_read(m: Socket & Result<&1, &1, U32 & String, Maybe<&1, String>>, +cx: Sys.Ctx) -> IO(Unit):
  (s, r) = m
  match r:
    case Done{Some{req}}:
      first(s, req, cx)
    case Done{None{}}:
      Socket.close(s)
    case Fail{e}:
      Socket.close(s)

def talk(s: Socket, +cx: Sys.Ctx) -> IO(Unit):
  do IO<Unit>:
    m : Socket & Result<&1, &1, U32 & String, Maybe<&1, String>> <- TCP.recv(s, 1048576)
    talk_read(m, cx)

def conn(m: Listener & Result<&1, &1, U32 & String, Socket>, +cx: Sys.Ctx) -> IO(Listener):
  (l, r) = m
  do IO<Listener>:
    s : Socket <- IO.pass(Socket, r)
    IO.spawn(Unit, talk(s, cx))
    return l

def serve(fuel: Nat, l: Listener, +cx: Sys.Ctx) -> IO(Unit):
  match fuel:
    case 0n:
      Listener.close(l)
    case 1n+fuel2:
      do IO<Unit>:
        m  : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
        l2 : Listener <- conn(m, cx)
        serve(fuel2, l2, cx)

# ---------- Start ----------

def port_of(m: Maybe<&2, U32>) -> U32:
  match m:
    case None{}:
      4280
    case Some{n}:
      n

def root_of.at(rest: List<String>) -> String:
  match rest:
    case Nil{}:
      "."
    case r <> more:
      r

# The arguments: the program, then LawEditor's own folder.
def root_of(args: List<String>) -> String:
  match args:
    case Nil{}:
      "."
    case p <> rest:
      root_of.at(rest)

# The pages door's port: LAWEDITOR_PAGES_PORT, or the app's port plus 1000.
def pages_port(+port: U32, m: Maybe<&2, U32>) -> U32:
  match m:
    case None{}:
      (port + 1000 : U32)
    case Some{n}:
      n

# The pages door opens beside the app, or not at all (its port is taken): the app still runs, and a
# project's page then has no Open.
def pages.open(r: Result<&1, &1, U32 & String, Listener>, +cx: Sys.Ctx) -> IO(Sys.Ctx):
  match r:
    case Fail{e}:
      do IO<Sys.Ctx>:
        IO.print("LawEditor: the pages door could not open at " ++ Sys.pages_address(cx) ++ " (LAWEDITOR_PAGES_PORT names another port). A project's page can't be opened from the app.")
        return Sys.Ctx{Sys.root(cx), Sys.port(cx), 0}
    case Done{l}:
      do IO<Sys.Ctx>:
        IO.spawn(Unit, serve(4294967295n, l, cx))
        IO.print("LawEditor: what the projects built is at http://" ++ Sys.pages_address(cx))
        return cx

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    +port : String <- Sys.env("LAWEDITOR_PORT", "4280")
    +pages : String <- Sys.env("LAWEDITOR_PAGES_PORT", "")
    +want : Sys.Ctx = Sys.Ctx{root_of(args), port_of(U32.read(port)), pages_port(port_of(U32.read(port)), U32.read(pages))}
    Proj.start()
    l : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", Sys.port(want)))
    r : Result<&1, &1, U32 & String, Listener> <- TCP.listen("127.0.0.1", Sys.pages(want))
    +cx : Sys.Ctx <- pages.open(r, want)
    IO.print("LawEditor: http://" ++ Sys.address(cx))
    serve(4294967295n, l, cx)
