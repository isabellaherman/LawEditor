# LawEditor's engine: the projects. Where they are, what is in them, their conversations.
# engine/PLACES.bend says where each thing is kept. Nothing here remembers a "current" project: every
# request names the project it is about, so two windows, or two conversations, never share one.

import Base
import ./SYS.bend as Sys
import ./PLACES.bend as Places
import ../harness/EVENTS.bend as Ev
import ../harness/CHAT.bend as Chat
import ../harness/ASK.bend as Ask

# ---------- Shell ----------
# sh lists and moves folders; every name reaches it as an argument. projects prints each project,
# its key and its folder split by a tab: the ones in the home, then the ones opened from elsewhere.
# A folder in the home is a project's key as it is, so only a simple name counts (letters, digits, "-":
# what PLACES.safe keeps); LawEditor names its folders so.

def tab_sh() -> String:
  "t=$(printf '\\t'); "

def projects_sh() -> String:
  tab_sh() ++ "projects() { for d in */; do d=${d%/}; case \"$d\" in *[!A-Za-z0-9-]*) continue;; esac; [ -d \"$d/.laweditor\" ] && printf '%s\\t%s\\n' \"$d\" \"$d\"; done; [ -f .folders ] && while IFS=\"$t\" read -r k p; do [ -d \"$p/.laweditor\" ] && printf '%s\\t%s\\n' \"$k\" \"$p\"; done < .folders; true; }; "

# ---------- A project's folder ----------

# The folder of a project, from its key ("" if the key names nothing).
def dir(+key: String) -> IO(String):
  do IO<String>:
    known : String <- Sys.read_file(Places.folders())
    return Places.folder(key, known)

# $0 the folder, $1 its name, $2 "1" for a conversation's own new folder (a draft). Only LawEditor's own
# .laweditor folder is made: no file of the project is, in a new folder or in one opened from elsewhere.
def make_sh() -> String:
  "[ -n \"$2\" ] || [ -d \"$0\" ] || exit 0; new=; [ -d \"$0/.laweditor\" ] || new=1; mkdir -p \"$0/.laweditor/chats\" \"$0/.laweditor/allowed\" \"$0/.laweditor/turns\"; [ -e \"$0/.laweditor/name\" ] || printf '%s' \"$1\" > \"$0/.laweditor/name\"; [ -n \"$new\" ] && [ -n \"$2\" ] && : > \"$0/.laweditor/draft\"; printf ok"

def ensure.made(+dir: String, +out: String) -> String:
  Sys.pick(String.eq(out, "ok"), dir, "")

def ensure.at(none: Bool, +dir: String, +draft: Bool) -> IO(String):
  match none:
    case True{}:
      IO.pure(String, "")
    case False{}:
      do IO<String>:
        +out : String <- Sys.sh(make_sh(), [dir, "", Sys.pick(draft, "1", "")], 5000)
        return ensure.made(dir, out)

# The folder a conversation works in, made ready. A conversation with no project yet names itself as
# one: it gets a folder of its own, marked as a draft (not a project until it has a rule or a file).
# Answers the folder, or "" when the key names no project.
def ensure(+key: String, +conv: String) -> IO(String):
  do IO<String>:
    +dir : String <- dir(key)
    ensure.at(String.is_empty(dir), dir, String.eq(key, conv))

# ---------- The lists ----------

# GET /api/projects: the projects, one per line: its key, a tab, its name. A draft isn't one yet.
def projects() -> IO(String):
  Sys.sh(projects_sh() ++ "projects | while IFS=\"$t\" read -r k d; do [ -e \"$d/.laweditor/draft\" ] && continue; printf '%s\\t%s\\n' \"$k\" \"$(cat \"$d/.laweditor/name\" 2>/dev/null || basename \"$d\")\"; done", [], 5000)

# GET /api/conversations: every conversation of every project, the one that moved last first. One per line:
# its project's key, its project's name (none for a draft), its name, its state (idle, working, asking) and
# its title, split by tabs.
def conversations() -> IO(String):
  Sys.sh(projects_sh() ++ "projects | while IFS=\"$t\" read -r k d; do g=''; [ -e \"$d/.laweditor/draft\" ] || g=$(cat \"$d/.laweditor/name\" 2>/dev/null || basename \"$d\"); for f in \"$d\"/.laweditor/chats/*.log; do [ -e \"$f\" ] || continue; i=$(basename \"$f\" .log); m=$(stat -c %Y \"$f\" 2>/dev/null || stat -f %m \"$f\"); printf '%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \"$m\" \"$k\" \"$g\" \"$i\" \"$(cat \"${f%.log}.state\" 2>/dev/null || printf idle)\" \"$(cat \"${f%.log}.title\" 2>/dev/null)\"; done; done | sort -rn | cut -f2-", [], 10000)

# ---------- A project is born, and named ----------

# A key in the home never starts with "x-": that marks a folder opened from elsewhere.
def home_key(+slug: String) -> String:
  Sys.pick(Places.is_outside(slug), "project-" ++ slug, slug)

# A draft with a rule (a sentence in RULES.md) or a file of its own becomes a project: it gets its name,
# and its folder takes that name (rio-negro; rio-negro-2 if taken). Answers the new key, or "" when
# nothing changed. Only a draft's own conversation is in it, and no turn of it is running when this is called.
def promote(+key: String, +name: String) -> IO(String):
  Sys.sh("[ -e \"$0/.laweditor/draft\" ] || exit 0; { [ -n \"$(ls \"$0\" 2>/dev/null | grep -v '^RULES[.]md$')\" ] || grep -q '[^[:space:]]' \"$0/RULES.md\" 2>/dev/null; } || exit 0; n=\"$2\"; i=1; while [ -e \"$n\" ]; do i=$((i+1)); n=\"$2-$i\"; done; printf '%s' \"$1\" > \"$0/.laweditor/name\"; rm \"$0/.laweditor/draft\"; mv \"$0\" \"$n\" && printf '%s' \"$n\"", [Places.safe(key), String.trim(name), home_key(Chat.slug(name))], 5000)

# POST /api/p/<key>/rename, body: the project's new name. Its folder keeps its place.
def rename(+dir: String, +name: String) -> IO(String):
  Sys.sh("[ -d \"$0/.laweditor\" ] && printf '%s' \"$1\" > \"$0/.laweditor/name\"; printf ok", [dir, String.trim(name)], 5000)

# ---------- A folder from elsewhere ----------

# $0 the folder, $1 a key made from its name. A folder already known keeps its key; one inside the home
# is the project it already is. Prints the key.
def register_sh() -> String:
  tab_sh() ++ "p=\"${0%/}\"; [ -d \"$p\" ] || exit 0; h=$(pwd -P); case \"$p\" in \"$h\"/*) b=${p#\"$h\"/}; case \"$b\" in */*) ;; *) printf '%s' \"$b\"; exit 0;; esac;; esac; k=$(awk -F '\\t' -v p=\"$p\" '$2==p{print $1}' .folders 2>/dev/null | head -n 1); if [ -z \"$k\" ]; then k=\"x-$1\"; i=1; while grep -q \"^$k$t\" .folders 2>/dev/null; do i=$((i+1)); k=\"x-$1-$i\"; done; printf '%s\\t%s\\n' \"$k\" \"$p\" >> .folders; fi; printf '%s' \"$k\""

def opened.line(+key: String, +dir: String, +made: String) -> String:
  Sys.pick(String.is_empty(made), "", key ++ "\t" ++ Ask.base_name(dir))

def opened.ready(+key: String) -> IO(String):
  do IO<String>:
    +d : String <- dir(key)
    +made : String <- Sys.sh(make_sh(), [d, Ask.base_name(d), ""], 5000)
    return opened.line(key, d, made)

def opened.at(none: Bool, +key: String) -> IO(String):
  match none:
    case True{}:
      IO.pure(String, "")
    case False{}:
      opened.ready(key)

# A folder of the computer becomes a project, where it is: LawEditor keeps its own things in a .laweditor
# folder inside it. Answers its key, a tab, its name ("" if the path is no folder).
def open_path(+path: String) -> IO(String):
  do IO<String>:
    +key : String <- Sys.sh(register_sh(), [String.trim(path), Chat.slug(Ask.base_name(String.trim(path)))], 5000)
    opened.at(String.is_empty(key), key)

def chosen(r: U32 & String) -> String:
  (+code, +out) = r
  Sys.pick(U32.is_eq(code, 0), String.trim(out), "")

def choose.at(none: Bool, +path: String) -> IO(String):
  match none:
    case True{}:
      IO.pure(String, "")
    case False{}:
      open_path(path)

# The computer's own folder chooser: osascript on macOS; on Linux zenity (GNOME) or kdialog (KDE). Prints the
# folder picked; fails when the person cancels or there is no chooser. What a chooser says on its errors is
# dropped, so only the path is printed.
def chooser_sh() -> String:
  "t='Open a folder as a project'; if command -v osascript >/dev/null 2>&1; then osascript -e \"POSIX path of (choose folder with prompt \\\"$t\\\")\" 2>/dev/null; elif command -v zenity >/dev/null 2>&1; then zenity --file-selection --directory --title=\"$t\" 2>/dev/null; elif command -v kdialog >/dev/null 2>&1; then kdialog --getexistingdirectory \"$HOME\" --title \"$t\" 2>/dev/null; else exit 127; fi"

# POST /api/open-folder: the computer's own folder chooser, then open_path. "" when the person cancels, or
# where there is no chooser to show.
def choose() -> IO(String):
  do IO<String>:
    r : U32 & String <- Sys.run("sh", ["-c", chooser_sh()], 600000)
    +path : String = chosen(r)
    choose.at(String.is_empty(path), path)

# ---------- A project's files ----------

# GET /api/p/<key>/files: the project's files, one path per line (the tree, and @ in the message box).
def files(+dir: String) -> IO(String):
  Sys.sh("cd \"$0\" && find . -type f -not -path '*/.*' -not -path '*/node_modules/*' | sed 's|^\\./||' | sort | head -500", [dir], 10000)

# POST /api/p/<key>/read, body: a path. One of the project's files, as text (the path comes in the body, so
# any name reaches the server as it is). A path may not climb out of the project.
def read.at(bad: Bool, +dir: String, +path: String) -> IO(String):
  match bad:
    case True{}:
      IO.pure(String, "")
    case False{}:
      Sys.read_file(dir ++ "/" ++ path)

def read(+dir: String, +path: String) -> IO(String):
  read.at((String.contains(path, "..") || String.starts_with(path, "/") || String.is_empty(path)), dir, path)

# POST /api/p/<key>/open: opens the project's folder on the computer: open on macOS, xdg-open elsewhere (on
# Linux, open is another program, or none). Answers "ok", or "error" when nothing could open it.
def open.said(r: U32 & String) -> String:
  (code, out) = r
  Sys.pick(U32.is_eq(code, 0), "ok", "error")

def open(+dir: String) -> IO(String):
  do IO<String>:
    r : U32 & String <- Sys.run_in(dir, "sh", ["-c", "if [ \"$(uname)\" = Darwin ]; then exec open .; else exec xdg-open .; fi"], 5000)
    return open.said(r)

# POST /api/c/<key>/<conversation>/delete: the conversation leaves the list. Its files go to the project's
# .laweditor/trash: LawEditor never deletes what the person made.
def forget(+dir: String, +conv: String) -> IO(String):
  Sys.sh("mkdir -p \"$0/.laweditor/trash\" && for f in \"$0/.laweditor/chats/$1\".*; do [ -e \"$f\" ] && mv \"$f\" \"$0/.laweditor/trash/\"; done; printf ok", [dir, Places.safe(conv)], 5000)

# ---------- When the server starts ----------

def migrate.one(+base: String) -> IO(Unit):
  do IO<Unit>:
    +text : String <- Sys.read_file(base ++ ".txt")
    Sys.write_file(base ++ ".log", Ev.from_old(text))
    Sys.write_file(base ++ ".title", String.take(Sys.nth(String.lines(text), 0n), 60n))
    kept : String <- Sys.sh("touch -r \"$0.txt\" \"$0.log\"", [base], 5000)
    return Unit{}

def migrate.at(none: Bool, +base: String) -> IO(Unit):
  match none:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      migrate.one(base)

def migrate.go(ps: List<&2, String>) -> IO(Unit):
  match ps:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case +h <> t:
      do IO<Unit>:
        migrate.at(String.is_empty(h), h)
        migrate.go(t)

# What the server left open when it stopped is closed (EVENTS.bend, left): nobody waits for it anymore.
def close.one(none: Bool, +path: String, events: String) -> IO(Unit):
  match none:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      Sys.append_file(path, events)

def close.at(none: Bool, +path: String) -> IO(Unit):
  match none:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      do IO<Unit>:
        +log : String <- Sys.read_file(path)
        close.one(String.is_empty(Ev.left(log)), path, Ev.left(log))

def close.go(ps: List<&2, String>) -> IO(Unit):
  match ps:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case +h <> t:
      do IO<Unit>:
        close.at(String.is_empty(h), h)
        close.go(t)

# Nothing was running before the server started: every conversation is idle, no law is being written, and
# a terminal left from before is ended.
# A conversation kept by 0.1.10 (a .txt of "Person:" and "Agent:" lines) gets its events; the .txt stays.
def start() -> IO(Unit):
  do IO<Unit>:
    old : String <- Sys.sh(projects_sh() ++ "projects | while IFS=\"$t\" read -r k d; do rmdir \"$d/.laweditor/lawlock\" 2>/dev/null; p=$(cat \"$d/.laweditor/term.pid\" 2>/dev/null); [ -n \"$p\" ] && { pkill -P \"$p\" 2>/dev/null; kill \"$p\" 2>/dev/null; }; rm -f \"$d/.laweditor/term.pid\" \"$d/.laweditor/term.in\"; for f in \"$d\"/.laweditor/chats/*.state; do [ -e \"$f\" ] && printf idle > \"$f\"; done; for f in \"$d\"/.laweditor/chats/*.txt; do [ -e \"$f\" ] && [ ! -e \"${f%.txt}.log\" ] && printf '%s\\n' \"${f%.txt}\"; done; done", [], 10000)
    migrate.go(String.lines(old))
    logs : String <- Sys.sh(projects_sh() ++ "projects | while IFS=\"$t\" read -r k d; do for f in \"$d\"/.laweditor/chats/*.log; do [ -e \"$f\" ] && printf '%s\\n' \"$f\"; done; done", [], 10000)
    close.go(String.lines(logs))
