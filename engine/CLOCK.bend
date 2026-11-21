# LawEditor's engine: the clock. A model can't wake itself, so the server does it: while it runs, it looks
# at every project's timers every half minute and starts the turn of each one that came due.
#
# harness/TIMER.bend says what a timer is, when it is due and what is left of it after; TURN.bend starts
# the turn; this file only keeps looking. The clock itself calls no model: a look costs nothing, and only a
# timer that came due starts a turn.
#
# Nothing is kept in memory: the timers are files (PLACES.timers) and the time is the computer's calendar
# (SYS.now). A server that was stopped finds them as they were when it starts again, and a timer whose time
# passed meanwhile starts one turn, not one for each time it missed (TIMER.after).

import Base
import ./SYS.bend as Sys
import ./PLACES.bend as Places
import ./PROJECTS.bend as Proj
import ./TURN.bend as Turn
import ../harness/EVENTS.bend as Ev
import ../harness/TIMER.bend as Timer

# How long between two looks, in ms.
def pace() -> U32: 30000

# ---------- Every timer ----------

# Every timer of every project (a conversation with no project yet has a folder too), one per line: the
# project's key, its folder, then the timer as it is kept.
def all_sh() -> String:
  Proj.projects_sh() ++ "projects | while IFS=\"$t\" read -r k d; do for f in \"$d\"/.laweditor/timers/*; do [ -f \"$f\" ] && printf '%s\\t%s\\t%s\\n' \"$k\" \"$d\" \"$(cat \"$f\")\"; done; done; true"

def all() -> IO(String):
  Sys.sh(all_sh(), [], 10000)

def key_of(+row: String) -> String:
  Ev.nth(String.split(row, Ev.tab()), 0n)

def dir_of(+row: String) -> String:
  Ev.nth(String.split(row, Ev.tab()), 1n)

def timer_of(+row: String) -> Timer.Timer:
  Timer.read(Ev.after.drop(String.split(row, Ev.tab()), 2n))

# ---------- One timer that came due ----------

def drop(+dir: String, id: String) -> IO(Unit):
  do IO<Unit>:
    done : String <- Sys.sh("rm -f \"$0\"", [Places.timer(dir, id)], 5000)
    return Unit{}

# What is left of it is written in its place, or the file goes when nothing is.
def keep(none: Bool, +dir: String, +id: String, +left: String) -> IO(Unit):
  match none:
    case True{}:
      drop(dir, id)
    case False{}:
      Sys.write_file(Places.timer(dir, id), left)

# busy: the chat was answering, or a question waited: the timer stays as it is and is tried at the next look.
def fired(busy: Bool, gone: Bool, +dir: String, +now: U32, +z: Timer.Zone, +t: Timer.Timer) -> IO(Unit):
  match busy gone:
    case True{} _:
      IO.pure(Unit, Unit{})
    case False{} True{}:
      drop(dir, Timer.id(t))
    case False{} False{}:
      keep(String.is_empty(Timer.after(now, z, t)), dir, Timer.id(t), Timer.after(now, z, t))

def one(due: Bool, +cx: Sys.Ctx, +now: U32, +z: Timer.Zone, +key: String, +dir: String, +t: Timer.Timer) -> IO(Unit):
  match due:
    case False{}:
      IO.pure(Unit, Unit{})
    case True{}:
      do IO<Unit>:
        +r : String <- Turn.wake(cx, key, dir, t)
        fired(String.eq(r, "busy"), String.eq(r, "gone"), dir, now, z, t)

def each(rows: List<&2, String>, +cx: Sys.Ctx, +now: U32, +z: Timer.Zone) -> IO(Unit):
  match rows:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case +h <> t:
      do IO<Unit>:
        one(Timer.due(now, timer_of(h)), cx, now, z, key_of(h), dir_of(h), timer_of(h))
        each(t, cx, now, z)

# One look. The zone is asked at each look: it changes with summer time, and a time of day follows it.
def tick(+cx: Sys.Ctx) -> IO(Unit):
  do IO<Unit>:
    +now : U32 <- Sys.now()
    zone : String <- Sys.zone()
    rows : String <- all()
    each(Ev.lines(rows), cx, now, Timer.zone_of(zone))

# The clock: a look, a wait, again, for as long as the server runs.
def run(fuel: Nat, +cx: Sys.Ctx) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+f:
      do IO<Unit>:
        tick(cx)
        IO.sleep(pace())
        run(f, cx)

# ---------- What a window reads and sends ----------

# GET /api/timers: the time now on the first line, then every timer (all, above).
def list() -> IO(String):
  do IO<String>:
    now : U32 <- Sys.now()
    rows : String <- all()
    return U32.show(now) ++ "\n" ++ rows

# POST /api/p/<key>/timer-stop, body: the timer's name. It is taken away.
def stop(+dir: String, id: String) -> IO(String):
  do IO<String>:
    drop(dir, String.trim(id))
    return "ok"

# One timer, read from its file (one that isn't there reads as no timer: TIMER.is_timer).
def get(+dir: String, id: String) -> IO(Timer.Timer):
  do IO<Timer.Timer>:
    text : String <- Sys.read_file(Places.timer(dir, String.trim(id)))
    return Timer.read(String.split(String.trim(text), Ev.tab()))

def put(there: Bool, +dir: String, id: String, line: String) -> IO(String):
  match there:
    case False{}:
      IO.pure(String, "gone")
    case True{}:
      do IO<String>:
        Sys.write_file(Places.timer(dir, id), line)
        return "ok"

# POST /api/p/<key>/timer-pause, body: the timer's name. It is kept, and comes due no more until resumed.
def pause(+dir: String, +id: String) -> IO(String):
  do IO<String>:
    +t : Timer.Timer <- get(dir, id)
    put(Timer.is_timer(t), dir, Timer.id(t), Timer.pause(t))

# POST /api/p/<key>/timer-resume: it goes again, counted from now (TIMER.resume).
def resume(+dir: String, +id: String) -> IO(String):
  do IO<String>:
    +t : Timer.Timer <- get(dir, id)
    +now : U32 <- Sys.now()
    zone : String <- Sys.zone()
    put((Timer.is_timer(t) && Bool.not(U32.is_eq(now, 0))), dir, Timer.id(t), Timer.resume(now, Timer.zone_of(zone), t))

def test.at(there: Bool, +cx: Sys.Ctx, +key: String, +dir: String, +t: Timer.Timer) -> IO(String):
  match there:
    case False{}:
      IO.pure(String, "gone")
    case True{}:
      Turn.wake(cx, key, dir, t)

# POST /api/p/<key>/timer-test: its turn starts now, once, and its own time stays as it was. A test is a
# real turn: it does what the timer does. Answers ok, busy (the chat answers or a question waits) or gone.
def test(+cx: Sys.Ctx, +key: String, +dir: String, +id: String) -> IO(String):
  do IO<String>:
    +t : Timer.Timer <- get(dir, id)
    test.at(Timer.is_timer(t), cx, key, dir, t)
