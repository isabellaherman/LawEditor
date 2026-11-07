# The editor's own rules. Owned by the repo owner: PROOF.bend must prove them.
# These are about the editor, not about anyone's project.

import Base
import ./EDITOR.bend as E
import ./POLICY.bend as P

# LAW: a title never gets a state.
law title_stays_title:
  {E.after_edit(E.title()) == E.title() : U32}

# LAW: editing a line with a law sends it back to empty.
law edit_clears_ok:
  {E.after_edit(E.ok()) == E.empty() : U32}

# LAW: editing a line that failed sends it back to empty.
law edit_clears_error:
  {E.after_edit(E.error()) == E.empty() : U32}

# LAW: if the line was edited while the agent worked, the answer is dropped.
law edited_result_is_dropped:
  for good: Bool
  {E.after_result(True{}, good) == E.empty() : U32}

# LAW: with nothing pending, there is nothing to generate.
law nothing_to_generate:
  {E.can_generate(False{}, 0) == False{} : Bool}

# LAW: one run at a time.
law one_run_at_a_time:
  for n: U32
  {E.can_generate(True{}, n) == False{} : Bool}

# LAW: a law block and a sentence block have the same minimum height.
law law_block_min_is_sentence_min:
  {E.min_lines(E.law_block()) == E.min_lines(E.sentence()) : U32}

# LAW: the chat may only read.
law chat_only_reads:
  {P.tools(P.chat()) == [P.read()] : List<U32>}

# LAW: from Claude, the chat gets only Read.
law chat_claude_reads:
  {P.claude_tools(P.chat()) == "Read" : String}

# LAW: from Codex, the chat gets the read-only sandbox.
law chat_codex_reads:
  {P.codex_sandbox(P.chat()) == "read-only" : String}

# LAW: the chat never changes a file.
law chat_never_changes:
  {P.changes(P.tools(P.chat())) == False{} : Bool}

# LAW: the law agent may read, edit, write and run bend, and nothing else.
law law_agent_tools:
  {P.tools(P.law_agent()) == [P.read(), P.edit(), P.write(), P.run_bend()] : List<U32>}

# LAW: from Claude, the law agent gets Read, Edit, Write and only bend in the shell.
law law_agent_claude:
  {P.claude_tools(P.law_agent()) == "Read,Edit,Write,Bash(bend:*)" : String}

# LAW: from Codex, the law agent gets the sandbox that writes only in the project folder.
law law_agent_codex:
  {P.codex_sandbox(P.law_agent()) == "workspace-write" : String}
