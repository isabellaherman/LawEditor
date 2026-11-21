# LawEditor: the chat sets timers. Pure; the engine and the windows ask it.
#
# A timer is a resource of the harness: a way to be called again. A model has no clock: it only answers
# when it is called. So a chat that should come back by itself asks the harness to call it. What it does
# when it is called is not said here: that is the person's own orientation, a skill (SKILL.bend).
# Three parts, as with the rules it hears (HEAR.bend):
#   the instructions (TIMER.md) ask the chat to end its reply with one line
#     TIMER: weekdays 10:00 "Run the skill Check Discord"
#     TIMER: mon,thu 10:30 "Post the rules-design report"
#     TIMER: every 4h "Read the notes and say what changed"
#     TIMER: in 30m "Run the tests again"
#   for something the person wants done later, or again and again.
#   the system (this file) reads those lines, and says when a timer is due and what is left of it after.
#   the engine keeps the clock (engine/CLOCK.bend) and starts the turn (engine/TURN.bend).
# No timer is set without the person's answer, and a turn a timer started sets none.
# A timer that repeats goes on until the person pauses it or stops it.

import Base
import ./EVENTS.bend as Ev

# ---------- The limits ----------
# All in seconds. The clock looks every 30 seconds, so nothing is asked for sooner than a minute.

def shortest() -> U32: 60
def longest() -> U32: 2592000

# How many timers a project may have at once.
def most() -> U32: 20

def pick32(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

# ---------- A span of time: 90s, 30m, 4h, 2d ----------

def unit.at(s: Bool, m: Bool, h: Bool, d: Bool) -> U32:
  match s m h d:
    case True{} _ _ _:
      1
    case False{} True{} _ _:
      60
    case False{} False{} True{} _:
      3600
    case False{} False{} False{} True{}:
      86400
    case False{} False{} False{} False{}:
      0

# The seconds in one of a unit (0 for a letter that names none).
def unit(+c: Char) -> U32:
  unit.at(Char.is_eq(c, 's'), Char.is_eq(c, 'm'), Char.is_eq(c, 'h'), Char.is_eq(c, 'd'))

def number(m: Maybe<&2, U32>) -> U32:
  match m:
    case None{}:
      0
    case Some{n}:
      n

# n of a unit, in seconds; 0 when it has no unit, or is longer than the longest (so it never overflows).
def span.times.at(fits: Bool, n: U32, u: U32) -> U32:
  match fits:
    case True{}:
      (n * u : U32)
    case False{}:
      0

def span.times(none: Bool, +n: U32, +u: U32) -> U32:
  match none:
    case True{}:
      0
    case False{}:
      span.times.at(U32.is_le(n, (longest() / u : U32)), n, u)

def span.rev(s: String) -> U32:
  match s:
    case SNil{}:
      0
    case SCon{+h, t}:
      span.times(U32.is_eq(unit(h), 0), number(U32.read(String.reverse(t))), unit(h))

# "4h" is 14400; 0 for what isn't a span.
def span(s: String) -> U32:
  span.rev(String.reverse(String.trim(s)))

# A span as a person reads it: the largest unit that fits it whole.
def plural(+n: U32, word: String) -> String:
  U32.show(n) ++ " " ++ word ++ Ev.first.pick(U32.is_eq(n, 1), "", "s")

def span_text.at(d: Bool, h: Bool, m: Bool, +secs: U32) -> String:
  match d h m:
    case True{} _ _:
      plural((secs / 86400 : U32), "day")
    case False{} True{} _:
      plural((secs / 3600 : U32), "hour")
    case False{} False{} True{}:
      plural((secs / 60 : U32), "minute")
    case False{} False{} False{}:
      plural(secs, "second")

def whole(+secs: U32, +u: U32) -> Bool:
  (U32.is_ge(secs, u) && U32.is_eq((secs % u : U32), 0))

def span_text(+secs: U32) -> String:
  span_text.at(whole(secs, 86400), whole(secs, 3600), whole(secs, 60), secs)

# ---------- The days of a week, and a time of day ----------
# The days are bits: Monday 1, Tuesday 2, Wednesday 4, Thursday 8, Friday 16, Saturday 32, Sunday 64.

def weekdays() -> U32: 31
def weekends() -> U32: 96
def all_days() -> U32: 127

# A day's bit from its name (0 for a word that names none).
def day_bit(+w: String) -> U32:
  pick32(String.eq(w, "mon"), 1, pick32(String.eq(w, "tue"), 2, pick32(String.eq(w, "wed"), 4, pick32(String.eq(w, "thu"), 8,
  pick32(String.eq(w, "fri"), 16, pick32(String.eq(w, "sat"), 32, pick32(String.eq(w, "sun"), 64, 0)))))))

# The days a list of names says; 0 as soon as one of them names no day.
def days.go(xs: List<&2, String>, acc: U32, ok: Bool) -> U32:
  match xs ok:
    case Nil{} True{}:
      acc
    case Nil{} False{}:
      0
    case h <> t False{}:
      0
    case +h <> t True{}:
      days.go(t, (acc .|. day_bit(String.to_lower(String.trim(h))) : U32), Bool.not(U32.is_eq(day_bit(String.to_lower(String.trim(h))), 0)))

# "weekdays", "weekends", "daily", or names split by commas ("mon,thu"); 0 for anything else.
def days(+w: String) -> U32:
  pick32(String.eq(w, "weekdays"), weekdays(), pick32(String.eq(w, "weekends"), weekends(), pick32(String.eq(w, "daily"), all_days(),
  days.go(String.split(w, ','), 0, True{}))))

def no_time() -> U32: 86400

def time.at(ok: Bool, h: U32, m: U32) -> U32:
  match ok:
    case True{}:
      ((h * 3600 : U32) + (m * 60 : U32) : U32)
    case False{}:
      no_time()

def time.in(+h: String, +m: String, more: Bool) -> U32:
  time.at((Bool.not(more) && Bool.not(String.is_empty(h)) && Nat.is_eq(String.length(m), 2n) && U32.is_lt(number(U32.read(h)), 24) && U32.is_lt(number(U32.read(m)), 60)), number(U32.read(h)), number(U32.read(m)))

# "10:30" is 37800, the seconds since the day began; no_time() for what isn't a time of day.
def time(+s: String) -> U32:
  time.in(Ev.nth(String.split(s, ':'), 0n), Ev.nth(String.split(s, ':'), 1n), Bool.not(String.is_empty(Ev.nth(String.split(s, ':'), 2n))))

def pad2(+n: U32) -> String:
  Ev.first.pick(U32.is_lt(n, 10), "0" ++ U32.show(n), U32.show(n))

def time_text(+sod: U32) -> String:
  pad2((sod / 3600 : U32)) ++ ":" ++ pad2(((sod % 3600 : U32) / 60 : U32))

def has(mask: U32, bit: U32) -> Bool:
  Bool.not(U32.is_eq((mask .&. bit : U32), 0))

def day_name.at(on: Bool, name: String, rest: List<&2, String>) -> List<&2, String>:
  match on:
    case True{}:
      name <> rest
    case False{}:
      rest

def day_name(+mask: U32, bit: U32, name: String, rest: List<&2, String>) -> List<&2, String>:
  day_name.at(has(mask, bit), name, rest)

def days_text.list(+mask: U32) -> String:
  String.join(day_name(mask, 1, "Mon", day_name(mask, 2, "Tue", day_name(mask, 4, "Wed", day_name(mask, 8, "Thu", day_name(mask, 16, "Fri", day_name(mask, 32, "Sat", day_name(mask, 64, "Sun", Nil{}))))))), ", ")

# The days as a person reads them: "weekdays", "every day", "Mon, Thu".
def days_text(+mask: U32) -> String:
  Ev.first.pick(U32.is_eq(mask, weekdays()), "weekdays", Ev.first.pick(U32.is_eq(mask, all_days()), "every day", Ev.first.pick(U32.is_eq(mask, weekends()), "weekends", days_text.list(mask))))

# ---------- Where the computer is: its hours ahead of or behind the world's clock ----------
# The calendar counts seconds the same everywhere. A time of day ("10:00") is a place's own, so the
# computer says how far its clock is from the world's: `date +%z` answers "-0300" or "+0530".

type Zone is Data:
  Zone{west: Bool, secs: U32}

def zone.at(ok: Bool, west: Bool, +n: U32) -> Zone:
  match ok:
    case True{}:
      Zone{west, (((n / 100 : U32) * 3600 : U32) + ((n % 100 : U32) * 60 : U32) : U32)}
    case False{}:
      Zone{False{}, 0}

def zone.in(s: String) -> Zone:
  match s:
    case SNil{}:
      Zone{False{}, 0}
    case SCon{+h, +t}:
      zone.at((Nat.is_eq(String.length(t), 4n) && (Char.is_eq(h, '-') || Char.is_eq(h, '+'))), Char.is_eq(h, '-'), number(U32.read(t)))

def zone_of(text: String) -> Zone:
  zone.in(String.trim(text))

# The seconds a clock on the wall here shows, counted from 1970 as if here were the world's clock.
def local(now: U32, z: Zone) -> U32:
  match z:
    case Zone{True{}, secs}:
      (now - secs : U32)
    case Zone{False{}, secs}:
      (now + secs : U32)

def back(t: U32, z: Zone) -> U32:
  match z:
    case Zone{True{}, secs}:
      (t + secs : U32)
    case Zone{False{}, secs}:
      (t - secs : U32)

def bit_at(+i: U32) -> U32:
  pick32(U32.is_eq(i, 0), 1, pick32(U32.is_eq(i, 1), 2, pick32(U32.is_eq(i, 2), 4, pick32(U32.is_eq(i, 3), 8, pick32(U32.is_eq(i, 4), 16, pick32(U32.is_eq(i, 5), 32, 64))))))

# The bit of the day a count of days since 1970 falls on (that day was a Thursday).
def bit_of(day: U32) -> U32:
  bit_at(((day + 3 : U32) % 7 : U32))

def slot.pick(hit: Bool, +cand: U32, +z: Zone, later: U32) -> U32:
  match hit:
    case True{}:
      back(cand, z)
    case False{}:
      later

# The first of the next eight days that is one of the days, at that time of day, after now.
def slot.go(fuel: Nat, +day: U32, +loc: U32, +z: Zone, +mask: U32, +sod: U32) -> U32:
  match fuel:
    case 0n:
      0
    case 1n+f:
      slot.pick((has(mask, bit_of(day)) && U32.is_gt(((day * 86400 : U32) + sod : U32), loc)), ((day * 86400 : U32) + sod : U32), z, slot.go(f, (day + 1 : U32), loc, z, mask, sod))

# When "these days, at this time" comes next after now (0 when no day is named).
def slot(+now: U32, +z: Zone, mask: U32, sod: U32) -> U32:
  slot.go(8n, (local(now, z) / 86400 : U32), local(now, z), z, mask, sod)

# ---------- The chat's reply ----------

def mark() -> String: "TIMER:"

def quote() -> Char: Char.from_u32(34)

def but_last.at(t: List<&2, String>, h: String) -> List<&2, String>:
  match t:
    case Nil{}:
      Nil{}
    case h2 <> t2:
      h <> but_last.at(t2, h2)

# A list without its last item.
def but_last(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      but_last.at(t, h)

# The words before the first quote, less the mark: "every 4h", "weekdays 10:00".
def head_of(+line: String) -> List<&2, String>:
  String.split(String.trim(String.drop(Ev.nth(String.split(line, quote()), 0n), String.length(mark()))), ' ')

# A timer is of one of three kinds: once (in 30m), every (every 4h), days (weekdays 10:00).
def once() -> U32: 0
def every() -> U32: 1
def on_days() -> U32: 2

def kind_of(+line: String) -> U32:
  pick32(String.eq(Ev.nth(head_of(line), 0n), "in"), once(), pick32(String.eq(Ev.nth(head_of(line), 0n), "every"), every(), on_days()))

# A span's seconds, for once and every; a time of day's seconds, for days.
def secs_of(+line: String) -> U32:
  pick32(U32.is_eq(kind_of(line), on_days()), time(Ev.nth(head_of(line), 1n)), span(Ev.nth(head_of(line), 1n)))

# The days it comes due on (0 for a timer that isn't of days, or names none).
def days_of(+line: String) -> U32:
  pick32(U32.is_eq(kind_of(line), on_days()), days(String.to_lower(Ev.nth(head_of(line), 0n))), 0)

# What the chat is to be told when the timer comes due: the words between the first quote and the last.
def prompt_of(+line: String) -> String:
  String.trim(String.join(but_last(Ev.after.drop(String.split(line, quote()), 1n)), "\""))

# Is its time one a timer may have? A span within the limits; or at least one day and a time of day.
def is_time(+line: String) -> Bool:
  ((U32.is_eq(kind_of(line), on_days()) && Bool.not(U32.is_eq(days_of(line), 0)) && U32.is_lt(secs_of(line), no_time())) || (Bool.not(U32.is_eq(kind_of(line), on_days())) && U32.is_ge(secs_of(line), shortest())))

# Is this line a timer the chat proposes? Its mark, a time it may have, and what to do.
def is_proposal.in(+line: String) -> Bool:
  (String.starts_with(line, mark()) && String.ends_with(line, "\"") && is_time(line) && Bool.not(String.is_empty(prompt_of(line))))

def is_proposal(line: String) -> Bool:
  is_proposal.in(String.trim(line))

def keep(yes: Bool, x: String, rest: List<&2, String>) -> List<&2, String>:
  match yes:
    case True{}:
      x <> rest
    case False{}:
      rest

def proposals.go(ls: List<&2, String>) -> List<&2, String>:
  match ls:
    case Nil{}:
      Nil{}
    case +h <> t:
      keep(is_proposal(h), String.trim(h), proposals.go(t))

# The timers the chat proposed, each as its line, in order.
def proposals(reply: String) -> List<&2, String>:
  proposals.go(String.lines(reply))

def count(reply: String) -> Nat:
  Ev.length(proposals(reply))

def proposal(reply: String, n: Nat) -> String:
  Ev.nth(proposals(reply), n)

def words.go(ls: List<&2, String>) -> List<&2, String>:
  match ls:
    case Nil{}:
      Nil{}
    case +h <> t:
      keep(Bool.not(String.starts_with(String.trim(h), mark())), h, words.go(t))

# What the person reads: the reply without its TIMER: lines.
def words(reply: String) -> String:
  String.trim(String.join(words.go(String.lines(reply)), "\n"))

# ---------- The question ----------

# When it comes due, in words: "in 30 minutes", "every 4 hours", "weekdays at 10:00".
def when.at(+kind: U32, +secs: U32, days: U32) -> String:
  Ev.first.pick(U32.is_eq(kind, once()), "in " ++ span_text(secs), Ev.first.pick(U32.is_eq(kind, every()), "every " ++ span_text(secs), days_text(days) ++ " at " ++ time_text(secs)))

def when(+line: String) -> String:
  when.at(kind_of(line), secs_of(line), days_of(line))

# What a timer costs and does, said before the person answers: each time it comes due is a whole turn.
def cost_text(once: Bool) -> String:
  match once:
    case True{}:
      "Once. The chat is called again then, as with a message of yours, to do this:"
    case False{}:
      "It repeats until you pause or stop it. Each time, the chat is called again, as with a message of yours, to do this:"

# What the person is asked: the question, then what it will cost and do.
def question(+line: String) -> String:
  "Set a timer, " ++ when(line) ++ "?\n" ++ cost_text(U32.is_eq(kind_of(line), once())) ++ "\n" ++ prompt_of(line)

def set_word() -> String: "set"
def dont_word() -> String: "dont"

def sets(+word: String) -> Bool:
  String.eq(word, set_word())

# Is there room for one more? have: how many the project has.
def has_room(have: U32) -> Bool:
  U32.is_lt(have, most())

def full_note() -> String:
  "Not set: this project already has " ++ U32.show(most()) ++ " timers. Stop one first."

def set_note(+line: String) -> String:
  "Timer set: " ++ when(line) ++ "."

# ---------- A timer, as it is kept ----------
# kind: once, every or days. secs: its span, or its time of day. days: the days it comes due on.
# next: when it comes due, in seconds since 1970, as the computer's calendar counts them. paused: it is
# kept, and never due. conv, ai, model, mode: the conversation that set it and what it was talking with,
# so the turn it starts is the same kind as the one that asked for it.
type Timer is Data:
  Timer{id: String, kind: U32, secs: U32, days: U32, next: U32, paused: Bool, conv: String, ai: String, model: String, mode: U32, prompt: String}

def id(t: Timer) -> String:
  match t:
    case Timer{id, kind, secs, days, next, paused, conv, ai, model, mode, prompt}:
      id

def kind(t: Timer) -> U32:
  match t:
    case Timer{id, kind, secs, days, next, paused, conv, ai, model, mode, prompt}:
      kind

def secs(t: Timer) -> U32:
  match t:
    case Timer{id, kind, secs, days, next, paused, conv, ai, model, mode, prompt}:
      secs

def days_on(t: Timer) -> U32:
  match t:
    case Timer{id, kind, secs, days, next, paused, conv, ai, model, mode, prompt}:
      days

def next(t: Timer) -> U32:
  match t:
    case Timer{id, kind, secs, days, next, paused, conv, ai, model, mode, prompt}:
      next

def paused(t: Timer) -> Bool:
  match t:
    case Timer{id, kind, secs, days, next, paused, conv, ai, model, mode, prompt}:
      paused

def conv(t: Timer) -> String:
  match t:
    case Timer{id, kind, secs, days, next, paused, conv, ai, model, mode, prompt}:
      conv

def ai(t: Timer) -> String:
  match t:
    case Timer{id, kind, secs, days, next, paused, conv, ai, model, mode, prompt}:
      ai

def model(t: Timer) -> String:
  match t:
    case Timer{id, kind, secs, days, next, paused, conv, ai, model, mode, prompt}:
      model

def mode(t: Timer) -> U32:
  match t:
    case Timer{id, kind, secs, days, next, paused, conv, ai, model, mode, prompt}:
      mode

def prompt(t: Timer) -> String:
  match t:
    case Timer{id, kind, secs, days, next, paused, conv, ai, model, mode, prompt}:
      prompt

# When a timer of this kind comes due next, counted from now: a span from now, or its next day and time.
def next_from(+now: U32, z: Zone, +kind: U32, +secs: U32, days: U32) -> U32:
  pick32(U32.is_eq(kind, on_days()), slot(now, z, days, secs), (now + secs : U32))

# The timer a proposal becomes, set now. Its first turn is at its next time, never when it is set.
def make(id: String, +line: String, +now: U32, z: Zone, conv: String, ai: String, model: String, mode: U32) -> Timer:
  Timer{id, kind_of(line), secs_of(line), days_of(line), next_from(now, z, kind_of(line), secs_of(line), days_of(line)), False{}, conv, ai, model, mode, prompt_of(line)}

def kind_text(+k: U32) -> String:
  Ev.first.pick(U32.is_eq(k, once()), "once", Ev.first.pick(U32.is_eq(k, every()), "every", "days"))

def kind_read(+s: String) -> U32:
  pick32(String.eq(s, "once"), once(), pick32(String.eq(s, "every"), every(), on_days()))

def flag(b: Bool) -> String:
  match b:
    case True{}:
      "1"
    case False{}:
      "0"

# One line, its fields split by tabs (what it asks may hold new lines: EVENTS.esc writes them \n).
def write(t: Timer) -> String:
  match t:
    case Timer{id, kind, secs, days, next, paused, conv, ai, model, mode, prompt}:
      String.join([id, kind_text(kind), U32.show(secs), U32.show(days), U32.show(next), flag(paused), conv, ai, model, U32.show(mode), Ev.esc(prompt)], "\t")

def read(+f: List<&2, String>) -> Timer:
  Timer{Ev.nth(f, 0n), kind_read(Ev.nth(f, 1n)), number(U32.read(Ev.nth(f, 2n))), number(U32.read(Ev.nth(f, 3n))), number(U32.read(Ev.nth(f, 4n))), String.eq(Ev.nth(f, 5n), "1"), Ev.nth(f, 6n), Ev.nth(f, 7n), Ev.nth(f, 8n), number(U32.read(Ev.nth(f, 9n))), Ev.unesc(Ev.nth(f, 10n))}

# A line that is a timer: it has a name and a time to come due.
def is_timer(+t: Timer) -> Bool:
  (Bool.not(String.is_empty(id(t))) && Bool.not(U32.is_eq(next(t), 0)))

# ---------- The clock's questions ----------

# Is it time? Never for one that is paused. now: the calendar's seconds (0 when it couldn't be read: then
# nothing is due).
def due(+now: U32, +t: Timer) -> Bool:
  (is_timer(t) && Bool.not(paused(t)) && Bool.not(U32.is_eq(now, 0)) && U32.is_ge(now, next(t)))

def at_next(t: Timer, next2: U32, paused2: Bool) -> Timer:
  match t:
    case Timer{id, kind, secs, days, next, paused, conv, ai, model, mode, prompt}:
      Timer{id, kind, secs, days, next2, paused2, conv, ai, model, mode, prompt}

# What is left of a timer after it started a turn, as its line ("" when nothing is: it is then taken away).
# One that doesn't repeat is done. One that repeats comes due again counted from now, not from when it
# should have: the hours a computer slept through count as one turn, never as a row of them.
def after.at(once: Bool, +now: U32, z: Zone, +t: Timer) -> String:
  match once:
    case True{}:
      ""
    case False{}:
      write(at_next(t, next_from(now, z, kind(t), secs(t), days_on(t)), False{}))

def after(+now: U32, z: Zone, +t: Timer) -> String:
  after.at(U32.is_eq(kind(t), once()), now, z, t)

# Paused: it is kept as it is, and never comes due.
def pause(+t: Timer) -> String:
  write(at_next(t, next(t), True{}))

# Going again: one that repeats counts from now, as after a turn; one that doesn't keeps its time (if
# that time passed while it was paused, it comes due at the clock's next look).
def resume(+now: U32, z: Zone, +t: Timer) -> String:
  write(at_next(t, pick32(U32.is_eq(kind(t), once()), next(t), next_from(now, z, kind(t), secs(t), days_on(t))), False{}))

# ---------- What the chat is told ----------

# When a timer comes due, in the conversation: "every 4 hours", "weekdays at 10:00".
def when_of(+t: Timer) -> String:
  when.at(kind(t), secs(t), days_on(t))

# Added to what the chat is told in a turn a timer started.
def told() -> String:
  "LawEditor: a timer the person set started this turn; they may not be here. Do what the timer asks, with what you may do in this mode. When it names a skill, read that skill's file first and follow it. If there is nothing new to say, answer with one short line saying so. Write no TIMER: line in this reply: a turn a timer started sets no timer."

# ---------- A list of them, for a window ----------
# About how long: seconds under two minutes, then minutes, hours, days, rounded down.
def span_text.near.at(d: Bool, h: Bool, m: Bool, +secs: U32) -> String:
  match d h m:
    case True{} _ _:
      plural((secs / 86400 : U32), "day")
    case False{} True{} _:
      plural((secs / 3600 : U32), "hour")
    case False{} False{} True{}:
      plural((secs / 60 : U32), "minute")
    case False{} False{} False{}:
      plural(secs, "second")

def span_text.near(+secs: U32) -> String:
  span_text.near.at(U32.is_ge(secs, 172800), U32.is_ge(secs, 7200), U32.is_ge(secs, 120), secs)

# left: until it comes due, from now; or that it is paused.
def left.at(paused: Bool, late: Bool, +now: U32, +next: U32) -> String:
  match paused late:
    case True{} _:
      "paused"
    case False{} True{}:
      "due now"
    case False{} False{}:
      "next in " ++ span_text.near((next - now : U32))

def left(+now: U32, +t: Timer) -> String:
  left.at(paused(t), U32.is_ge(now, next(t)), now, next(t))

# One timer, in a few words: when, and the first line of what it asks.
def brief(+t: Timer) -> String:
  when_of(t) ++ "  " ++ String.take(Ev.nth(String.lines(prompt(t)), 0n), 80n)

# One timer, in a line of text: when, when next (or paused), and the first line of what it asks.
def row(+now: U32, +t: Timer) -> String:
  when_of(t) ++ "  (" ++ left(now, t) ++ ")  " ++ String.take(Ev.nth(String.lines(prompt(t)), 0n), 80n)
