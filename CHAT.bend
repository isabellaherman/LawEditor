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
