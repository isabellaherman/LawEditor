# LawEditor

Write rules in plain sentences; an agent (Claude or Codex) turns each one into a [Bend](https://github.com/bendlang/bend) **law**, and Bend checks it.

Everything is Bend: the server (`server.bend`), the editor's logic (`EDITOR.bend`, with its own rules in `LAWS.bend`), and the look ([Bend-UI](https://github.com/isabellaherman/Bend-UI)). JS only reads input and draws.

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

**Chat** talks with an AI. Under the message field, pick the AI (Claude or Codex) and its model: the list comes from that AI's own CLI (`claude --help` aliases, `codex debug models`). The chat reads your project and never edits it. Its **Context** button shows `CHAT.md`, exactly what it is told.

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
| `CHAT.bend` | The chat's logic (who wrote a message, the reply's phases, the model list's states, when Send is on) |
| `MODELS.bend` | Reads the models each AI's CLI offers |
| `LAWS.bend` / `PROOF.bend` | The editor's own rules and their proofs (`bun run check`) |
| `AGENT.md` | What the law agent is told |
| `CHAT.md` | What the chat is told (next to `AGENT.md`) |
| `web/` | The page: `index.html` (Bend-UI classes only); `main.js` (Laws), `chat.js` and `chat/` (Chat), `markdown.js`. They draw; no CSS of its own |

Agent instructions for this repo: [`AGENTS.md`](AGENTS.md).
