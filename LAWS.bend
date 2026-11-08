# The editor's own rules. Owned by the repo owner: PROOF.bend must prove them.
# These are about the editor, not about anyone's project.

import Base
import ./EDITOR.bend as E
import ./POLICY.bend as P
import ./HEAR.bend as H
import ./CHAT.bend as C
import ./FLOW.bend as F
import ./OFFER.bend as O

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
  {P.tools(P.chat()) == [P.read()] : List<&2, P.AgentTool>}

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
  {P.tools(P.law_agent()) == [P.read(), P.edit(), P.write(), P.run_bend()] : List<&2, P.AgentTool>}

# LAW: from Claude, the law agent gets Read, Edit, Write and only bend in the shell.
law law_agent_claude:
  {P.claude_tools(P.law_agent()) == "Read,Edit,Write,Bash(bend:*)" : String}

# LAW: from Codex, the law agent gets the sandbox that writes only in the project folder.
law law_agent_codex:
  {P.codex_sandbox(P.law_agent()) == "workspace-write" : String}

# LAW: reading never changes a file.
law reading_changes_nothing:
  {P.changes_file(P.read()) == False{} : Bool}

# LAW: the chat runs no command.
law chat_runs_nothing:
  {P.runs(P.tools(P.chat())) == False{} : Bool}

# ---------- The chat hears rules (HEAR.bend) ----------

# LAW: every session starts by asking before adding a sentence.
law hear_starts_asking:
  {H.must_ask(H.start()) == True{} : Bool}

# LAW: "Don't add" puts nothing in the document.
law dont_adds_nothing:
  {H.adds(H.dont()) == False{} : Bool}

# LAW: "Add" puts the sentence in the document.
law add_adds:
  {H.adds(H.add()) == True{} : Bool}

# LAW: after "Add", the next proposal is asked again.
law add_keeps_asking:
  {H.mode_after(H.asking(), H.add()) == H.asking() : U32}

# LAW: after "Don't add", the next proposal is asked again.
law dont_keeps_asking:
  {H.mode_after(H.asking(), H.dont()) == H.asking() : U32}

# LAW: after "Always add", the session stops asking.
law always_stops_asking:
  {H.must_ask(H.mode_after(H.asking(), H.always())) == False{} : Bool}

# LAW: once it stops asking, it doesn't start again this session.
law always_stays:
  for a: U32
  {H.mode_after(H.adding(), a) == H.adding() : U32}

# LAW: the chat's LAW: line becomes a proposal, and the person doesn't read it.
law reply_proposes:
  {H.proposal("Nice!\nLAW: \"The player starts with 3 lives\"", 0n) == "The player starts with 3 lives" : String}

law reply_hides_proposals:
  {H.words("Nice!\nLAW: \"The player starts with 3 lives\"") == "Nice!" : String}

# LAW: while a question waits for the person, nothing can be sent: the talk stops until they answer.
law question_stops_the_talk:
  for answering: Bool
  for n: U32
  {C.can_send(True{}, answering, n) == False{} : Bool}

# LAW: a sentence already in the document is not proposed again.
law known_sentence_is_not_new:
  {H.is_new("The player starts with 3 lives", "# Game\nThe player starts with 3 lives\n") == False{} : Bool}

# ---------- The hear-rules flow itself (HEAR.flow, drawn as the diagram) ----------

# LAW: every arrow of the flow goes to one of its steps.
law flow_is_whole:
  {F.well_formed(H.flow()) == True{} : Bool}

# LAW: after a model acts, Bend acts: no skill step goes on unchecked.
law flow_skill_then_system:
  {F.skill_then_system(H.flow()) == True{} : Bool}

# LAW: from what the chat hears, no path writes a file without passing through you.
law flow_writes_need_you:
  {F.unguarded(64n, H.flow(), [1n]) == False{} : Bool}

# ---------- The chat offers the mode (OFFER.flow, drawn as the diagram) ----------

# LAW: every arrow of the offer flow goes to one of its steps.
law offer_flow_is_whole:
  {F.well_formed(O.flow()) == True{} : Bool}

# LAW: after the chat offers the mode, Bend acts: no skill step goes on unchecked.
law offer_flow_skill_then_system:
  {F.skill_then_system(O.flow()) == True{} : Bool}

# LAW: from the chat's offer, no path writes a file without passing through you.
law offer_flow_writes_need_you:
  {F.unguarded(64n, O.flow(), [1n]) == False{} : Bool}

# LAW: Stay keeps the chat in the mode it starts in (Only read).
law stay_keeps_only_read:
  {O.mode_after(O.stay()) == P.chat_mode_index() : U32}

# LAW: Switch moves to a mode that asks before each change, never to one that changes freely.
law switch_asks_first:
  {P.mode_asks_at(O.mode_after(O.switch())) == True{} : Bool}

# LAW: the chat's MODE: line is for the page; the person doesn't read it.
law reply_hides_offer:
  {O.words("I can build it.\nMODE: \"Ask before changes\"") == "I can build it." : String}
