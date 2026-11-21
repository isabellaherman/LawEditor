# Changelog

Versions stay at 0.x until the MVP. Each iteration raises the last digit.

## Next

What the person asked for, as goals. Each one becomes an iteration when it's picked.

- The chat answers fast.
- A law is proved, not only stated: code that breaks a rule turns red (NEXT.md: a law is only a claim until it is proved).
- The chat proposes only sentences that are rules.
- Codex asks before changes too.
- Codex's answer comes without its own notice ("Reading additional input from stdin...").
- When a project is done, the chat shows a link that opens its folder on the computer.
- A main chat that opens other chats (NEXT.md: options B and C).

## 0.1.14 (2026-11-21, not validated by the owner yet)

Skills and timers: the chat keeps your way of doing a thing, and comes back by itself to do it. The model, as the owner put it: the harness gives **resources** that don't know what they are for (the clock is one), and a **skill** is the person's own orientation for using them in one context. The flow follows Grok Bot's skills and routines (https://docs.x.ai/grok-bot/skills-routines-and-automations): do the task once, save the way as a skill, then put it on a schedule. From the artifacts "Relógio do harness" (https://claude.ai/artifact/8TyCwbaCNidwTLhiiVFV81) and "Recurso e skill" (https://claude.ai/artifact/F2VoBW12JbWLyiUS5fuLKF).

**Skills** (`harness/SKILL.bend`, `harness/SKILL.md`)

- **You ask, the chat writes, you read, the engine saves.** "Save that as a skill called Count the notes": the chat ends its reply with the skill, every line marked (`SKILL: "name"`, then `SKILL|` lines). The question shows its whole text in the message box's place: Save skill, or Don't save. A name that is already a skill asks to replace it. The chat still only reads: the engine writes the file.
- **A skill is a file of the project**: `.laweditor/skills/<name>.md`, plain text you can open and change.
- **The chat knows the project's skills.** Each turn it is told their names and files, and reads a skill's file before using it, when you name it or a timer does.
- **Chat › Context** shows `SKILL.md` as it is.

**Timers** (`harness/TIMER.bend`, `harness/TIMER.md`, `engine/CLOCK.bend`)

- **The chat asks for a timer** with one line, and you answer Set timer or Don't set, with when and what it will do shown. Three kinds: on days at a time of day (`weekdays 10:00`, `mon,thu 10:30`, `daily`, `weekends`), after a span (`every 4h`), or once (`in 30m`). A time of day is this computer's own: the engine asks `date` how far its clock is from the world's, at every look.
- **The server keeps the clock.** Every 30 seconds it looks at every project's timers; a look calls no model. A timer that came due starts a turn in the conversation that set it, with the same AI, model and mode: a new event, `timer`, which every window shows as the turn's first line and the chat reads as the app speaking. A conversation that is busy is tried again at the next look; one that was deleted takes its timers with it.
- **Its first turn is at its next time**, never when it is set. `laweditor timers test <n>` starts one now, and leaves its time as it was.
- **It goes on until you say.** `laweditor timers` lists them; `pause <n>`, `resume <n>` and `stop <n>` do the rest. A paused timer is kept and never comes due. (A first draft ended every timer after 7 days, as Claude Code does: wrong for a standing job, and gone.)
- **Timers are files** (`.laweditor/timers/`, one each), and the time is the computer's calendar: Bend's own `IO.now` counts from when the program started, so it can't outlive a restart.
- **The limits, in one file**: 20 per project; a span from 1 minute to 30 days; a turn a timer started sets none; after a turn, the next time is counted from now, so the hours a computer slept through start one turn.
- **Always on** (`service.sh install`): launchd on macOS, systemd on Linux keeps the server running from login, and starts it again if it stops.

**Tested**, on a server of its own built in a folder apart, with a real chat (Claude, Only read):

- The whole path: a task ("count the lines in NOTES.md"), then "save that as a skill called Count the notes" (the question showed the text; Save skill wrote the file), then "run that skill every weekday at 10:00" (the timer was kept for Monday 10:00, asked on a Saturday), then `timers test 1` (a turn started at once, read the skill and answered as the first time; the timer's time didn't move).
- `timers pause`, `resume`, `stop`, and a number that isn't there. A weekday timer two hours late, beside a paused one whose time had passed: the clock started one turn, kept the late one for Monday 10:00, and left the paused one alone.
- The page, in a browser driven by script: the skill question with its text, the timer question, a timer's turn, `SKILL.md` and `TIMER.md` in Context; no error in the console.
- The rules on sample values: days and times (weekdays, mon,thu, daily, weekends, a zone ahead of the world's clock and one behind), lines that aren't timers, a late timer, pause and resume; two skills in one reply, a heading with no name, the text a person reads.
- Earlier, before days and pause: a timer once in a minute, one whose conversation was gone, the most of 20, a server restarted with timers kept.
- `bun run check` passes.

**Not tested**: `service.sh` on any computer; a timer in Ask before changes, whose action waits for a yes with nobody there; Codex; a computer that really slept; summer time changing; two timers of one conversation due at the same look (the second waits for the next); replacing a skill with a real chat.

**Not yet**: the skills and the timers in the app (a list, pause, test: they need a design first); skills shared by every project; the chat suggesting a skill or a timer by itself, beyond what `SKILL.md` asks of it; a check that runs before the model is called, so a timer with nothing new costs nothing; an answer that stays silent; a timer started by something that happens (a message, a build) and not by the clock; a notice outside the app; the other resources (a browser, accounts of the agent's own); the laws of `TIMER.bend` and `SKILL.bend` (NEXT.md); the computer in the cloud.

## 0.1.13 (2026-11-19, not validated by the owner yet)

On Bend-UI 1.1.29 (the inspect extension). The first piece of the artifact system: the frame, and the three tools that need nothing from the chat. From the "Ferramentas do Artefato" artifact (https://claude.ai/artifact/WxbKa5dA3bCtNTKhCYsz4j), with the tools on the bar (its option A).

- **The page opens beside the chat**, in a pane (the eye in the toolbar; "Open the page" in a reply). Before, it opened in a tab of its own; that is still there, as a button on the pane's bar. A page Bend bundles again shows again by itself.
- **Three tools on the pane's bar** (`harness/INSPECT.bend` says which, and what each does). None needs the chat to write anything: they read the page as it is drawn, so they are the same on every page.
  - **Measures**: every padding, margin and gap of the page, drawn over it with its number.
  - **Inspect**: click a part and read its values under the page, each space and corner with its name on the scale (`space_4`, `radius_md`) or "off the scale". The click does nothing else to the page.
  - **Comment**: click a part and a pin marks it; the message box starts with what it points at (`On the page, at button.btn ("Later"): `), and you write the rest. Sent, the pin stays, numbered. `CHAT.md` tells the chat what such a message means.
- **How the app reads a page it can't touch.** A project's page is served from another address (the pages door), so the app can't read it. A page asked for with `?inspect` comes with the probe (`engine/probe.js`): it reads the page's boxes and tells the frame, and the app draws them with Bend-UI's inspect. Only the app's frame asks for it: in a tab of its own the page is exactly what Bend bundled. What the probe sends is kept to numbers and short texts.
- **Tested**, in a browser driven by script, on a server of its own with a small Bend project: the pane opens on the project's page; with no tool on the page works as usual; Measures shows the page's own numbers (padding 16 and 24, gap 12 and 8, margin 20) exactly over it, and follows a scroll; Inspect reads a button without pressing it and names what is on the scale; Comment starts the message, moves with a second click keeping what was written, and keeps its pin when sent; a page bundled again shows again; light, dark, 1280 and 520 wide. `bun run check` passes.
- **Not tested**: with a real AI (a comment sent to Claude, and its answer); a page the chat itself built; the four older suites; a page with thousands of parts (the probe measures the first 1,500 in sight); Safari, Firefox, a screen reader.
- **Not yet**: Parameters, Options and Values (the tools that need the page to declare a list), the skill that tells the chat how to make such a page, and the laws of the frame. A pin is lost when the page is shown again. The tools have no keyboard way to pick a part.

## 0.1.12 (2026-11-18)

Run and approved by the owner on 2026-11-18. LawEditor began as an editor of laws for game design and is now a harness for Bend. This version takes what was left of the first idea out of what runs, and makes what the chat builds go through Bend's own pipeline.

- **What the chat builds is Bend.** Before, the chat was told to put "pages, scripts, images" in a `game/` folder: every project it built was one HTML file with JavaScript inside and no line of Bend, while its laws checked a stand-in the law agent kept in `TYPES.bend`. The built thing and its laws never met. Now `CHAT.md` says what a project is made of (logic in `.bend` files, glue around it) and how Bend builds it: `main.bend` for a program, `index.html` importing the `.bend` files for a page.
- **The laws talk about the project's own code.** `TYPES.bend` is gone: `LAWS.bend` imports the project's `.bend` files, and the law agent states a law about the definitions that are there. When the code has nothing yet that a rule talks about, it adds the smallest definition to the code itself, and the chat builds on it (`AGENT.md`). A turn of the chat waits while a law is being written, so the two never write the same file at once.
- **Bend checks every reply that changed the project** (`engine/BUILD.bend`). After a reply that edited a file, wrote one or ran a command, the engine runs `bend <file> --check-only` on each `.bend` file and bundles the page with `bend index.html -o …`. The conversation keeps what Bend answered (two new events, `check` and `page`) and every window shows it: the files checked and how many claims wait for a proof, or the error as Bend gave it. With an error, the chat reads it and gets a turn to fix it, at most three more per message. A page that imports no `.bend` file is bundled and flagged: its logic is outside Bend.
- **Three layers, in one list** (`harness/POLICY.bend`: `Layer`, `logic_kinds`, `glue_kinds`). Logic is `.bend`. Glue is what goes around it (a command in shell, a setting, a text, an image, the page that draws) and holds no rule. Anything else is a program in another language: not what LawEditor builds. Nothing is forbidden by this list: the question before the chat writes a file that isn't Bend says no law checks it, the file's name in "files changed" carries a tag (not checked, not Bend), and the chat is told to say that it builds in Bend before writing another language. To move a kind of file from one layer to another, change the list.
- **Open the page.** What Bend bundled is kept in the project's `.laweditor/page` and served at a second address, the pages door (the port plus 1000, `LAWEDITOR_PAGES_PORT`). A page a chat wrote is another site to the browser, so the app refuses what it sends.
- **Bend's guide, where the chat can read it.** Each turn writes what `bend guide` prints to the project's `.laweditor/GUIDE.md`: the chat reads it in any mode, with no command to allow.
- **A project, not a game.** `GDD.md` is `RULES.md`; the chat names the project with a `PROJECT:` line; the conversation's event is `project`; the side bar renames the project. The examples the chat and the law agent are given are about programs, not games.
- **No default files.** A new project's folder holds nothing but `.laweditor/`: `RULES.md` appears with the first rule, `LAWS.bend` with the first law, the code when it is written. A folder opened from elsewhere gets no file of LawEditor's beside its own.
- **Gone**: the `game/` folder, `TYPES.bend` and its panel in Laws › Files, `GDD.md`, the `GAME:` line and the `game` event, and the design note "the game follows the laws (0.2.0)" in `NEXT.md` (it chose "another language named: build in it, laws off"; this version replaces that).
- **Projects made before** keep working after one pass of a small script, run once on the home of the projects: `GDD.md` is renamed, the conversations' `game` events and `GAME:` lines are renamed, and each `game/` folder goes to the computer's trash. Their `TYPES.bend` stays, as code their laws import.
- **Tested**: with Claude itself, on a server of its own (another port, another home): asked for a counter in the browser, it wrote `main.bend` (the count, a click, the label) and an `index.html` that imports it and only draws; the gate's question for the page said no law checks it; Bend checked and bundled; the two rules it heard became laws about `main.bend`'s own definitions; the page opened at the pages door and counted. Asked in Only read for a shopping cart with two rules, it proposed five; the law agent wrote their laws and the definitions they need in `main.bend`, the chat waited for it, switched mode, added only `main` on top of those definitions, and `bend main.bend` printed the total. A copy of the owner's projects, after the one-time script, opened whole (conversations, rules, laws). The terminal window prints the check and the page's address. With a stand-in AI: a `.bend` file with a type error was caught, the chat got its turn and the next check passed; a page with its script inside was flagged; a Python file was tagged. A page served at the pages door could not read the app's address nor post to it (403). `bun run check` passes.
- **Not yet**: a law is still an open claim, not a proof, so code that changes what a definition does breaks no law (NEXT.md). Which files are glue is a list of endings: nothing but the chat's instructions keeps logic out of a `.js` file. A program that opens a window has no button in the app. No law covers the layers or the check (NEXT.md lists the ones to propose). Not tested: Codex, a screen reader, Safari, Firefox, a project opened from another folder.

## 0.1.11 (2026-11-18)

On Bend-UI 1.1.22. From the options approved in the "LawEditor Harness Options" artifact and the adjustments of the "LawEditor Chat Composition" artifact. The owner ran it and approved it on 2026-11-18.

- **The chat's composition** (2026-11-18, from the "LawEditor Chat Composition" artifact, adjustments A and C, on Bend-UI 1.1.22). The chat's pieces were each approved alone and stacked without relating: in a finished reply the text started at seven different places. Now a reply and what comes of it is one turn on one ruler (`.turn`: rows of two columns, a mark and the text): the plan always first, each action a row that opens, what it does now, its words, one closing line with the files changed and the folder. A finished reply folds its work into one line. A question takes the message box's place (`.ask`) and the turn keeps one line of what was answered; the rules heard are a group under the reply. A stopped reply says so inside its turn. `web/chat/messages.js` draws turns; `web/chat/composer.js` holds the question.
- **A refused action no longer counts.** `ASK.bend` reads which actions did not run (Claude marks their answer `is_error`): such an action says "not run" and its file is not in "files changed". Before, refusing an edit still showed "Done. 1 file changed".
- **Fixed on 2026-11-18, found by driving a real conversation.** A permission question waits as long as the person takes (Claude gave up after about a minute, so nothing was written for someone who read the change first). The page no longer breaks on a long conversation: it read the conversation with Bend functions that run out of room in a browser after about 6,000 letters, so a permission question holding a whole file stopped it; the server now says what goes on (`/api/c/<key>/<conversation>/now`) and the page reads the events itself. When the server starts, it closes the questions and the turn it left open when it stopped.
- **One engine, and windows on it.** The conversation lives in the server: `engine/TURN.bend` conducts a turn (the AI, each law it heard, the mode it offers, the gate's questions, the laws written) and keeps every step as an event (`harness/EVENTS.bend`). The page only sends what you wrote or answered and draws the events. Before, the page kept the conversation and conducted the turn, so nothing else could use the app.
- **No current project.** `projects/.current` is gone: every request names its project and its conversation. Any number of conversations and windows go at once. This also ends a leak seen in 0.1.10: a new conversation inherited another game's sentences, because the Laws page kept the document in memory and wrote it into whatever project was "current".
- **Your projects live in `~/LawEditor`**, out of LawEditor's own folder (`LAWEDITOR_HOME`, `LAWEDITOR_PORT`). The first start copies the ones 0.1.10 kept in `projects/`; conversations kept as `Person:` / `Agent:` lines open as before. A game's folder takes the game's name when the game is born (`fox-run`, not the conversation's id).
- **Any folder of the computer can be a project**, where it is (Open a folder… under the message box, with the computer's own folder chooser on macOS; `laweditor here` in a terminal).
- **The side bar lists every conversation with its state**: a dot while the chat works, another while it waits for you, and the game's name. Its menu renames the game, opens its folder, or deletes the conversation (to the project's `.laweditor/trash`). You can start another conversation while one works.
- **The place button under the message box** says New project and nothing has to be picked; its menu puts a new conversation in a game that exists or in a folder of the computer.
- **LawEditor in the terminal**: `laweditor` (`cli.bend`, `bun run cli`) is a second window on the same engine. A question is answered with its letter; `/new`, `/list`, `/open <n>`, `/mode`, `/quit`.
- **A command of your own**: a message that starts with `!` runs in the project's folder, and the chat reads what it printed. A mode that only reads runs none.
- **The project's files, in a pane beside the chat** (Bend-UI's panes: tree, pane): what the chat changed is marked, a file opens there read only, and a file's name in a reply's "files changed" opens it.
- **A real terminal in the app**, in a pane under the chat: your own shell, in the project's folder. A few lines of `python3` hold the pseudo-terminal, since Bend runs a program and waits for it to end. The chat neither sees it nor types in it.
- **Compact view**: the chat and the terminal, with a line of state on top (the game, how many conversations work, how many wait for you).
- **The server only answers its own windows**: a request another site's page sends, or one not addressed to the server by its own name, is refused. It runs commands, so this matters.
- **The house in order**: `engine/` (what runs), `harness/` (the rules the chat follows and what the AIs are told), `flows/` (the drawings). `LAWS.bend` only changed its import paths.
- **Legacy gone**: `.detail` in place of `.meta`; what is only read has no hover (the laws list, the law beside a sentence); the faces in the chat only look; the key-chosen item of the `/` and `@` list shows; Files and Context in Laws show when they are on; code in replies is colored; the page's own side bar toggle, `title_of` and `is_start` are gone.
- **Tested**: with a stand-in AI, in a browser driven by script: a law asked, added, written and checked; a game born and named; the mode offered and switched; three conversations at once in different states; stop; an old conversation opened whole; the Laws page showing only its own project; the files pane; a command in each mode; the real shell (typed, closed, opened again, ended); the compact view. With Claude itself: one turn in Ask before changes, where the gate asked twice and the file was written. Other sites' requests answered 403.
- **Kept on purpose**: `btn--ghost` and `btn--primary`. The lib calls them older names of `btn--plain btn--neutral` and `btn--filled`, but two of its rules exist only under the old ones (the current item of a side bar, the toolbar's main button), so renaming loses them. To settle in Bend-UI.
- **Not yet**: no law covers the engine (NEXT.md lists the ones to propose). Two conversations in the same project can change the same file. The terminal draws lines and colors, not a full screen (no editor like vim), and needs `python3`. The folder chooser is macOS only (elsewhere: `laweditor here`). A deleted conversation has no way back in the app (its files are in `.laweditor/trash`). Codex still can't ask.

## 0.1.9 (2026-11-17)

- **Allowed in this chat, in the mode's menu.** In a mode that asks, the mode button carries the count ("Ask before changes · 3 allowed"), and its menu shows what the person allowed for this conversation: newest first, each row with its kind (Run, Edit, Write) and the exact action, a Find… field, × to take one back and "Stop allowing all". The list shows 8 rows and scrolls inside the menu (Bend-UI 1.1.10's menu with a list). Anything else still asks.
- **Bend decides what the menu shows** (`GATE.bend`, `allowed_*`): the list read from the session file, the count, each row's kind, tone and text, finding, and taking back one action or all of them. `server.bend` answers `GET /api/allowed/<conversation>` and `POST /api/allowed/<conversation>` (body: the action, or `all`).
- **Bend-UI 1.0.3 → 1.1.10.** Follow is gone from the lib (1.0.16), so the laws screen no longer scrolls along while laws are generated. Tones and dots use the lib's new names (success, warning, danger); nothing looks different.
- **Tested in the app**: Allow for this session put "1 allowed" on the button and the row in the menu; × took it back, and the same command asked again.
- **Not yet**: chat replies are shown as plain text, not Markdown. The two laws decided on 2026-11-12 are still not in `LAWS.bend`.

## 0.1.8 (2026-11-16)

- **The chat asks Bend before it acts, and the endless question is gone.** In Ask before changes, Claude no longer checks its own list and retries: before an action that isn't on it, it asks LawEditor's interphone (`GATE.bend`, `POST /mcp/<conversation>/<turn>`, `--permission-prompt-tool`) with the whole action and waits, with no time limit. A command made of parts (`touch hello.txt; ls | tr a-z A-Z`) is asked once and runs once.
- **The gate's rules are one list that runs and draws itself** (`GATE.rules()`): a law forbids it (the chat changing `LAWS.bend`, by edit or by any command naming it), the mode forbids it (Only read: anything but reading), allowed for this session already (the same action, exactly), otherwise ask. `GATE.decide()` runs the list, `GATE.flow()` draws it, and `GATE.tried()` runs it on six actions and groups them by answer: the diagrams "Permission: the gate decides" and "Permission: the gate, tried".
- **The card shows during the turn**: Allow (this once), Allow for this session (kept on the server for this conversation, until the page reloads), Don't allow. When a rule refuses, the chat is told why, so it doesn't try another way.
- **Isolation for the chat that asks**: `--safe-mode` turns off MCP servers, the interphone included, so this chat runs with `Policy.claude_isolation_asking()`: none of the person's settings files (permission rules, hooks, plugins), no MCP server but LawEditor's, no skills or commands. A `CLAUDE.md` in the project folder and Claude's own memory for that folder are no longer kept out. Only read keeps `--safe-mode`.
- **Removed**: the retry flow (`/api/allow`, `--resume`, "Always allow").
- **Tested in the app**: the card came during the reply; Allow for this session ran the command once; the same command again ran without asking.
- **Not yet**: the two laws decided on 2026-11-12 (an answer covers exactly what was answered; the chat is refused on `LAWS.bend` before the person is asked) are in the gate's code, not yet in `LAWS.bend`. Codex still can't ask.

## 0.1.7 (2026-11-12)

- **The harness, drawn from its own code.** `ARCH.bend` is the harness as it is today, as a `FLOW.bend` flow (who acts where); the words for modes, flags and tools are read from `POLICY.bend`, so they follow the code. `DIAGRAMS.bend` turns `HEAR.flow()`, `OFFER.flow()` and `ARCH.flow()` into Mermaid text (`bend DIAGRAMS.bend` prints them; with a URL it sends the ones that changed, from a clean commit only). Each diagram's top node names the commit it came from.
- **A legend for who acts** (`FLOW.who_means`): Person, Skill and System each say what they are, and the diagrams draw their legend from it.
- **Known:** unstable, with bugs not yet listed. This version saves the state as it is before the next round of fixes.

## 0.1.6 (2026-11-11)

- **The chat proposes laws again, also the ones nobody said.** Since 0.1.4 each mode told the chat what to do with a request to build, and the chat did that and dropped its LAW: lines. Now every mode carries one more line, `Policy.still_hears()`, added in `mode_section` so no mode can leave it out; the Switch message (`OFFER.told()`) says it too.
- **Where the rules are** (`HEAR.md`): most rules are never said. The chat looks in what the person says, in what their words take for granted ("a top-down shooter": the player moves in four directions), and in what it decided while building (one shot kills an enemy). Each becomes a proposal: Add, Always add or Don't add. At most five per reply, the most important first. `HEAR.flow()` names the step that way.
- **Tested** with "quero um top down shooter", which states no rule: Only read proposed 3 laws, Ask before changes 5 laws of the game it planned. A rule added from the chat got its law from the law agent, and Bend accepted it.

## 0.1.5 (2026-11-08)

- **Debug screen** (side bar › Debug, to remove later): LawEditor's own `LAWS.bend`, exactly as the file is, and the output of `bend PROOF.bend`, run by the server each time the screen opens (`GET /api/debug/LAWS.bend`, `GET /api/debug/check`). Nothing on it is typed by hand: a law added, changed or removed shows there as it is, and a law that fails shows Bend's own error.

## 0.1.4 (2026-11-07)

- **The chat offers the mode** (`OFFER.bend`, flow A of the four drawn on 2026-11-07). In Only read, when the person wants something built, the chat ends its reply with `MODE: "Ask before changes"`; the page asks Switch / Stay. Switch moves the picker and sends the request again; in Ask before changes the chat writes the smallest version to play first, says how to open it, and asks one question. Stay keeps Only read.
- **The flow is the source, and it is checked.** `OFFER.flow()` is drawn in Chat › Context by Bend-UI's diagram. New laws (`LAWS.bend`, proved in `PROOF.bend`): `offer_flow_is_whole`, `offer_flow_skill_then_system`, `offer_flow_writes_need_you`, `stay_keeps_only_read`, `switch_asks_first`, `reply_hides_offer`.
- **Validated in the app against the diagram**, "quero um jogo de plataforma so andar pro lado":

  | Step | Seen |
  |---|---|
  | You ask for something to be built | Sent in Only read |
  | The chat ends its reply with MODE: | Yes, with a rule (first try missed it: "I want a game" read as a description; the Only read text now says wanting a game means building it) |
  | Switch to Ask before changes? | Card shown, talk stopped |
  | The picker moves; the request goes again | Picker on Ask before changes; a new reply started |
  | The chat writes the smallest version | `plataforma.html` (canvas, arrows or A/D) |
  | Claude refused, question | Allow card with the file |
  | Write it; how to open it; one question | Written; "clique duplo nele"; one question about the screen edge |
  | Stay, Don't allow | Not clicked in this run (Stay is proved by `stay_keeps_only_read`) |

- **Known:** the Allow card shows the whole file, so a game makes it long. The offer card and a rule card can wait at the same time, and answering one frees the message field. The first answer took about 30 s (the chat reads the project first).

## 0.1.3 (2026-11-07)

- **The chat shows its answer while it writes it** (Claude). Claude runs with `--include-partial-messages` and its output goes to a file for the turn (`/tmp/laweditor-turn-<id>.jsonl`; the id keeps only letters and digits). The page asks `GET /api/progress/<id>` every 300 ms and draws the text so far; `ASK.bend` reads it (the message being written now). Codex still answers all at once. Measured: the first words show about 3 s after sending, instead of the whole answer at the end.
- **The server runs compiled** (`bun run start` builds `dist/laweditor-server`). Run as `bend server.bend`, Bend waits for a program to finish before it answers anything else, so the page couldn't ask for the answer so far; the compiled server answers while Claude works.

## 0.1.2 (2026-11-07)

- **The chat builds, and says how.** `CHAT.md` says the chat helps build the project as far as its mode allows, and hears its rules. In Only read, asked to build or change something, it says it can once the person picks Ask before changes (as Claude Code does when a mode blocks it), never that it isn't its job. Tested: "cria um jogo da velha que é impossivel perder e tem grafico de gameboy" in Only read now answers "Posso criar o jogo quando você escolher Ask before changes".
- **The chat runs apart from the person's own Claude Code** (`--safe-mode`, `Policy.claude_isolation`): their CLAUDE.md, plugins, hooks and memory don't reach it, and it starts in about half the time (a bare "oi": about 5.4 s before, 2.4 s now). Asking, Allow and the LAWS.bend refusal work the same.
- Not the cause: the person's connectors (Gmail, Drive…) never load in the chat.

## 0.1.1 (2026-11-07)

- **Fix: Allow didn't let the chat write a file.** Two causes, both in `ASK.bend`. (1) A new or rewritten file comes from Claude's Write tool, and the app allowed it as `Write(//path)`; Claude doesn't take that rule, so Write stayed refused. Claude's file rules are all `Edit(…)`, which covers Write: the grant is now always `Edit(//path)`. (2) Claude's refusal tells it "don't retry, it will be refused for the rest of this session"; told only "Go ahead", it gave up after a few tries. The resume now says what was allowed and that the earlier refusal no longer applies. Tested in the app: "Create a new file TEST.md", Allow, the file is written. The question for Write says "write", not "create" (it may be an existing file).
- **The version** shows at the window's bottom-right (a `tag`, from `package.json`); "Made with Bend-UI" stays alone at the left. Bend-UI 1.0.3 (`.window__foot--end`).
- **The chat knows what a rule is** (`HEAR.md`): one fact that can be checked. "What exists or what someone can do", two things in one sentence, and vague words are not rules yet. With something vague, the chat proposes its clear meaning, or asks one plain question with options and waits. Tested: "eu quero criar um jogo 2D onde eu ando e atiro" gave "Quando o jogador anda, a posição dele muda" (its law compiles) and a question about shooting; the answer "aparece uma bala e a munição diminui" gave two rules.
- **Known issue:** the chat can still propose a sentence that isn't a rule. The skill is a prompt, not a check, so it improves the odds but doesn't guarantee it. When it happens, the law agent refuses the sentence and says why; nothing invalid is written. Seen again on 2026-11-07, after the fix.

## 0.1.0 (2026-11-07)

The chat and the laws talk.

- **The chat hears rules** (`HEAR.md`, `HEAR.bend`): it ends its reply with the rules it heard; each becomes a question (Add, Always add, Don't add), and an added sentence gets its law.
- **The chat's modes** (`POLICY.bend`, `HARNESS.md`), picked under the message field:
  - **Only read**, the start: it reads and changes nothing.
  - **Ask before changes**, Claude only (`ASK.bend`): what it isn't allowed is refused and turned into a question (Allow, Always allow, Don't allow); the same conversation goes on with what the person allowed.
  - `LAWS.bend` is refused in every mode.
- Chat › Context shows `HARNESS.md`: what the chat may do in each mode, and when it asks.
- Bend 2.0.40 added `Tool` to Base, so the policy's types are `AgentTool` and `Agent`, with qualified constructors.
- **Known:** Codex can't ask yet (Ask before changes is off with Codex). The version in the window's bottom-right waits for a footer slot in Bend-UI.
