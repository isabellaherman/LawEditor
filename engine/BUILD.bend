# LawEditor's engine: Bend's own pipeline, run on a project after the chat changed it. What the chat
# writes is only text until Bend has read it: here a project meets the compiler, as a step of the system
# and not a promise of the model.
#
#   check  every .bend file at the project's top, with `bend <file> --check-only` (what a file imports is
#          checked with it). A law with no proof yet is a TODO, and fine; an error names its Location.
#   page   a project with an index.html is bundled as Bend bundles a page (`bend index.html -o <folder>`),
#          into LawEditor's own folder in the project (PLACES.page). The pages door serves it (server.bend).
#          A page that imports no .bend file is bundled too, and said to be so: its logic is outside Bend.
#
# engine/TURN.bend writes what each answers as an event (EVENTS.bend: check, page): the windows draw it,
# and the chat reads what went wrong in its next turn.

import Base
import ./SYS.bend as Sys
import ./PLACES.bend as Places

# ---------- What a run answered ----------
# Its first line is its state: ok, warn or error ("" when there was nothing to do). The rest is its text.

def state(+out: String) -> String:
  String.trim(Sys.nth(String.lines(out), 0n))

def text(+out: String) -> String:
  String.trim(String.drop(out, String.length(Sys.nth(String.lines(out), 0n))))

def ran(+out: String) -> Bool:
  Bool.not(String.is_empty(state(out)))

def failed(+out: String) -> Bool:
  String.eq(state(out), "error")

# ---------- The check ----------
# $0 the project's folder. ok: the files checked, then how many claims wait for a proof. error: the file,
# then what Bend said. Bend answers "ALL PROOFS CHECK", or counts the TODOs, or gives an error with its
# Location; anything else (bend isn't installed, it stopped) is an error too.
def check_sh() -> String:
  "cd \"$0\" || exit 0; set -- *.bend; [ -e \"$1\" ] || exit 0; names=; todo=0; for f in \"$@\"; do out=$(bend \"$f\" --check-only 2>&1); case \"$out\" in *Location:*) printf 'error\\n%s\\n%s\\n' \"$f\" \"$out\"; exit 0;; *'ALL PROOFS CHECK'*|*'TODO found'*|*'TODOs found'*) ;; *) printf 'error\\n%s\\n%s\\n' \"$f\" \"$out\"; exit 0;; esac; n=$(printf '%s' \"$out\" | sed -n 's/^Error: \\([0-9][0-9]*\\) TODOs\\{0,1\\} found.*/\\1/p' | head -n 1); todo=$((todo + ${n:-0})); names=\"${names:+$names, }$f\"; done; printf 'ok\\n%s\\n%s\\n' \"$names\" \"$todo\""

def check(+dir: String) -> IO(String):
  Sys.sh(check_sh(), [dir], 120000)

# ---------- The page's fixed pieces (harness/web) ----------
# A page is written in Bend (harness/web/WEB.md): main.bend renders it with Web.bend, and LawEditor's own
# shell runs it. $0 the project's folder, $1 harness/web. The vocabulary is kept where the chat reads it
# (.laweditor/web) and, in a project whose Bend imports it, in the project itself, always LawEditor's
# version: a Web.bend changed by hand is put back. Nothing is written in a project that doesn't use it.
def web_sh() -> String:
  "cd \"$0\" || exit 0; mkdir -p .laweditor/web && cp \"$1/Web.bend\" \"$1/WEB.md\" .laweditor/web/ 2>/dev/null; if grep -qsE '^import [.]/Web[.]bend' *.bend 2>/dev/null; then cp \"$1/Web.bend\" Web.bend; fi; true"

def web(+dir: String, +shell: String) -> IO(String):
  Sys.sh(web_sh(), [dir, shell], 5000)

# ---------- The page ----------
# $0 the project's folder, $1 where the bundle goes, inside it, $2 harness/web. ok: the page's file. warn: the
# same, with why. error: the file, then what Bend said.
# A main.bend that renders with Web.bend is the page: LawEditor's shell (index.html, app.js, driver.js) goes
# to .laweditor/web and is bundled with it. Otherwise, a project's own index.html is bundled as before, and
# said to be outside Bend when it imports no .bend file.
def page_sh() -> String:
  "cd \"$0\" || exit 0; if grep -qsE '^def render[(]' main.bend && grep -qsE '^import [.]/Web[.]bend' main.bend; then mkdir -p .laweditor/web && cp \"$2/index.html\" \"$2/app.js\" \"$2/driver.js\" \"$2/Web.bend\" .laweditor/web/ && cp \"$2/Web.bend\" Web.bend; rm -rf \"$1\"; if out=$(bend .laweditor/web/index.html -o \"$1\" 2>&1); then printf 'ok\\nmain.bend\\n'; else printf 'error\\nmain.bend\\n%s\\n' \"$out\"; fi; exit 0; fi; [ -f index.html ] || exit 0; rm -rf \"$1\"; if out=$(bend index.html -o \"$1\" 2>&1); then if find . -type f \\( -name '*.html' -o -name '*.js' -o -name '*.mjs' \\) -not -path '*/.*' -not -path '*/node_modules/*' -exec grep -lE \"[.]bend[\\\"']\" {} + 2>/dev/null | grep -q .; then printf 'ok\\nindex.html\\n'; else printf 'warn\\nThe page imports no .bend file: what it does is written outside Bend, and no law checks it.\\n'; fi; else printf 'error\\nindex.html\\n%s\\n' \"$out\"; fi"

def page(+dir: String, +shell: String) -> IO(String):
  Sys.sh(page_sh(), [dir, Places.page_in(), shell], 120000)
