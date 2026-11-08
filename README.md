# LawEditor

A workbench for [Bend](https://github.com/bendlang/bend): talk with an agent about your project, and turn what you mean into **laws** the Bend compiler checks.

- **Chat**: talk with Claude or Codex about your project. It reads your files and never edits them.
  When you state a rule in the talk ("the player starts with 3 lives"), the chat proposes it as a sentence; you answer Add, Always add (this session) or Don't add. An added sentence goes to the document and its law is written and checked, as with Generate.
- **Laws**: write a rule in a plain sentence; the agent writes it as a Bend law, and Bend checks it.

Everything is Bend: the server (`server.bend`), the logic (`EDITOR.bend`, `CHAT.bend`, `MODELS.bend`), the editor's own rules (`LAWS.bend`), and the look ([Bend-UI](https://github.com/isabellaherman/Bend-UI), whose rules are laws too). JS only reads input and draws.

## What is checked

Nothing here asks to be trusted. Each claim below is checked by the Bend compiler, or enforced by a tool.

| Claim | How |
|---|---|
| A law you write compiles | `bend LAWS.bend --check-only`, run by the agent and again by the server. Red when it doesn't, with the reason |
| The editor follows its own rules (below) | `LAWS.bend` + `PROOF.bend` in this repo: `bun run check` |
| The look stays on the design system: spacing scale, control heights, nested radii, the 4 grid | Bend-UI's laws: a value off the scale doesn't compile |
| Shortcuts never clash, keep the browser's keys, and never fire while you type | Bend-UI's key laws |
| The chat does only what its mode allows | `POLICY.bend` holds the modes (`HARNESS.md`). **Only read** (the start): laws prove Claude gets `--allowedTools Read` and Codex `--sandbox read-only`. **Ask before changes** (Claude only): what isn't allowed is refused, `ASK.bend` turns it into a question, and the same session goes on with what you allowed. `LAWS.bend` is denied in every mode. The CLI enforces them |
| The law agent reads, edits, writes and runs only bend | `POLICY.bend`; laws prove Claude gets `--allowedTools Read,Edit,Write,Bash(bend:*)`. Codex can't allow one command: it gets `--sandbox workspace-write`, so it writes only in the project folder but may run other commands there |
| The chat adds nothing without you | The skill `HEAR.md` (a prompt) asks the chat to end its reply with `LAW: "<sentence>"` lines; it can miss a rule or make one up. `HEAR.bend` reads them, and laws prove: every session starts by asking, Don't add adds nothing, only Always add stops the asking, a sentence already in the document isn't asked again. The page writes the sentence; the chat still only reads |
| You see exactly what the agents are told | Laws › Context shows `AGENT.md`, Chat › Context shows `CHAT.md` and its skill `HEAR.md`; the server sends those files as they are |
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

You need [Bend](https://github.com/bendlang/bend) (`bend` on your PATH), [Bun](https://bun.sh), and `claude` (Claude Code) or `codex` installed and logged in.

```bash
bun install
bun run start
```

Open http://127.0.0.1:4280. Your project lives in `project/`: `GDD.md` (your sentences), `TYPES.bend` (what the laws talk about) and `LAWS.bend` (the laws). `bun run start` builds the page and the server (`dist/laweditor-server`, compiled: it answers while the chat works). To use another folder, run the server from it:

```bash
bun run build && bun run server
cd ~/my-project
/path/to/LawEditor/dist/laweditor-server /path/to/LawEditor/dist /path/to/LawEditor/AGENT.md
```

## How it works

The app opens on **Chat**. The side bar has two places: **Chat** and **Laws**.

**Chat** talks with an AI. It opens empty, the agent's face and the message field in the middle; your first message sends the field down and the face beside the first reply. Under the message field, pick the AI (Claude or Codex) and its model: the list comes from that AI's own CLI (`claude --help` aliases, `codex debug models`). The third picker is the chat's mode: **Only read** (it reads your project and never edits it) or **Ask before changes** (Claude only: when it wants to change a file or run a command, you get Allow / Always allow / Don't allow). Its **Context** button shows `CHAT.md`, its skill `HEAR.md` and `HARNESS.md` (what the chat may do, and when it asks).

**Laws** is where rules become laws:

1. Write a rule and press Enter. It gets an empty dot.
2. Pick an AI in the agent (hover the face) and press **Generate LAWs**.
3. For each sentence, the agent adds what's missing to `TYPES.bend`, appends one law to `LAWS.bend`, and checks it with `bend LAWS.bend --check-only`. The server checks again.
4. Green: the law compiles (a law with no proof yet is fine). Red: it doesn't, or the agent couldn't write one; the message says why.

The selector shows the sentences alone, with their laws, or side by side. Two buttons on the right show:

- **Files** (`<>`): `LAWS.bend` and `TYPES.bend` as they are. Deleting a sentence never deletes its law: the law turns amber here until you remove it. To edit, hold the lock.
- **Context** (book): `AGENT.md`, exactly what the law agent is told. Read only.

## Files

| File | What it is |
|---|---|
| `server.bend` | The server: serves the page, keeps the project files, runs the agent and the chat |
| `EDITOR.bend` | The editor's logic (line states, when Generate is on) |
| `CHAT.bend` | The chat's logic (who wrote a message, the empty start, the reply's phases, the model list's states, when Send is on) |
| `HEAR.bend` | The chat hears rules: reads its `LAW:` lines, and when to ask (Add / Always add / Don't add) |
| `MODELS.bend` | Reads the models each AI's CLI offers |
| `ASK.bend` | The chat asks before it acts: reads what Claude was refused and makes the question; the person's answers |
| `OFFER.bend` | The chat offers the mode: in Only read, a request to build becomes Switch / Stay; its flow is drawn in Chat › Context |
| `FLOW.bend` | How a flow is written: its steps, who acts in each, where each goes |
| `POLICY.bend` | The tools (and what each does: changes a file, runs a command), the two agents, the chat's modes, and the tools each is given; each CLI's flags come from it |
| `LAWS.bend` / `PROOF.bend` | The editor's own rules and their proofs (`bun run check`) |
| `AGENT.md` | What the law agent is told |
| `CHAT.md` | What the chat is told (next to `AGENT.md`) |
| `HEAR.md` | The chat's skill: hear rules in the talk and propose them (sent after `CHAT.md`) |
| `HARNESS.md` | What the chat may do in each mode, and when it asks |
| `web/` | The page: `index.html` (Bend-UI classes only); `main.js` (Laws), `chat.js` and `chat/` (Chat: messages, face, start, models, composer), `markdown.js`. They draw; no CSS of its own |

Agent instructions for this repo: [`AGENTS.md`](AGENTS.md).
