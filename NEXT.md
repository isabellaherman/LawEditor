# Next: a question when the server stops (found on 2026-11-19)

Found while testing on Linux. Not built: what to do is below, smallest first.

## Today

A question that waits (a rule, the mode, an action) is held by the turn, inside the server. When the server stops, the turn is gone; when it starts again, `harness/EVENTS.bend` (`left`) answers every open question no, with the same note for all: "Not answered: LawEditor was closed while it waited." The person sees the question closed and doesn't know what to do. Waiting long is fine (no time limit): only a restart closes it.

## Small (text and drawing only)

- **A note for each kind of question**, saying what to do now:
  - Rule: "Not answered: LawEditor was closed while it waited. You can still add it in Laws."
  - Action: "The request was lost: LawEditor was closed while it waited. Ask again to run it."
  - Mode: "Not answered: LawEditor was closed. You can switch the mode under the message box."
- **A no answer doesn't flash green.** The answer's button turns green with a check for every answer (Bend-UI's `done()`, `.btn--async.is-done`), so Don't add and Don't allow look like yes for a moment. In the app: a no answer closes the question without `done()`. Better, in Bend-UI: a tone for `done()` with an x (neutral or warning, not danger: no is not an error). The owner's call.

## Larger: a question that outlives the server

What dies with the turn is not only the question but everything after it in `replied` (`engine/TURN.bend`): the next rules of the same reply, the mode offer, the laws to write, and the chat run again after a switch.

- **A. The question on screen stays answerable.** On start, a rule's or mode's question stays open, marked as having no turn behind it; its answer is done by the server itself (`add_sentence`, `Law.write`, the mode's setting). To decide: whether such a question still holds the message box (`EVENTS.can_say`). The laws of `HEAR.bend` must still hold. An action's question can't be kept: the CLI that asked is gone.
- **B. The turn resumes where it stopped.** The server reads the conversation again and does the rest of `replied`. A change at the heart of the engine.

Worth it only if the server restarts often (an automatic update, say). In normal use a restart with a question open is rare, and a lost rule can be added in Laws.

# Next: the artifact system (0.1.13)

Written on 2026-11-19. The owner wants her own artifacts, taking Claude's apart: a page (HTML, no server), the agent's tools, skills, types, capabilities, and the shell around the page, where the comment picker lives. Her complaints split in two: what Claude does but differently each time (fits the screen, shows every parameter, options beside Today, values that come back), and what it lacks (a debug mode with the spacings, picking a part to read it). The artifact "Ferramentas do Artefato" has the whole map.

Built in 0.1.13: the frame, and the tools that read any page (Comment, Measures, Inspect).

Still to decide or build, in the order I would take them (mine, not chosen):

- **Parameters from the code.** The page declares its parameters in a `.bend` file; the frame draws a panel from that list, so none can be left out, and the preview never leaves the screen. Needs a way for the frame to hand the values to the page (the probe can carry them).
- **Options.** The same declaration names Today and the options; the bar switches between them.
- **Values.** What was picked goes to the chat as an event of the conversation, not copied by hand.
- **The skill** (`ARTIFACT.md`): when the chat makes such a page, and how it fills the declaration.
- **Laws of the frame**, to propose: every declared parameter has a control; every option gives every parameter a value; an artifact uses the project's own code or says it doesn't. They need the owner's yes.
- **States** and **a lock per value**: tools for later.
- The name: "artifact" is Claude's word. Her own pages are often called Lab.

# Next: after the Bend pipeline (0.1.12)

Written on 2026-11-18, with 0.1.12. LawEditor is a harness for Bend: what it builds is Bend, built by Bend's own pipeline. What is still to decide or build.

## Laws to propose (none is in `LAWS.bend`: they need the owner's yes)

What 0.1.12 does is in Bend (`harness/POLICY.bend`, `engine/BUILD.bend`), but no law says it yet:

- **A `.bend` file is logic, and only logic is checked.** `P.layer_of("bend") == Logic`, and `P.layer_checked` is true for logic alone.
- **A file that isn't logic is never passed in silence.** `P.layer_note` is empty only for logic: the question before such a file is written always says no law checks it.
- **A turn that changed the project is checked by Bend before the person is asked anything else.** The order in `engine/TURN.bend` (`replied`): the reply, the check, then the laws heard.
- **A page is never served from the app's own address.** `server.bend`: the pages door.

## A law is only a claim until it is proved

Since 0.1.12 a law talks about the project's real code: it stops compiling when the definition it names goes away or changes its shape. But a law that compiles is an open claim (Bend counts it as a TODO), so code that changes what a definition *does* still breaks no law. Seen with Bend 2.0.40: a claim with no `for` is proved by `{==}`, and then a wrong value turns it red ("expected 2, observed 3"). The step after this one:

- The law agent writes the proof when the claim is settled by running it (`{==}`), in a `PROOF.bend` of the project, and the engine's check runs `bend PROOF.bend`.
- A law with `for` needs a real proof (cases, induction). A model can try; when it fails, the person must be told whether the law is false for this code or only not proved yet. That difference is the hard part.
- The check's line already counts them ("2 without a proof").

## What a project is made of: still open

- **Which files are glue is a list of endings** (`POLICY.glue_kinds`). A `.js` file is glue, and nothing but the chat's instructions keeps logic out of it. The one thing the system sees today: a page that imports no `.bend` file at all. A finer test (how much of a page is not drawing) is an idea, not a plan.
- **A program in another language is asked, not refused.** In Ask before changes every file is asked anyway; the question only says more. If it should be refused in some mode, that is a new rule in `GATE.rules()`.
- **The chat can't run `bend` without asking.** It reads the guide from `.laweditor/GUIDE.md` and the engine checks after its reply, giving it a turn to fix an error (at most three more turns per message). Letting `bend <file> --check-only` through the gate without a question would shorten that loop: it is a change to `GATE.rules()` and to what the chat's own list allows, both the owner's.
- **A program that opens a window** (`App.run`) only runs as a native binary, from a desktop session: the app has no button for it. The person runs `!bend main.bend` from the message box, or builds it in the terminal pane.
- **The page is bundled into `.laweditor/page`**, LawEditor's own folder, so nothing of the person's is overwritten. `bend index.html -o dist` is still theirs to run.
- **Old projects** made before 0.1.12 hold a `TYPES.bend` their laws import, and a `game/` folder with a lone HTML file. Their conversations open; the files are just files of the project now (`TYPES.bend` is code like any other). Nothing in the app reads those names anymore.

# Next: after the engine (0.1.11)

Written on 2026-11-17 and 2026-11-18, with 0.1.11. What is still to decide or build.

## Laws to propose (none is in `LAWS.bend`: they need the owner's yes)

The engine's rules are in Bend (`harness/EVENTS.bend`, `engine/TURN.bend`), but no law says them yet:

- **One question at a time in a conversation.** While a question waits, nothing else is asked and the person can't write (`EVENTS.can_say`).
- **A message is refused while the chat answers.** `say` answers "busy"; nothing is queued silently.
- **A conversation's events are only added to.** No event is changed or taken out; a window that has read n reads the ones after n.
- **A conversation stays in one project.** The project is named once; the folder's name changes, the conversation doesn't move.
- **A draft becomes a project only with a rule or a file.** Talking alone makes no project.
- **A command of the person's follows the mode.** Only read runs none.
- The two from 2026-11-12 (below) are still waiting too.

## A main chat that opens others

Not built. The artifact drew three options: chats side by side, led by you (built: the list with states); a main chat that leads helpers and reads their summaries (B); the chat proposes a sibling conversation with a card, and you decide (C). C fits the app (the chat proposes, the person decides) and needs only a new kind of question in `engine/TURN.bend` and a line the chat writes, like `PROJECT:`. B needs the questions of a helper to reach the person saying who asks: the hardest part to make trustworthy.

## The chat's composition

Built on 2026-11-18 from the artifact "LawEditor Chat Composition" (https://claude.ai/artifact/G3nS9UssNQ9ssxRHg24SdD): adjustment A (one ruler: a turn is rows of two columns, a mark and the text) and what C adds (the question in the message box's place; a finished reply folds its work). On the branch `chat-composition`, with Bend-UI 1.1.22 (`.turn`, `.ask`) on the lib's branch `harness-panes`. Not validated by the owner yet; the lib's pieces are in its docs page (Chat, A turn) to be looked at there.

Still to decide or do:

- B, a thread through the turn's marks, was left for later: it can come over the ruler as a style.
- The record of an answered question keeps no preview: the action's own row opens to what it wrote. If the code should stay in sight, the record can become a row that opens.
- Keyboard: the question takes the focus as a whole; Tab reaches its buttons. Number keys for the answers (as the terminals have) are not there.
- Not tested: a screen reader, Safari, Firefox.

## Found while driving a real conversation (2026-11-18), still open

- **A project with no `PROJECT:` line takes the start of the first message as its name** (a folder named `create-the-file-game-hello-txt-with-the`).
- The i-th answer is paired with the i-th action (`ASK.bend`): actions run at the same time could be paired wrongly.

The Laws view was tested with a document of 58,000 letters (702 sentences): it opens whole.

## Known limits

- Two conversations in the same project can change the same file. The references solve it with a copy of the folder per conversation (needs git). A simple first rule: warn when a second turn starts in a project where one is running.
- The terminal pane draws lines and colors (`TERM=dumb`), not a full screen. Its helper is `python3`; a pseudo-terminal in Bend itself would remove it.
- Open a folder… uses the computer's folder chooser: osascript on macOS, zenity or kdialog on Linux. With none of them it does nothing and says nothing; `laweditor here` works anywhere.
- A deleted conversation goes to `.laweditor/trash`; the app has no way to bring it back.
- A project's folder in the home keeps a simple name (letters, digits, "-"), as LawEditor names them; one renamed by hand with a space or a dot isn't listed. Open it with Open a folder… instead.
- The server's guard (Origin, Host) is tested by hand, not proved.

# Next: the chat asks Bend before it acts (0.1.8)

Decided on 2026-11-12 with the repo owner. Built in 0.1.8 (2026-11-16); the laws below are still to add. The flows are in `PERMIT.bend`; `bend DIAGRAMS.bend` draws them.

## The bug (0.1.7)

A command made of parts (`sed … | sed … > /tmp/x.js && node --check /tmp/x.js && echo OK`) asks forever. The person allows it; `ASK.bend` adds the whole line to Claude's list (`Bash(<whole command>)`); Claude's CLI checks each part alone, finds none on the list, and refuses again. Seen in every project. Reproduced outside the app with Claude Code 2.1.322.

## The decision: Bend decides, the CLI obeys

Two fixes were drawn (`PERMIT.list()`, `PERMIT.ask_bend()`):

- **A, write the list right**: cut the command into parts as Claude does and add one line per part. Bend would have to copy how each CLI reads its list (Codex has no list per command), and the loop comes back the day the CLI cuts differently.
- **B, the CLI asks Bend** (chosen): before an action that isn't on its list, Claude asks our server and waits. Bend gets the whole action, decides with `POLICY.bend` and the laws, and asks the person only when it must. No retry, no `--resume`. A model that runs locally fits the same flow, with no CLI in between: the harness runs the tool itself.

## What the three references do

All three stop the agent, hand the whole action to the harness, and wait for allow, allow always or deny.

- **Claude Code**: `--permission-prompt-tool` (an MCP tool) answers `{"behavior":"allow"}` or `{"behavior":"deny","message":…}`; Claude waits with no time limit. Deny rules are checked first, so the tool is never asked about them. ([CLI](https://code.claude.com/docs/en/cli-reference), [order of checks](https://code.claude.com/docs/en/agent-sdk/permissions#how-permissions-are-evaluated), [compound commands](https://code.claude.com/docs/en/permissions#compound-commands))
- **Codex**: only its `app-server` asks a client (`item/commandExecution/requestApproval`, answered `accept`, `acceptForSession`, `decline` or `cancel`). `codex exec`, which LawEditor runs today, asks no one. ([app-server](https://learn.chatgpt.com/docs/app-server), [approvals](https://learn.chatgpt.com/docs/agent-approvals-security))
- **Hermes Agent**: the harness runs the tools and decides itself: allow once, allow always, deny. No answer in 300 s means deny. It also cuts commands into parts for its deny list and says that is "not a complete shell interpreter". ([security](https://github.com/NousResearch/hermes-agent/blob/main/website/docs/user-guide/security.md), [approval.py](https://github.com/NousResearch/hermes-agent/blob/main/tools/approval.py))

## Tested on 2026-11-12 (outside the app, Claude Code 2.1.322)

- Claude asked a small outside tool, waited 5 s for its answer, and got the **whole** command (`tool_name`, `input`, `tool_use_id`).
- Allow: the command ran once. Deny: it didn't run, and the chat didn't retry.
- `--disallowedTools Edit(LAWS.bend)` won: Claude refused by itself and never asked the tool. (With a rule written in the wrong path form, the edit went through and nothing warned: the list is not a guard, Bend is.)
- The tool works over plain HTTP (`"type": "http"`), with plain JSON answers. So `server.bend` itself can be the interphone; Bend doesn't need to read stdin.

## The pieces

1. **`server.bend` answers `POST /mcp`**: the MCP calls (`initialize`, `tools/list`, `tools/call`). A `tools/call` puts the question where the page can see it and waits for the answer. The compiled server already answers other requests while one waits (since 0.1.3).
2. **Bend decides** (`ASK.bend`, `POLICY.bend`): allowed already in this session or always, so yes; a law forbids it, so no; otherwise, ask the person. It waits for the answer with no time limit, as Claude does.
3. **The page asks during the turn**: the card shows while the chat is still working, and the answer goes back to the waiting call.
4. **Claude runs with** `--permission-prompts host --permission-prompt-tool …` and an MCP config naming the server, instead of `--permission-prompts none` and `--resume`.
5. **Codex comes later**: it needs `codex app-server` instead of `codex exec`.

## Open questions

- **How the waiting call hears the answer**: a file it reads every few hundred ms (as `/api/progress` does), or a channel between the two requests. Leaning to the file: it already works.

## Decided with the repo owner (2026-11-12)

- **No time limit**: the card waits for the person, as Claude does. A setting for "no answer after X minutes means no" (Hermes uses 300 s) is a later idea, not 0.1.8.
- **Laws to add** (`LAWS.bend`, proved in `PROOF.bend`):
  - **An answer covers exactly what was answered.** Allow: this once. Allow for session: the same action, exactly, until the conversation ends. Always allow: the same action, exactly, in this project only. And the same action is never asked twice in a row: the bug can't come back. ("Never asked again", said loosely, would have made Allow mean Always, crossed projects, and let one `rm` stand for another.)
  - **The chat is refused on `LAWS.bend` before the person is asked.** Only the chat: the law agent, which writes the laws after Add, runs with its own tools (`law_agent_claude`) and doesn't go through the interphone.
- **Two buttons, named truly**: Allow and "Allow for this session" (today's "Always allow" only lasts until the page reloads). The law speaks of those two. A real "always, in this project" is a later idea.
- **Dropped**: "no answer means no" (there's no time limit).

## Built so far

- **Piece 1, the interphone** (`GATE.bend`, `server.bend`: `POST /mcp/<turn>`), tested alone on 2026-11-12: Claude 2.1.322 connected to the compiled server, asked with the whole command, waited for the answer file; allow ran it once, deny didn't, no retry. While a call waits, the server still answers the page. Nothing calls it from the app yet.
- **Piece 2, the gate decides** (`GATE.rules()`, `decide()`, `flow()`, `tried()`), 2026-11-16.
- **Piece 3, the card during the turn** (`GET /api/question/<turn>`, `POST /api/answer/<turn>`, the session file per conversation), 2026-11-16.
- **Piece 4, Claude asks the gate** (`--permission-prompts host`, `--permission-prompt-tool mcp__laweditor__approve`, `--mcp-config`), 2026-11-16. Tested in the app. `--safe-mode` turns off MCP, so the chat that asks is isolated by `Policy.claude_isolation_asking()`.
- **Found while building**: `run_to` stops Claude after 600 s (10 min), so "no time limit" needs that raised for the chat (piece 4). One question at a time per turn: two calls at once would overwrite each other's file.
