# LawEditor: the chat's logic. Pure; the page asks it and draws the answer.

import Base

# Who wrote a message.
def person() -> U32: 0
def agent() -> U32: 1

# Send is on when there is text and the agent is not answering.
def can_send(answering: Bool, length: U32) -> Bool:
  match answering:
    case True{}:
      False{}
    case False{}:
      (length > 0 : U32)

# The agent's latest message: it says what it reads, then its words form, then it is done.
def reading() -> U32: 0
def writing() -> U32: 1
def done() -> U32: 2

# The model list of an AI: loading while the server asks its CLI, then ready (or empty if it can't).
def loading() -> U32: 0
def ready() -> U32: 1
def empty() -> U32: 2

# The model picker is on only when its list is ready.
def can_pick(list: U32) -> Bool:
  U32.is_eq(list, 1)

# The chat starts empty: the agent's face and the composer in the middle, until the first message.
def is_start(messages: U32) -> Bool:
  U32.is_eq(messages, 0)
