# LawEditor

A harness for [Bend](https://github.com/bendlang/bend): talk with an agent that builds your project in Bend, and turn what you mean into **laws** the Bend compiler checks.

- **It builds Bend, with Bend's own pipeline.** A project's logic is `.bend` files; around it goes glue (a command in shell, a setting, the page that draws what Bend returns), which holds no rule. After each reply that changes the project, Bend checks it and bundles its page, and the conversation shows what Bend said. A program in another language is not what it builds: it says so, and you decide.
- **Chat**: talk with Claude or Codex about your project. What it may do is the mode you pick: only read, or ask you before each change.
  When you state a rule in the talk ("a new list starts with no task"), the chat proposes it as a sentence; you answer Add, Always add (this conversation) or Don't add. An added sentence goes to the document and its law is written and checked, as with Generate.
- **Skills**: your own way of doing a thing, kept so you don't repeat it. Do a task with the chat, say "save that as a skill", read what it wrote and answer Save skill. Next time you name it, and the chat follows it.
- **Timers**: the chat comes back by itself. Ask for something later or again and again ("run that skill every weekday at ten"), and it proposes a timer; you answer Set timer or Don't set. The server keeps the clock and calls the chat when the time comes. A skill says how, a timer says when.
- **Laws**: write a rule in a plain sentence; the agent writes it as a Bend law, and Bend checks it.
- **One engine, several windows**: the page and the terminal (`laweditor`) show the same conversations. Any number of them go at once, each in its own project.

Everything is Bend: the server (`server.bend`), the engine (`engine/`), the rules the chat follows (`harness/`), the terminal (`cli.bend`), the editor's own rules (`LAWS.bend`), and the look ([Bend-UI](https://github.com/isabellaherman/Bend-UI), whose rules are laws too). JS only reads input and draws.

## What is checked

Nothing here asks to be trusted. Each claim below is checked by the Bend compiler, or enforced by a tool.

| Claim | How |
|---|---|
| A law you write compiles, against your project's own code | `LAWS.bend` imports the project's `.bend` files: there is no stand-in. `bend LAWS.bend --check-only`, run by the agent and again by the server. Red when it doesn't, with the reason. A law that compiles is a claim: it holds for sure only once it has a proof, and the agent writes none yet |
| What the chat wrote is Bend that Bend accepts | `engine/BUILD.bend`: after a reply that acted on the project, the engine runs `bend <file> --check-only` on every `.bend` file and `bend index.html -o …` on its page, and writes what Bend answered in the conversation. With an error, the chat gets a turn to fix it. The engine does it: no model is trusted to have checked |
| A file that isn't Bend is said to be so | `POLICY.bend` holds the layers (logic, glue, other) in one list. The question before the chat writes such a file says no law checks it, and so does its name among the files changed. A page that imports no `.bend` file is flagged. Not a law yet |
| A page a chat wrote can't use the app | It is served from a second address (the pages door, port 5280), so the app refuses what it sends, like any other site's request. Tested by hand |
| The editor follows its own rules (below) | `LAWS.bend` + `PROOF.bend` in this repo: `bun run check` |
| The look stays on the design system: spacing scale, control heights, nested radii, the 4 grid | Bend-UI's laws: a value off the scale doesn't compile |
| Shortcuts never clash, keep the browser's keys, and never fire while you type | Bend-UI's key laws |
| The chat does only what its mode allows | `POLICY.bend` holds the modes (`HARNESS.md`). **Only read** (the start): laws prove Claude gets `--allowedTools Read` and Codex `--sandbox read-only`. **Ask before changes** (Claude only): before an action that isn't reading, Claude asks the gate and waits; `GATE.bend`'s rules decide (a law forbids, the mode forbids, allowed for this conversation, otherwise you are asked). `LAWS.bend` is denied in every mode. The CLI enforces them |
| The law agent reads, edits, writes and runs only bend | `POLICY.bend`; laws prove Claude gets `--allowedTools Read,Edit,Write,Bash(bend:*)`. Codex can't allow one command: it gets `--sandbox workspace-write`, so it writes only in the project folder but may run other commands there |
| The chat adds nothing without you | The skill `HEAR.md` (a prompt) asks the chat to end its reply with `LAW: "<sentence>"` lines; it can miss a rule or make one up. `HEAR.bend` reads them, and laws prove: every conversation starts by asking, Don't add adds nothing, only Always add stops the asking, a sentence already in the document isn't asked again. The engine writes the sentence; the chat still only reads |
| The chat sets no timer without you, and a timer never sets another | The skill `TIMER.md` (a prompt) asks the chat to end its reply with `TIMER:` lines; `TIMER.bend` reads them and the engine asks you before one is kept. A turn a timer started sets none, a project holds at most 20, a paused one never comes due, and the hours a computer slept through start one turn, not a row of them (`TIMER.bend`: `after`). Tested with a real chat; not laws yet |
| The chat saves no skill without you | The instructions `SKILL.md` (a prompt) ask the chat to write a skill with every line marked; `SKILL.bend` reads them and the engine shows you the whole text before the file is written. A name that exists asks to replace it. The chat still only reads: the engine writes the file. Tested with a real chat; not laws yet |
| Only this computer's own windows reach the server | `server.bend` refuses a request another site's page sends (its `Origin`) or one not addressed to it by its own name (`Host`). Not a law yet: tested by hand |
| You see exactly what the agents are told | Laws › Context shows `AGENT.md`, Chat › Context shows `CHAT.md` and what comes with it, `HEAR.md`, `SKILL.md` and `TIMER.md`; the server sends those files as they are |
| The model lists are real | Read from each AI's CLI by `MODELS.bend`; none is typed by hand |

The editor's own rules (`LAWS.bend`, proved in `PROOF.bend`):

- A title never gets a state.
- Editing a line with a law, or one that failed, sends it back to empty.
- If a line was edited while the agent worked, the answer is dropped.
- With nothing pending, there is nothing to generate; and one run at a time.
- A law block and a sentence block have the same minimum height.
- In Only read, the chat may only read, and never changes a file (`POLICY.bend`): Claude gets `Read`, Codex the `read-only` sandbox.
- The law agent may read, edit, write and run bend, and nothing else: Claude gets exactly that; Codex writes only in the project folder.
- Each tool says what it does: reading never changes a file, and the chat runs no command.

## Run

You need [Bend](https://github.com/bendlang/bend) (`bend` on your PATH), [Bun](https://bun.sh), and `claude` (Claude Code) or `codex` installed and logged in. The terminal inside the app also needs `python3`.

```bash
bun install
bun run start
```

Open http://127.0.0.1:4280. `bun run start` builds the page, the server (`dist/laweditor-server`) and the terminal (`dist/laweditor`), and runs the server in the home of your projects.

- **Your projects live in `~/LawEditor`**, one folder each (`LAWEDITOR_HOME` names another home). A project holds its program in `.bend` files (`main.bend` is where it starts; `index.html` when it has a page), `RULES.md` (your rules, one sentence per line), `LAWS.bend` (their laws, which import the program) and `.laweditor/` (its name, its conversations, what you allowed, its timers, your skills, each turn's record, the page as Bend last bundled it). LawEditor makes none of the first three before there is something to put in it.
- **Any folder of the computer can be a project**, where it is: Open a folder… under the message box, or `laweditor here` in a terminal. LawEditor keeps its things in a `.laweditor` folder inside it.
- `LAWEDITOR_PORT` moves the server from 4280. What your projects built is served at a second address, the port plus 1000 (`LAWEDITOR_PAGES_PORT` names another).
- Coming from 0.1.10: the first `bun run start` copies the projects kept in `projects/` to `~/LawEditor`. The originals stay where they were.

## Always on

A timer comes due only while the server runs. To have the computer keep it running (it starts when you log in, and starts again if it stops):

```bash
./service.sh install    # after bun run start built everything; stop the server you started by hand first
./service.sh status
./service.sh remove
```

It is the same server, in the same home and on the same port: on macOS launchd keeps it, on Linux systemd. A computer that sleeps runs nothing; a timer whose time passed meanwhile starts one turn when it wakes.

## The terminal

```bash
ln -s "$PWD/dist/laweditor" /usr/local/bin/laweditor   # once, so it runs from anywhere
laweditor          # a new conversation (in this folder's project, when the folder is one)
laweditor here     # this folder becomes a project, and the conversation is in it
laweditor list     # the conversations, with their state
laweditor timers   # the timers the chats set; then: timers pause <n> | resume <n> | test <n> | stop <n>
```

It is a second window on the same server (which has to be running): what you do there shows in the app, and what the app does shows there. Write and press Enter; a question is answered with its letter; `!command` runs a command in the project; `/new`, `/list`, `/open <n>`, `/mode`, `/quit`.

## How it works

The app opens on a new conversation, with nothing to pick. The side bar has **New conversation**, **Laws**, **Debug**, and the list of every conversation: the one that moved last first, each with its state (a dot while the chat works, another while it waits for you) and its project's name. Its menu (…) renames the project, opens its folder or deletes the conversation (it goes to the project's `.laweditor/trash`).

**Chat** talks with an AI. Your first message starts the conversation in a folder of its own; once it has a rule or a file it becomes a project, named by the chat, and the folder takes that name. Under the message field:

- **Where**: it says New project. Its menu puts a new conversation in a project that exists, or opens a folder of the computer. Once the conversation has begun it stays where it is.
- **The AI** (Claude or Codex) and **its model**: the list comes from that AI's own CLI (`claude --help` aliases, `codex debug models`).
- **The mode**: **Only read** (it reads your project and never edits it) or **Ask before changes** (Claude only: before it changes a file or runs a command, you get Allow / Allow for this session / Don't allow). In a mode that asks, the menu also lists what you allowed in this conversation.

A reply and everything that comes of it is one **turn**, drawn on one ruler (Bend-UI's `.turn`): its plan, each thing it did (a row that opens to what it answered), what it does now, its words, then one line with the files it changed. When the reply ends, its work folds into one line ("Worked for 48s · 3 actions") that opens again. When the reply changed the project, the turn then says what Bend answered: the files it checked (and how many claims wait for a proof), or the error as Bend gave it; and the page it bundled, with **Open the page**. A file that isn't Bend carries a tag (not checked, not Bend). The rules it heard stay under it, each with what came of it.

A **question** (a rule to add, the mode it offers, an action that needs your yes) takes the message box's place until you answer: where you answer is where it asks, with what would change shown in it. The turn keeps one line as the record ("Allowed · Write index.html"). An action you refused says "not run", and a file counts as changed only when the action that changes it ran.

A **skill** starts as a question: when you ask the chat to keep a way of doing something ("save that as a skill called Count the notes"), the question shows the skill's whole text, and you answer Save skill or Don't save. It is kept with the project, in `.laweditor/skills/`, one file each, plain text you can open and change. The chat is told the project's skills at every turn and reads a skill's file before using it.

A **timer** starts as a question too: when you ask for something later, or again and again, the chat proposes one and you answer Set timer or Don't set, with when and what it will do shown in the question. A timer is on days at a time (weekdays at 10:00; Monday and Thursday at 10:30), after a span (every 4 hours), or once (in 30 minutes). Its first turn is at its next time. When it comes due, the server starts a turn in the same conversation, with the same AI and mode: the turn opens with one line saying a timer started it. What the chat may do then is what the mode allows, and an action that needs your yes still waits for it. A timer that repeats goes on until you pause or stop it: `laweditor timers` lists them, and pauses, resumes, tests (its turn starts now) or stops one.

A message that starts with `!` is a command you run yourself in the project (`!ls`); `/` lists the commands and `@` points to a file. The chat's **Context** button shows `CHAT.md`, its skill `HEAR.md` and `HARNESS.md` (what the chat may do, and when it asks).

Several conversations go at once: start another while one works, and come back to it from the list.

In the toolbar: **Files** opens the project's files in a pane at the right (a file opens there, read only; a file's name in a reply's "files changed" opens it too). **Terminal** opens your own shell in the project's folder, in a pane under the chat; the chat neither sees it nor types in it. **Compact view** keeps the chat and the terminal, with a line of state on top.

**Laws** is where rules become laws. It shows the open conversation's project:

1. Write a rule and press Enter. It gets an empty dot.
2. Pick an AI in the agent (hover the face) and press **Generate LAWs**.
3. For each sentence, the agent states one law about the project's own code and appends it to `LAWS.bend`; when the code has nothing yet that the sentence talks about, it adds the smallest definition to the code itself (`main.bend`), and the chat builds on it. It checks with `bend LAWS.bend --check-only`. The server checks again.
4. Green: the law compiles (a law with no proof yet is fine). Red: it doesn't, or the agent couldn't write one; the message says why.

The selector shows the sentences alone, with their laws, or side by side. Two buttons on the right show:

- **Files** (`<>`): `LAWS.bend` as it is. Deleting a sentence never deletes its law: the law turns amber here until you remove it. To edit, hold the lock. The code the laws talk about is the project's own: it shows in the files pane.
- **Context** (book): `AGENT.md`, exactly what the law agent is told. Read only.

## How it is built

One engine, and windows on it. The server keeps nothing in memory and has no "current" project: every request names its project and its conversation, and what happened is in their files.

- A conversation is a list of events, kept with its project (`harness/EVENTS.bend`): what you wrote, each turn, each reply, what Bend said of the project after it, each question and its answer, the project getting its name. Nothing is ever taken out.
- `engine/TURN.bend` conducts a turn: it runs the AI, has Bend check what it changed, asks each law it heard, offers the mode, asks before an action through the gate, and writes the laws. The rules of each step are in `harness/`.
- A window sends what you wrote or answered (`POST /api/c/<project>/<conversation>/say`, `answer/<question>`, `stop`) and reads the events after the ones it has (`GET …/events/<n>`). The page draws them; the terminal prints them.

## Files

| File | What it is |
|---|---|
| `server.bend` | The door: reads a request and hands it to the engine. Refuses what isn't from its own page or terminal. A second door only serves what the projects built |
| `cli.bend` | LawEditor in the terminal (`dist/laweditor`): a window on the same engine |
| `engine/TURN.bend` | A conversation's turn, conducted: the AI, the questions, the laws, the events |
| `engine/PROJECTS.bend` | The projects: their folders, their lists, a draft becoming a project, a folder opened from elsewhere |
| `engine/BUILD.bend` | Bend's pipeline, run on a project after the chat changed it: the check of its `.bend` files, the bundle of its page |
| `engine/LAW.bend` | The law agent: writes one sentence's law about the project's code, and Bend checks it |
| `engine/CLOCK.bend` | The clock: while the server runs, it looks at every project's timers and starts the turn of each one that came due |
| `engine/TERMINAL.bend` | A real shell in a project, for the terminal pane |
| `engine/PLACES.bend`, `engine/SYS.bend` | Where each thing is kept; files and programs |
| `harness/EVENTS.bend` | A conversation as events: writing them, and reading what is going on from them |
| `harness/POLICY.bend` | The tools (and what each does: changes a file, runs a command), the two agents, the chat's modes, and the tools each is given; each CLI's flags come from it. And what a project is made of: which files are logic, which are glue |
| `harness/GATE.bend` | The gate: the rules that decide an action (a law forbids, the mode forbids, allowed, ask you), and what was allowed |
| `harness/HEAR.bend` | The chat hears rules: reads its `LAW:` lines, and when to ask (Add / Always add / Don't add) |
| `harness/SKILL.bend` | The person's skills: reads the chat's marked `SKILL` lines, the question that shows one whole, the list the chat is told |
| `harness/TIMER.bend` | The chat sets timers: reads its `TIMER:` lines, days and times of day, the limits, when one is due, what is left of it after, pausing |
| `harness/OFFER.bend` | The chat offers the mode: in Only read, a request to build becomes Switch / Stay |
| `harness/ASK.bend` | Reads what Claude sends: an action, a turn's answer while it is written, its work |
| `harness/CHAT.bend`, `harness/MODELS.bend` | The chat's small rules (when Send is on, the commands, the project's name); the models each AI's CLI offers |
| `harness/AGENT.md`, `CHAT.md`, `HEAR.md`, `SKILL.md`, `TIMER.md`, `HARNESS.md` | What the law agent is told; what the chat is told, and how it hears rules, writes skills and asks for timers; what it may do and when it asks |
| `service.sh` | Hands the server to the computer to keep it always on (launchd, systemd) |
| `flows/FLOW.bend` | How a flow is written: its steps, who acts in each, where each goes |
| `flows/ARCH.bend`, `PERMIT.bend`, `DIAGRAMS.bend` | The harness, the permission flows, and the program that draws them |
| `EDITOR.bend` | The Laws editor's logic (line states, when Generate is on) |
| `LAWS.bend` / `PROOF.bend` | The editor's own rules and their proofs (`bun run check`) |
| `web/` | The page: `index.html` (Bend-UI classes only); `main.js` (Laws), `chat.js` and `chat/` (Chat), `files.js`, `shell.js`, `compact.js`, `where.js`, `markdown.js`. They draw; no CSS of its own |

Agent instructions for this repo: [`AGENTS.md`](AGENTS.md).
