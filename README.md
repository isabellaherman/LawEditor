# LawEditor

A workbench for [Bend](https://github.com/bendlang/bend): talk with an agent about your project, and turn what you mean into **laws** the Bend compiler checks.

- **Chat**: talk with Claude or Codex about your project. It reads your files and never edits them.
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
| The chat never edits your files | Enforced by the CLI: Claude runs with `--allowedTools Read`, Codex with `--sandbox read-only` |
| You see exactly what the agents are told | Laws › Context shows `AGENT.md`, Chat › Context shows `CHAT.md`; the server sends those files as they are |
| The model lists are real | Read from each AI's CLI by `MODELS.bend`; none is typed by hand |

The editor's own rules (`LAWS.bend`, proved in `PROOF.bend`):

- A title never gets a state.
- Editing a line with a law, or one that failed, sends it back to empty.
- If a line was edited while the agent worked, the answer is dropped.
- With nothing pending, there is nothing to generate; and one run at a time.
- A law block and a sentence block have the same minimum height.
- The chat may only read (`POLICY.bend`).

## Run

You need [Bend](https://github.com/bendlang/bend) (`bend` on your PATH), [Bun](https://bun.sh), and `claude` (Claude Code) or `codex` installed and logged in.

```bash
bun install
bun run start
```

Open http://127.0.0.1:4280. Your project lives in `project/`: `GDD.md` (your sentences), `TYPES.bend` (what the laws talk about) and `LAWS.bend` (the laws). To use another folder, run the server from it:

```bash
bun run build
cd ~/my-project
bend /path/to/LawEditor/server.bend /path/to/LawEditor/dist /path/to/LawEditor/AGENT.md
```

## How it works

The app opens on **Chat**. The side bar has two places: **Chat** and **Laws**.

**Chat** talks with an AI. It opens empty, the agent's face and the message field in the middle; your first message sends the field down and the face beside the first reply. Under the message field, pick the AI (Claude or Codex) and its model: the list comes from that AI's own CLI (`claude --help` aliases, `codex debug models`). The chat reads your project and never edits it. Its **Context** button shows `CHAT.md`, exactly what it is told.

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
| `MODELS.bend` | Reads the models each AI's CLI offers |
| `POLICY.bend` | What each agent may do: the chat reads; the law agent reads, edits, writes and runs bend |
| `LAWS.bend` / `PROOF.bend` | The editor's own rules and their proofs (`bun run check`) |
| `AGENT.md` | What the law agent is told |
| `CHAT.md` | What the chat is told (next to `AGENT.md`) |
| `web/` | The page: `index.html` (Bend-UI classes only); `main.js` (Laws), `chat.js` and `chat/` (Chat: messages, face, start, models, composer), `markdown.js`. They draw; no CSS of its own |

Agent instructions for this repo: [`AGENTS.md`](AGENTS.md).
