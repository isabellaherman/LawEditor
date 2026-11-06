# LawEditor: the editor's logic. Pure; web/main.js asks it what happens and draws the answer.
#
# Each line of the document has a state:
#   title (no state) · empty (written, no law yet) · busy (the agent is on it)
#   ok (the law compiles) · error (it doesn't, or the agent couldn't write one)

import Base

def title() -> U32: 0
def empty() -> U32: 1
def busy() -> U32: 2
def ok() -> U32: 3
def error() -> U32: 4

# After the person edits a line, an old result no longer matches its text: back to empty.
# A title stays a title. A line the agent is on stays busy; its result will be dropped.
def after_edit(s: U32) -> U32:
  match s:
    case 0:
      0
    case 2:
      2
    case n:
      1

# The agent answered. If the line was edited meanwhile, the answer is for old text: drop it.
def after_result.good(good: Bool) -> U32:
  match good:
    case True{}:
      3
    case False{}:
      4

def after_result(edited: Bool, good: Bool) -> U32:
  match edited:
    case True{}:
      1
    case False{}:
      after_result.good(good)

# Lines the agent should take: empty ones, and ones that failed (to try again).
def is_pending(+s: U32) -> Bool:
  (U32.is_eq(s, 1) || U32.is_eq(s, 4))

# Generate is on only when nothing is running and some line is pending.
def can_generate(running: Bool, pending: U32) -> Bool:
  match running:
    case True{}:
      False{}
    case False{}:
      (pending > 0 : U32)
