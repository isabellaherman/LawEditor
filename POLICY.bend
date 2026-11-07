# LawEditor: what each agent may do. Pure; its rules are in LAWS.bend.

import Base

# The tools an agent can be given.
def read() -> U32: 0
def edit() -> U32: 1
def write() -> U32: 2
def run_bend() -> U32: 3

# The agents: the chat, and the one that writes laws.
def chat() -> U32: 0
def law_agent() -> U32: 1

# The tools each agent is given.
def tools(mode: U32) -> List<U32>:
  match mode:
    case 0:
      [read()]
    case n:
      [read(), edit(), write(), run_bend()]
