# LawEditor: how a flow is written. A flow is data: its steps, who acts in each, and where each goes.
# The diagram is drawn from this data, so it shows what the code says; laws check the flow itself.
#
#   Person: you act (talk, answer a question).
#   Skill:  a model acts, from a prompt. It can get it wrong.
#   System: Bend acts. Laws prove what it does.

import Base

type Who is Data:
  Person{}
  Skill{}
  System{}

# An arrow to another step (by its place in the flow), with what makes it go there.
type Go is Data:
  Go{to: Nat, label: String}

# A step: its name, who acts, whether it writes a file, and its arrows. A step with no arrows ends the flow.
type Step is Data:
  Step{name: String, who: Who, writes: Bool, next: List<&2, Go>}

# ---------- Reading a flow ----------

def nowhere() -> Step:
  Step{"?", System{}, False{}, []}

def at(f: List<&2, Step>, i: Nat) -> Step:
  match f i:
    case Nil{} _:
      nowhere()
    case h <> t 0n:
      h
    case h <> t 1n+k:
      at(t, k)

def size(f: List<&2, Step>) -> Nat:
  match f:
    case Nil{}:
      0n
    case h <> t:
      (1n + size(t) : Nat)

def is_person(w: Who) -> Bool:
  match w:
    case Person{}:
      True{}
    case Skill{}:
      False{}
    case System{}:
      False{}

def is_skill(w: Who) -> Bool:
  match w:
    case Person{}:
      False{}
    case Skill{}:
      True{}
    case System{}:
      False{}

def is_system(w: Who) -> Bool:
  match w:
    case Person{}:
      False{}
    case Skill{}:
      False{}
    case System{}:
      True{}

def name_of(s: Step) -> String:
  match s:
    case Step{n, w, x, g}:
      n

def who_of(s: Step) -> Who:
  match s:
    case Step{n, w, x, g}:
      w

def writes_of(s: Step) -> Bool:
  match s:
    case Step{n, w, x, g}:
      x

def next_of(s: Step) -> List<&2, Go>:
  match s:
    case Step{n, w, x, g}:
      g

def to_of(g: Go) -> Nat:
  match g:
    case Go{t, l}:
      t

def targets(gs: List<&2, Go>) -> List<&2, Nat>:
  match gs:
    case Nil{}:
      Nil{}
    case h <> t:
      to_of(h) <> targets(t)

def append(xs: List<&2, Nat>, ys: List<&2, Nat>) -> List<&2, Nat>:
  match xs:
    case Nil{}:
      ys
    case h <> t:
      h <> append(t, ys)

# ---------- Checks on a flow ----------

# Every arrow goes to a step of the flow.
def arrows_in.go(gs: List<&2, Go>, +n: Nat) -> Bool:
  match gs:
    case Nil{}:
      True{}
    case h <> t:
      (to_of(h) < n : Nat) && arrows_in.go(t, n)

def arrows_in(ss: List<&2, Step>, +n: Nat) -> Bool:
  match ss:
    case Nil{}:
      True{}
    case h <> t:
      arrows_in.go(next_of(h), n) && arrows_in(t, n)

def well_formed(+f: List<&2, Step>) -> Bool:
  arrows_in(f, size(f))

# After a skill comes the system: a model's step never goes straight on to another model, or to you, unchecked.
def to_system.go(gs: List<&2, Go>, +f: List<&2, Step>) -> Bool:
  match gs:
    case Nil{}:
      True{}
    case h <> t:
      is_system(who_of(at(f, to_of(h)))) && to_system.go(t, f)

def skill_then_system.at(skill: Bool, gs: List<&2, Go>, +f: List<&2, Step>) -> Bool:
  match skill:
    case True{}:
      to_system.go(gs, f)
    case False{}:
      True{}

def skill_then_system.step(+s: Step, +f: List<&2, Step>) -> Bool:
  skill_then_system.at(is_skill(who_of(s)), next_of(s), f)

def skill_then_system.go(ss: List<&2, Step>, +f: List<&2, Step>) -> Bool:
  match ss:
    case Nil{}:
      True{}
    case h <> t:
      skill_then_system.step(h, f) && skill_then_system.go(t, f)

def skill_then_system(+f: List<&2, Step>) -> Bool:
  skill_then_system.go(f, f)

# Can a file be written from these steps without passing through you? It walks every path, a step at a time.
# One step of the walk: does this step write (outside you), and where does it go next? Your steps stop the walk.
def walk.at(person: Bool, writes: Bool, gs: List<&2, Go>) -> Bool & List<&2, Nat>:
  match person:
    case True{}:
      (False{}, [])
    case False{}:
      (writes, targets(gs))

def walk(+s: Step) -> Bool & List<&2, Nat>:
  walk.at(is_person(who_of(s)), writes_of(s), next_of(s))

def merge.at(x: Bool, xs: List<&2, Nat>, b: Bool & List<&2, Nat>) -> Bool & List<&2, Nat>:
  match b:
    case (y, ys):
      (x || y, append(xs, ys))

def merge(a: Bool & List<&2, Nat>, b: Bool & List<&2, Nat>) -> Bool & List<&2, Nat>:
  match a:
    case (x, xs):
      merge.at(x, xs, b)

# Every step on the front of the walk, at once.
def front(+f: List<&2, Step>, from: List<&2, Nat>) -> Bool & List<&2, Nat>:
  match from:
    case Nil{}:
      (False{}, [])
    case i <> rest:
      merge(walk(at(f, i)), front(f, rest))

# fuel bounds the walk; if it runs out with steps left, the answer is True (not shown safe), so a law asking False fails.
def unguarded.go(fuel: Nat, +f: List<&2, Step>, r: Bool & List<&2, Nat>) -> Bool:
  match fuel:
    case 0n:
      True{}
    case 1n+k:
      match r:
        case (hit, xs):
          match hit xs:
            case True{} _:
              True{}
            case False{} Nil{}:
              False{}
            case False{} h <> t:
              unguarded.go(k, f, front(f, h <> t))

def unguarded(fuel: Nat, +f: List<&2, Step>, from: List<&2, Nat>) -> Bool:
  unguarded.go(fuel, f, front(f, from))
